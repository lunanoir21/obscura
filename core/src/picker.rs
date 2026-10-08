//! A screen-share picker for xdg-desktop-portal-hyprland.
//!
//! xdph can run a "custom picker binary" instead of its own dialog. It passes
//! the open windows in `XDPH_WINDOW_SHARING_LIST` and reads one line back:
//! `[SELECTION]<flags>/<kind>:<id>`, with `r` in the flags to allow a restore
//! token, and kind `screen`, `window` or `region`.
//!
//! This process draws nothing itself. It hands the list to the Quickshell
//! widget over a Unix socket and waits for the answer, so
//! the picker looks like the rest of the desktop. If the widget does not answer
//! within a moment (or nothing listens), it runs the stock picker, so
//! screen sharing never depends on obscura being healthy.

use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{Result, bail};
use serde::Serialize;
use serde_json::{Value, json};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Window {
    /// The id xdph expects back in `window:<handle>`.
    pub handle: String,
    pub class: String,
    pub title: String,
    /// Hyprland's window address, decimal.
    pub address: String,
}

/// `handle[HC>]class[HT>]title[HE>]address[HA>]`, repeated.
pub fn parse_windows(list: &str) -> Vec<Window> {
    let mut out = Vec::new();
    let mut rest = list;
    while let Some(end) = rest.find("[HA>]") {
        let entry = &rest[..end];
        rest = &rest[end + "[HA>]".len()..];
        let Some((handle, tail)) = entry.split_once("[HC>]") else { continue };
        let Some((class, tail)) = tail.split_once("[HT>]") else { continue };
        let Some((title, address)) = tail.split_once("[HE>]") else { continue };
        if handle.is_empty() {
            continue;
        }
        out.push(Window {
            handle: handle.trim().to_owned(),
            class: class.to_owned(),
            title: title.to_owned(),
            address: address.trim().to_owned(),
        });
    }
    out
}

/// The line xdph reads. `kind` is screen, window or region.
pub fn selection_line(kind: &str, id: &str, remember: bool) -> Result<String> {
    if !["screen", "window", "region"].contains(&kind) {
        bail!("unknown selection kind: {kind}");
    }
    if id.is_empty() || id.contains('\n') {
        bail!("bad selection id");
    }
    Ok(format!("[SELECTION]{}/{kind}:{id}", if remember { "r" } else { "" }))
}

/// Where the widget listens. Absent or refusing connections means "no widget".
pub fn socket_path() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
        .join("obscura/picker.sock")
}

/// How long the widget has to say it saw the request before we give up on it.
const ACK_WAIT: Duration = Duration::from_millis(2500);
/// How long a person gets to choose.
const ANSWER_WAIT: Duration = Duration::from_secs(600);

pub enum Outcome {
    /// Print this line, exit 0.
    Selected(String),
    /// The person closed the picker: exit non-zero.
    Cancelled,
    /// The widget is not there or not answering: run the stock picker.
    NoWidget,
}

/// One JSON line each way. We send `{"windows": [...]}`; the widget answers
/// `{"ack": true}` at once, then either `{"kind","value","remember"}` or
/// `{"cancel": true}` when the person has chosen.
pub fn ask_widget(list: &str) -> Result<Outcome> {
    ask_at(&socket_path(), list)
}

