//! A screen-share picker for xdg-desktop-portal-hyprland.
//!
//! xdph can run a "custom picker binary" instead of its own dialog. It passes
//! the open windows in `XDPH_WINDOW_SHARING_LIST` and reads one line back:
//! `[SELECTION]<flags>/<kind>:<id>`, with `r` in the flags to allow a restore
//! token, and kind `screen`, `window` or `region`.
//!
//! This process draws nothing itself. It hands the list to the Quickshell
//! widget through files in the runtime directory and waits for the answer, so
//! the picker looks like the rest of the desktop. If the widget does not answer
//! within a moment (Quickshell not running), it runs the stock picker, so
//! screen sharing never depends on obscura being healthy.

use std::path::{Path, PathBuf};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

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

fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
        .join("obscura")
}

fn now_ms() -> u128 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0)
}

fn write_atomic(path: &Path, text: &str) -> Result<()> {
    let tmp = path.with_extension("tmp");
    std::fs::write(&tmp, text)?;
    std::fs::rename(tmp, path)?;
    Ok(())
}

fn read_json(path: &Path) -> Option<Value> {
    serde_json::from_str(&std::fs::read_to_string(path).ok()?).ok()
}

/// How long the widget has to say it saw the request before we give up on it.
const ACK_WAIT: Duration = Duration::from_millis(2500);
/// How long a person gets to choose.
const ANSWER_WAIT: Duration = Duration::from_secs(600);
const POLL: Duration = Duration::from_millis(60);

pub enum Outcome {
    /// Print this line, exit 0.
    Selected(String),
    /// The person closed the picker: exit non-zero.
    Cancelled,
    /// The widget never answered: run the stock picker.
    NoWidget,
}

pub fn ask_widget(list: &str) -> Result<Outcome> {
    let dir = runtime_dir();
    std::fs::create_dir_all(&dir)?;
    let (req, ack, ans) = (dir.join("request.json"), dir.join("ack.json"), dir.join("answer.json"));
    let id = format!("{}-{}", now_ms(), std::process::id());
    let _ = std::fs::remove_file(&ack);
    let _ = std::fs::remove_file(&ans);
    write_atomic(
        &req,
        &json!({ "id": id, "ts": now_ms() as u64, "windows": parse_windows(list) }).to_string(),
    )?;

    let mine = |p: &Path| read_json(p).is_some_and(|v| v["id"] == id);
    let started = Instant::now();
    let outcome = loop {
        if mine(&ans) {
            let v = read_json(&ans).unwrap_or(Value::Null);
            break match (v["kind"].as_str(), v["value"].as_str()) {
                (Some(kind), Some(value)) => {
                    Outcome::Selected(selection_line(kind, value, v["remember"].as_bool().unwrap_or(false))?)
                }
                _ => Outcome::Cancelled,
            };
        }
        let acked = mine(&ack);
        if !acked && started.elapsed() > ACK_WAIT {
            break Outcome::NoWidget;
        }
        if started.elapsed() > ANSWER_WAIT {
            break Outcome::Cancelled;
        }
        std::thread::sleep(POLL);
    };
    let _ = std::fs::remove_file(&req);
    let _ = std::fs::remove_file(&ack);
    let _ = std::fs::remove_file(&ans);
    Ok(outcome)
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

    // One test owns XDG_RUNTIME_DIR for the whole process.
    #[test]
    fn widget_answers_and_stale_files_are_cleaned_up() {
        let dir = std::env::temp_dir().join(format!("obscura-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        // SAFETY: no other test in this binary reads or sets the variable.
        unsafe { std::env::set_var("XDG_RUNTIME_DIR", &dir) };
        let run = dir.join("obscura");

        // A widget that acks, then picks a window with "remember".
        let run2 = run.clone();
        let widget = std::thread::spawn(move || {
            let req = run2.join("request.json");
            let v = loop {
                if let Some(v) = read_json(&req) {
                    break v;
                }
                std::thread::sleep(Duration::from_millis(20));
            };
            let id = v["id"].as_str().unwrap().to_owned();
            assert_eq!(v["windows"][0]["class"], "kitty");
            write_atomic(&run2.join("ack.json"), &json!({ "id": id }).to_string()).unwrap();
            write_atomic(
                &run2.join("answer.json"),
                &json!({ "id": id, "kind": "window", "value": "1781998000", "remember": true }).to_string(),
            )
            .unwrap();
        });
        let out = ask_widget("1781998000[HC>]kitty[HT>]t[HE>]1[HA>]").unwrap();
        widget.join().unwrap();
        assert!(matches!(out, Outcome::Selected(ref l) if l == "[SELECTION]r/window:1781998000"));
        assert!(!run.join("request.json").exists());

        // Nobody home: falls through to the stock picker after the ack timeout.
        let out = ask_widget("").unwrap();
        assert!(matches!(out, Outcome::NoWidget));
        std::fs::remove_dir_all(&dir).ok();
    }
}
