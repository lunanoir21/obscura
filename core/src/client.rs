use std::collections::VecDeque;
use std::fmt;
use std::io::ErrorKind;
use std::net::{TcpStream, ToSocketAddrs};
use std::time::Duration;

use anyhow::{Result, anyhow, bail};
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

/// Why a connection attempt failed, so callers can tell "OBS is closed" from
/// "wrong password" without parsing messages.
#[derive(Debug)]
pub enum ConnectError {
    Unreachable(String),
    Auth(String),
    Other(anyhow::Error),
}

impl fmt::Display for ConnectError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Unreachable(m) | Self::Auth(m) => f.write_str(m),
            Self::Other(e) => write!(f, "{e:#}"),
        }
    }
}

impl std::error::Error for ConnectError {}

impl From<anyhow::Error> for ConnectError {
    fn from(e: anyhow::Error) -> Self {
        Self::Other(e)
    }
}

pub struct Client {
    ws: WebSocket<TcpStream>,
    next_id: u64,
    /// Events that arrived while a request was waiting for its answer.
    pending: VecDeque<Value>,
}

impl Client {
    /// Connect and identify. Fails fast (under a second) when OBS is not listening.
    pub fn connect(conn: &Connection, subscriptions: u32) -> Result<Self, ConnectError> {
        let addr = (conn.host.as_str(), conn.port)
            .to_socket_addrs()
            .map_err(|e| anyhow!("cannot resolve {}: {e}", conn.host))?
            .next()
            .ok_or_else(|| anyhow!("cannot resolve {}", conn.host))?;
        let stream = TcpStream::connect_timeout(&addr, CONNECT_TIMEOUT).map_err(|e| {
            ConnectError::Unreachable(format!(
                "OBS is not listening on {}:{}: {e}",
                conn.host, conn.port
            ))
        })?;
        stream.set_nodelay(true).ok();
        stream.set_read_timeout(Some(IO_TIMEOUT)).map_err(anyhow::Error::from)?;
        stream.set_write_timeout(Some(IO_TIMEOUT)).map_err(anyhow::Error::from)?;

        let url = format!("ws://{}:{}", conn.host, conn.port);
        let (mut ws, _) =
            tungstenite::client(url, stream).map_err(|e| anyhow!("handshake: {e}"))?;

        let hello = read_json(&mut ws)?;
        if hello["op"].as_u64() != Some(OP_HELLO) {
            return Err(anyhow!("expected Hello from OBS").into());
        }
        let mut data = json!({ "rpcVersion": 1, "eventSubscriptions": subscriptions });
        if let Some(a) = hello["d"].get("authentication") {
            let password = conn.password.as_deref().ok_or_else(|| {
                ConnectError::Auth("OBS asks for a password; set OBSCURA_PASSWORD".into())
            })?;
            let salt = a["salt"].as_str().unwrap_or_default();
            let challenge = a["challenge"].as_str().unwrap_or_default();
            data["authentication"] = json!(auth::response(password, salt, challenge));
        }
        send_json(&mut ws, &json!({ "op": OP_IDENTIFY, "d": data }))?;

        // A wrong password makes OBS close the socket instead of answering.
        let reply = read_json(&mut ws)
            .map_err(|_| ConnectError::Auth("authentication failed (wrong password?)".into()))?;
        if reply["op"].as_u64() != Some(OP_IDENTIFIED) {
            return Err(ConnectError::Auth("authentication failed (wrong password?)".into()));
        }
        Ok(Self { ws, next_id: 1, pending: VecDeque::new() })
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
                Some(OP_EVENT) => self.pending.push_back(msg),
                _ => continue,
            }
        }
    }

    /// Next event, waiting at most `wait`. `None` means the wait ran out.
    pub fn next_event(&mut self, wait: Duration) -> Result<Option<Value>> {
        if let Some(ev) = self.pending.pop_front() {
            return Ok(Some(ev));
        }
        self.ws.get_ref().set_read_timeout(Some(wait))?;
        let out = loop {
            match self.ws.read() {
                Ok(Message::Text(t)) => {
                    let v: Value = serde_json::from_str(t.as_str())?;
                    if v["op"].as_u64() == Some(OP_EVENT) {
                        break Ok(Some(v));
                    }
                }
                Ok(Message::Close(_)) => break Err(anyhow!("OBS closed the connection")),
                Ok(_) => {}
                Err(tungstenite::Error::Io(e))
                    if matches!(e.kind(), ErrorKind::WouldBlock | ErrorKind::TimedOut) =>
                {
                    break Ok(None);
                }
                Err(e) => break Err(e.into()),
            }
        };
        self.ws.get_ref().set_read_timeout(Some(IO_TIMEOUT))?;
        out
    }

    /// Cheap liveness check for an otherwise silent connection.
    pub fn ping(&mut self) -> Result<()> {
        self.ws.send(Message::Ping(Vec::new().into()))?;
        Ok(())
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