pub fn ask_at(path: &Path, list: &str) -> Result<Outcome> {
    let Ok(mut sock) = UnixStream::connect(path) else { return Ok(Outcome::NoWidget) };
    sock.set_write_timeout(Some(ACK_WAIT))?;
    let req = json!({ "windows": parse_windows(list) }).to_string();
    if sock.write_all(req.as_bytes()).and_then(|_| sock.write_all(b"\n")).is_err() {
        return Ok(Outcome::NoWidget);
    }

    let mut lines = BufReader::new(sock.try_clone()?);
    let mut next = |wait: Duration| -> Option<Value> {
        sock.set_read_timeout(Some(wait)).ok()?;
        let mut line = String::new();
        match lines.read_line(&mut line) {
            Ok(n) if n > 0 => serde_json::from_str(line.trim()).ok(),
            _ => None,
        }
    };
    if next(ACK_WAIT).is_none_or(|v| v["ack"] != true) {
        return Ok(Outcome::NoWidget);
    }
    let Some(v) = next(ANSWER_WAIT) else { return Ok(Outcome::NoWidget) };
    Ok(match (v["kind"].as_str(), v["value"].as_str()) {
        (Some(kind), Some(value)) => {
            Outcome::Selected(selection_line(kind, value, v["remember"].as_bool().unwrap_or(false))?)
        }
        _ => Outcome::Cancelled,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const LIST: &str = "1781998000[HC>]kitty[HT>]a title[HE>]94574999010272[HA>]\
                        1782008096[HC>]org.gnome.Boxes[HT>]Kutular[HE>]94574999690992[HA>]";

    #[test]
    fn parses_xdph_window_list() {
        let w = parse_windows(LIST);
        assert_eq!(w.len(), 2);
        assert_eq!(w[0].handle, "1781998000");
        assert_eq!(w[0].class, "kitty");
        assert_eq!(w[1].title, "Kutular");
        assert_eq!(w[1].address, "94574999690992");
    }

    #[test]
    fn titles_may_contain_odd_characters() {
        let w = parse_windows("7[HC>]firefox[HT>](32) A | B — Mozilla[HE>]9[HA>]");
        assert_eq!(w[0].title, "(32) A | B — Mozilla");
    }

    #[test]
    fn empty_or_broken_lists_give_no_windows() {
        assert!(parse_windows("").is_empty());
        assert!(parse_windows("garbage").is_empty());
        assert!(parse_windows("[HC>]x[HT>]y[HE>]1[HA>]").is_empty());
    }

    #[test]
    fn builds_selection_lines() {
        assert_eq!(selection_line("screen", "eDP-1", false).unwrap(), "[SELECTION]/screen:eDP-1");
        assert_eq!(selection_line("window", "42", true).unwrap(), "[SELECTION]r/window:42");
        assert!(selection_line("tab", "1", false).is_err());
        assert!(selection_line("screen", "", false).is_err());
    }
}

#[cfg(test)]
mod flow {
    use super::*;
    use std::os::unix::net::UnixListener;

    fn widget(path: PathBuf, answer: Option<&'static str>) -> std::thread::JoinHandle<Value> {
        let listener = UnixListener::bind(&path).unwrap();
        std::thread::spawn(move || {
            let (mut conn, _) = listener.accept().unwrap();
            let mut line = String::new();
            BufReader::new(conn.try_clone().unwrap()).read_line(&mut line).unwrap();
            let req: Value = serde_json::from_str(line.trim()).unwrap();
            if let Some(a) = answer {
                writeln!(conn, "{{\"ack\": true}}").unwrap();
                writeln!(conn, "{a}").unwrap();
            }
            req
        })
    }

    fn tmp(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("obscura-{name}-{}.sock", std::process::id()))
    }

    #[test]
    fn widget_picks_a_window_with_remember() {
        let p = tmp("pick");
        let w = widget(p.clone(), Some(r#"{"kind":"window","value":"1781998000","remember":true}"#));
        let out = ask_at(&p, "1781998000[HC>]kitty[HT>]t[HE>]1[HA>]").unwrap();
        let req = w.join().unwrap();
        assert_eq!(req["windows"][0]["class"], "kitty");
        assert!(matches!(out, Outcome::Selected(ref l) if l == "[SELECTION]r/window:1781998000"));
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn closing_the_picker_cancels() {
        let p = tmp("cancel");
        let w = widget(p.clone(), Some(r#"{"cancel":true}"#));
        assert!(matches!(ask_at(&p, "").unwrap(), Outcome::Cancelled));
        w.join().unwrap();
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn no_listener_means_no_widget() {
        assert!(matches!(ask_at(&tmp("none"), "").unwrap(), Outcome::NoWidget));
    }

    #[test]
    fn a_widget_that_hangs_up_falls_back() {
        let p = tmp("hangup");
        let w = widget(p.clone(), None);
        assert!(matches!(ask_at(&p, "").unwrap(), Outcome::NoWidget));
        w.join().unwrap();
        std::fs::remove_file(p).ok();
    }
}
