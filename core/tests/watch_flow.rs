//! Drives `watch::run` against a scripted fake obs-websocket server, including
//! the password handshake, so the whole path is exercised without OBS.

use std::net::TcpListener;
use std::sync::mpsc;
use std::thread;

use obscura_core::{Connection, auth, watch};
use serde_json::{Value, json};
use tungstenite::Message;

fn send(ws: &mut tungstenite::WebSocket<std::net::TcpStream>, v: Value) {
    ws.send(Message::text(v.to_string())).unwrap();
}

fn recv(ws: &mut tungstenite::WebSocket<std::net::TcpStream>) -> Value {
    loop {
        if let Message::Text(t) = ws.read().unwrap() {
            return serde_json::from_str(t.as_str()).unwrap();
        }
    }
}

fn status(active: bool, paused: bool, ms: u64) -> Value {
    json!({ "outputActive": active, "outputPaused": paused, "outputDuration": ms,
            "outputTimecode": "00:00:00.000", "outputBytes": 0 })
}

fn answer(ws: &mut tungstenite::WebSocket<std::net::TcpStream>, req: &Value, data: Value) {
    send(
        ws,
        json!({ "op": 7, "d": { "requestType": req["d"]["requestType"], "requestId": req["d"]["requestId"],
            "requestStatus": { "result": true, "code": 100 }, "responseData": data } }),
    );
}

fn event(state: &str, path: Option<&str>) -> Value {
    json!({ "op": 5, "d": { "eventType": "RecordStateChanged", "eventIntent": 64,
        "eventData": { "outputActive": true, "outputState": state, "outputPath": path } } })
}

#[test]
fn reports_a_full_recording_cycle_after_authenticating() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();

    thread::spawn(move || {
        let (stream, _) = listener.accept().unwrap();
        let mut ws = tungstenite::accept(stream).unwrap();
        let (salt, challenge) = ("c2FsdA==", "Y2hhbGxlbmdl");
        send(
            &mut ws,
            json!({ "op": 0, "d": { "obsWebSocketVersion": "5.5.0", "rpcVersion": 1,
                "authentication": { "salt": salt, "challenge": challenge } } }),
        );
        let identify = recv(&mut ws);
        assert_eq!(identify["d"]["authentication"], auth::response("pw", salt, challenge));
        assert_eq!(identify["d"]["eventSubscriptions"], 65);
        send(&mut ws, json!({ "op": 2, "d": { "negotiatedRpcVersion": 1 } }));

        let req = recv(&mut ws);
        answer(&mut ws, &req, status(false, false, 0));

        send(&mut ws, event("OBS_WEBSOCKET_OUTPUT_STARTING", None));
        send(&mut ws, event("OBS_WEBSOCKET_OUTPUT_STARTED", None));
        let req = recv(&mut ws);
        answer(&mut ws, &req, status(true, false, 1200));

        send(&mut ws, event("OBS_WEBSOCKET_OUTPUT_PAUSED", None));
        let req = recv(&mut ws);
        answer(&mut ws, &req, status(true, true, 4000));

        send(&mut ws, event("OBS_WEBSOCKET_OUTPUT_STOPPING", None));
        send(&mut ws, event("OBS_WEBSOCKET_OUTPUT_STOPPED", Some("/v/take.mkv")));
        // Dropping the socket ends the session; the reader below stops first.
        thread::sleep(std::time::Duration::from_millis(300));
    });

    let conn = Connection {
        host: "127.0.0.1".into(),
        port,
        password: Some("pw".into()),
        server_enabled: Some(true),
    };
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        watch::run(&conn, |s| {
            if let Some(s) = s {
                tx.send(s.clone()).ok();
            }
            true
        });
    });

    let mut seen = Vec::new();
    while let Ok(s) = rx.recv_timeout(std::time::Duration::from_secs(5)) {
        let done = s.state == "idle" && s.saved.is_some();
        seen.push(s);
        if done {
            break;
        }
    }
    let flow: Vec<_> = seen.iter().map(|s| (s.state, s.elapsed_ms)).collect();
    assert_eq!(
        flow,
        vec![
            ("idle", 0),
            ("starting", 0),
            ("recording", 1200),
            ("paused", 4000),
            ("stopping", 0),
            ("idle", 0),
        ]
    );
    assert_eq!(seen.last().unwrap().saved.as_deref(), Some("/v/take.mkv"));
}
