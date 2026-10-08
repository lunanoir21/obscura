//! `obscura meters`: audio input levels while a panel is looking at them.
//!
//! OBS sends volume meters about 50 times a second. The widget needs a dozen,
//! so this process thins them out and sends only what changed. It runs only
//! while the panel is open and is stopped by the widget otherwise.

use std::collections::BTreeMap;
use std::time::{Duration, Instant};

use serde_json::Value;

use crate::client::{Client, events};
use crate::config::Connection;

const MIN_GAP: Duration = Duration::from_millis(80);
const MIN_CHANGE: f64 = 0.02;
const FLOOR_DB: f64 = -60.0;

/// 0.0 (silence) to 1.0 (full scale) on a -60..0 dB scale.
pub fn level(linear: f64) -> f64 {
    if linear <= 0.0 {
        return 0.0;
    }
    ((20.0 * linear.log10() - FLOOR_DB) / -FLOOR_DB).clamp(0.0, 1.0)
}

/// The loudest peak across an input's channels, as a 0..1 level.
pub fn input_level(levels_mul: &Value) -> f64 {
    levels_mul
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|ch| ch.get(1).and_then(Value::as_f64))
        .fold(0.0, f64::max)
        .pipe(level)
}

trait Pipe: Sized {
    fn pipe<R>(self, f: impl FnOnce(Self) -> R) -> R {
        f(self)
    }
}
impl Pipe for f64 {}

/// Returns when the connection ends or `emit` returns false (reader gone).
pub fn run(conn: &Connection, mut emit: impl FnMut(Option<&BTreeMap<String, f64>>) -> bool) {
    let Ok(mut client) = Client::connect(conn, events::INPUT_VOLUME_METERS) else { return };
    let mut last: BTreeMap<String, f64> = BTreeMap::new();
    let mut last_sent = Instant::now() - MIN_GAP;
    loop {
        match client.next_event(Duration::from_secs(5)) {
            Ok(Some(ev)) => {
                if ev["d"]["eventType"] != "InputVolumeMeters" || last_sent.elapsed() < MIN_GAP {
                    continue;
                }
                let now: BTreeMap<String, f64> = ev["d"]["eventData"]["inputs"]
                    .as_array()
                    .into_iter()
                    .flatten()
                    .filter_map(|i| Some((i["inputName"].as_str()?.to_owned(), input_level(&i["inputLevelsMul"]))))
                    .collect();
                let moved = now.len() != last.len()
                    || now.iter().any(|(k, v)| last.get(k).is_none_or(|o| (o - v).abs() > MIN_CHANGE));
                if moved {
                    if !emit(Some(&now)) {
                        return;
                    }
                    last = now;
                    last_sent = Instant::now();
                }
            }
            // Quiet connection: a heartbeat notices a reader that went away.
            Ok(None) => {
                if !emit(None) {
                    return;
                }
            }
            Err(_) => return,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn db_scale_maps_to_unit_range() {
        assert_eq!(level(0.0), 0.0);
        assert!((level(1.0) - 1.0).abs() < 1e-9);
        assert!((level(0.1) - (40.0 / 60.0)).abs() < 1e-9); // -20 dB
        assert_eq!(level(0.000001), 0.0); // below the floor
    }

    #[test]
    fn takes_the_loudest_channel_peak() {
        // [magnitude, peak, input-peak] per channel
        let v = json!([[0.01, 0.1, 0.1], [0.02, 0.5, 0.5]]);
        assert!((input_level(&v) - level(0.5)).abs() < 1e-9);
        assert_eq!(input_level(&json!([])), 0.0);
    }
}
