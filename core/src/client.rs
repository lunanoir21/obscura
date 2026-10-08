use std::net::{TcpStream, ToSocketAddrs};
use std::time::Duration;

use anyhow::{Context, Result, anyhow, bail};
use serde::Deserialize;
use serde_json::{Value, json};
use tungstenite::{Message, WebSocket};

use crate::{auth, config::Connection};

const OP_HELLO: u64 = 0;
const OP_IDENTIFY: u64 = 1;
const OP_IDENTIFIED: u64 = 2;
const OP_EVENT: u64 = 5;
const OP_REQUEST: u64 = 6;
const OP_RESPONSE: u64 = 7;

/// Event subscription bits (obs-websocket v5).
pub mod events {
    pub const NONE: u32 = 0;
    pub const GENERAL: u32 = 1 << 0;
    pub const OUTPUTS: u32 = 1 << 6;
}

const CONNECT_TIMEOUT: Duration = Duration::from_millis(800);
const IO_TIMEOUT: Duration = Duration::from_secs(5);

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecordStatus {
    pub output_active: bool,
    pub output_paused: bool,
    /// `HH:MM:SS.mmm`
    #[serde(default)]
    pub output_timecode: String,
    #[serde(default)]
    pub output_duration: u64,
    #[serde(default)]
    pub output_bytes: u64,
}

pub struct Client {
    ws: WebSocket<TcpStream>,
    next_id: u64,
}

impl Client {
    /// Connect and identify. Fails fast (under a second) when OBS is not listening.
    pub fn connect(conn: &Connection, subscriptions: u32) -> Result<Self> {
        let addr = (conn.host.as_str(), conn.port)
            .to_socket_addrs()?
            .next()
            .ok_or_else(|| anyhow!("cannot resolve {}", conn.host))?;
        let stream = TcpStream::connect_timeout(&addr, CONNECT_TIMEOUT)
            .with_context(|| format!("OBS is not listening on {}:{}", conn.host, conn.port))?;
        stream.set_nodelay(true).ok();
        stream.set_read_timeout(Some(IO_TIMEOUT))?;
        stream.set_write_timeout(Some(IO_TIMEOUT))?;

        let url = format!("ws://{}:{}", conn.host, conn.port);
        let (mut ws, _) = tungstenite::client(url, stream).map_err(|e| anyhow!("handshake: {e}"))?;

        let hello = read_json(&mut ws)?;
        if hello["op"].as_u64() != Some(OP_HELLO) {
            bail!("expected Hello from OBS");
        }
        let mut data = json!({ "rpcVersion": 1, "eventSubscriptions": subscriptions });
        if let Some(a) = hello["d"].get("authentication") {
            let password = conn
                .password
                .as_deref()
                .ok_or_else(|| anyhow!("OBS asks for a password; set OBSCURA_PASSWORD"))?;
            let salt = a["salt"].as_str().unwrap_or_default();
            let challenge = a["challenge"].as_str().unwrap_or_default();
            data["authentication"] = json!(auth::response(password, salt, challenge));
        }
        send_json(&mut ws, &json!({ "op": OP_IDENTIFY, "d": data }))?;

        let reply = read_json(&mut ws)?;
        if reply["op"].as_u64() != Some(OP_IDENTIFIED) {
            bail!("authentication failed (wrong password?)");
        }
        Ok(Self { ws, next_id: 1 })
    }

    /// One request, one response. Events that arrive in between are skipped.
    pub fn request(&mut self, kind: &str, data: Value) -> Result<Value> {
        let id = self.next_id.to_string();
        self.next_id += 1;
        send_json(
            &mut self.ws,
            &json!({ "op": OP_REQUEST, "d": { "requestType": kind, "requestId": id, "requestData": data } }),
        )?;
        loop {
            let msg = read_json(&mut self.ws)?;
            match msg["op"].as_u64() {
                Some(OP_RESPONSE) if msg["d"]["requestId"] == id => {
                    let st = &msg["d"]["requestStatus"];
                    if st["result"].as_bool() != Some(true) {
                        bail!(
                            "{kind}: {}",
                            st["comment"].as_str().unwrap_or("request failed")
                        );
                    }
                    return Ok(msg["d"]["responseData"].clone());
                }
                Some(OP_EVENT) | Some(OP_RESPONSE) => continue,
                _ => continue,
            }
        }
    }

    pub fn record_status(&mut self) -> Result<RecordStatus> {
        let v = self.request("GetRecordStatus", Value::Null)?;
        Ok(serde_json::from_value(v)?)
    }

    pub fn start_record(&mut self) -> Result<()> {
        self.request("StartRecord", Value::Null).map(drop)
    }

    /// Returns the saved file path when OBS reports one.
    pub fn stop_record(&mut self) -> Result<Option<String>> {
        let v = self.request("StopRecord", Value::Null)?;
        Ok(v["outputPath"].as_str().map(str::to_owned))
    }

    pub fn toggle_pause(&mut self) -> Result<()> {
        self.request("ToggleRecordPause", Value::Null).map(drop)
    }
}

fn send_json(ws: &mut WebSocket<TcpStream>, v: &Value) -> Result<()> {
    ws.send(Message::text(v.to_string()))?;
    Ok(())
}

fn read_json(ws: &mut WebSocket<TcpStream>) -> Result<Value> {
    loop {
        match ws.read()? {
            Message::Text(t) => return Ok(serde_json::from_str(t.as_str())?),
            Message::Close(_) => bail!("OBS closed the connection"),
            _ => continue,
        }
    }
}
