//! `obscura watch`: one long-running connection that reports recording state.
//!
//! The bar widget runs this and reads one JSON object per line. The process
//! sleeps on the socket, so it costs nothing while nothing changes. The elapsed
//! time is sent only on state changes; the widget counts seconds itself.

use std::thread::sleep;
use std::time::Duration;

use serde::Serialize;
use serde_json::Value;

use crate::client::{Client, ConnectError, RecordStatus, events};
use crate::config::Connection;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct State {
    /// offline, disabled, auth, idle, starting, recording, paused, stopping
    pub state: &'static str,
    pub elapsed_ms: u64,
    /// Path of the file OBS just saved; only on the idle state after a stop.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub saved: Option<String>,
}

impl State {
    fn bare(state: &'static str) -> Self {
        Self { state, elapsed_ms: 0, saved: None }
    }

    pub fn from_status(s: &RecordStatus) -> Self {
        let state = match (s.output_active, s.output_paused) {
            (false, _) => "idle",
            (true, true) => "paused",
            (true, false) => "recording",
        };
        Self { state, elapsed_ms: if s.output_active { s.output_duration } else { 0 }, saved: None }
    }
}

/// How an OBS `RecordStateChanged` event changes what we report.
#[derive(Debug, PartialEq, Eq)]
pub enum Step {
    /// Report this at once; the truth is confirmed by a status query after.
    Show(State),
    /// Ask OBS for the real status (gives the elapsed time).
    Query,
}

pub fn step_for(event: &Value) -> Option<Step> {
    if event["d"]["eventType"] != "RecordStateChanged" {
        return None;
    }
    let data = &event["d"]["eventData"];
    Some(match data["outputState"].as_str()? {
        "OBS_WEBSOCKET_OUTPUT_STARTING" => Step::Show(State::bare("starting")),
        "OBS_WEBSOCKET_OUTPUT_STOPPING" => Step::Show(State::bare("stopping")),
        "OBS_WEBSOCKET_OUTPUT_STOPPED" => Step::Show(State {
            saved: data["outputPath"].as_str().map(str::to_owned),
            ..State::bare("idle")
        }),
        _ => Step::Query, // STARTED, PAUSED, RESUMED
    })
}

const BACKOFF_START: Duration = Duration::from_secs(1);
const BACKOFF_MAX: Duration = Duration::from_secs(10);
const AUTH_RETRY: Duration = Duration::from_secs(10);
const KEEPALIVE: Duration = Duration::from_secs(30);

/// Runs until `emit` returns false (the reader went away).
/// `emit(None)` is a heartbeat (an empty line): it lets us notice a reader that
/// has gone away even while the state is not changing.
pub fn run(conn: &Connection, mut emit: impl FnMut(Option<&State>) -> bool) {
    let mut last: Option<State> = None;
    let mut say = |s: State, emit: &mut dyn FnMut(Option<&State>) -> bool| -> bool {
        if last.as_ref() == Some(&s) {
            return emit(None);
        }
        let ok = emit(Some(&s));
        last = Some(s);
        ok
    };

    let mut backoff = BACKOFF_START;
    loop {
        match Client::connect(conn, events::OUTPUTS | events::GENERAL) {
            Ok(mut client) => {
                backoff = BACKOFF_START;
                match session(&mut client, &mut |s| match s {
                    Some(s) => say(s, &mut emit),
                    None => emit(None),
                }) {
                    Session::ReaderGone => return,
                    Session::Dropped => {
                        if !say(offline(conn, false), &mut emit) {
                            return;
                        }
                        sleep(BACKOFF_START);
                    }
                }
            }
            Err(ConnectError::Auth(_)) => {
                if !say(State::bare("auth"), &mut emit) {
                    return;
                }
                sleep(AUTH_RETRY);
            }
            Err(_) => {
                if !say(offline(conn, true), &mut emit) {
                    return;
                }
                sleep(backoff);
                backoff = (backoff * 2).min(BACKOFF_MAX);
            }
        }
    }
}

fn offline(conn: &Connection, refused: bool) -> State {
    if refused && conn.server_enabled == Some(false) {
        State::bare("disabled")
    } else {
        State::bare("offline")
    }
}

enum Session {
    Dropped,
    ReaderGone,
}

fn session(client: &mut Client, say: &mut dyn FnMut(Option<State>) -> bool) -> Session {
    let Ok(status) = client.record_status() else { return Session::Dropped };
    if !say(Some(State::from_status(&status))) {
        return Session::ReaderGone;
    }
    loop {
        match client.next_event(KEEPALIVE) {
            Ok(Some(ev)) => {
                if ev["d"]["eventType"] == "ExitStarted" {
                    return Session::Dropped;
                }
                let next = match step_for(&ev) {
                    None => continue,
                    Some(Step::Show(s)) => s,
                    Some(Step::Query) => match client.record_status() {
                        Ok(s) => State::from_status(&s),
                        Err(_) => return Session::Dropped,
                    },
                };
                if !say(Some(next)) {
                    return Session::ReaderGone;
                }
            }
            Ok(None) => {
                if client.ping().is_err() {
                    return Session::Dropped;
                }
                if !say(None) {
                    return Session::ReaderGone;
                }
            }
            Err(_) => return Session::Dropped,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn ev(state: &str, path: Option<&str>) -> Value {
        json!({ "op": 5, "d": { "eventType": "RecordStateChanged",
            "eventData": { "outputState": state, "outputPath": path } } })
    }

    #[test]
    fn started_is_confirmed_by_a_query_not_assumed() {
        assert_eq!(step_for(&ev("OBS_WEBSOCKET_OUTPUT_STARTED", None)), Some(Step::Query));
        assert_eq!(step_for(&ev("OBS_WEBSOCKET_OUTPUT_PAUSED", None)), Some(Step::Query));
    }

    #[test]
    fn starting_never_shows_as_recording() {
        let Some(Step::Show(s)) = step_for(&ev("OBS_WEBSOCKET_OUTPUT_STARTING", None)) else {
            panic!()
        };
        assert_eq!(s.state, "starting");
    }

    #[test]
    fn stop_carries_the_saved_path() {
        let Some(Step::Show(s)) = step_for(&ev("OBS_WEBSOCKET_OUTPUT_STOPPED", Some("/v/a.mkv")))
        else {
            panic!()
        };
        assert_eq!((s.state, s.saved.as_deref()), ("idle", Some("/v/a.mkv")));
    }

    #[test]
    fn other_events_are_ignored() {
        let e = json!({ "op": 5, "d": { "eventType": "CurrentProgramSceneChanged" } });
        assert_eq!(step_for(&e), None);
    }

    #[test]
    fn status_maps_to_state() {
        let mut s = RecordStatus {
            output_active: true,
            output_paused: true,
            output_timecode: String::new(),
            output_duration: 5000,
            output_bytes: 0,
        };
        assert_eq!(State::from_status(&s).state, "paused");
        s.output_paused = false;
        assert_eq!(State::from_status(&s).elapsed_ms, 5000);
        s.output_active = false;
        assert_eq!(State::from_status(&s), State::bare("idle"));
    }
}
