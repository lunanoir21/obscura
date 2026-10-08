//! Everything the panel asks OBS for or tells it to do, as small functions on a
//! connected [`Client`]. One short-lived connection per call keeps the widget
//! free of state to keep in sync: it asks `info`, draws, and asks again after
//! each action.

use anyhow::{Result, bail};
use serde_json::{Value, json};

use crate::client::Client;

fn s(v: &Value, key: &str) -> Option<String> {
    v[key].as_str().map(str::to_owned)
}

/// OBS stores the recording container under one key in both output modes.
const FORMATS: [(&str, &str); 3] = [("mkv", "mkv"), ("mp4", "hybrid_mp4"), ("mov", "mov")];

fn profile(c: &mut Client, category: &str, name: &str) -> Option<String> {
    let v = c
        .request("GetProfileParameter", json!({ "parameterCategory": category, "parameterName": name }))
        .ok()?;
    s(&v, "parameterValue")
}

fn set_profile(c: &mut Client, category: &str, name: &str, value: &str) -> Result<()> {
    c.request(
        "SetProfileParameter",
        json!({ "parameterCategory": category, "parameterName": name, "parameterValue": value }),
    )
    .map(drop)
}

/// "SimpleOutput" or "AdvOut", whichever the profile currently uses.
fn output_section(c: &mut Client) -> &'static str {
    match profile(c, "Output", "Mode").as_deref() {
        Some("Advanced") => "AdvOut",
        _ => "SimpleOutput",
    }
}

/// The fastest real display's refresh rate, in whole Hz. A capture cannot be
/// smoother than the screen it copies, so this is the useful ceiling for the
/// frame rate. `None` when Hyprland cannot be asked.
pub fn max_refresh_hz() -> Option<u32> {
    let out = std::process::Command::new("hyprctl").args(["monitors", "-j"]).output().ok()?;
    max_refresh(&String::from_utf8_lossy(&out.stdout))
}

pub fn max_refresh(monitors_json: &str) -> Option<u32> {
    let v: Value = serde_json::from_str(monitors_json).ok()?;
    v.as_array()?
        .iter()
        .filter(|m| !m["name"].as_str().unwrap_or_default().starts_with("HEADLESS"))
        .filter_map(|m| m["refreshRate"].as_f64())
        .map(|r| r.floor() as u32)
        .max()
        .filter(|hz| *hz > 0)
}

pub fn info(c: &mut Client) -> Result<Value> {
    let status = c.record_status()?;

    let mut scenes = Vec::new();
    let mut scene = Value::Null;
    if let Ok(v) = c.request("GetSceneList", Value::Null) {
        scene = v["currentProgramSceneName"].clone();
        if let Some(list) = v["scenes"].as_array() {
            // OBS lists the newest scene first; show them in the order made.
            scenes = list.iter().rev().filter_map(|x| s(x, "sceneName")).collect();
        }
    }

    // Only inputs that carry audio answer GetInputMute; the rest are skipped.
    let mut inputs = Vec::new();
    if let Ok(v) = c.request("GetInputList", Value::Null) {
        for name in v["inputs"].as_array().into_iter().flatten().filter_map(|x| s(x, "inputName")) {
            if let Ok(m) = c.request("GetInputMute", json!({ "inputName": name })) {
                inputs.push(json!({ "name": name, "muted": m["inputMuted"] }));
            }
        }
    }

    let video = c.request("GetVideoSettings", Value::Null).ok().map(|v| {
        let fps = v["fpsNumerator"].as_f64().unwrap_or(30.0) / v["fpsDenominator"].as_f64().unwrap_or(1.0).max(1.0);
        json!({ "fps": fps.round(), "base_w": v["baseWidth"], "base_h": v["baseHeight"],
                "out_w": v["outputWidth"], "out_h": v["outputHeight"] })
    });

    let dir = c.request("GetRecordDirectory", Value::Null).ok().and_then(|v| s(&v, "recordDirectory"));
    let section = output_section(c);
    let filename = profile(c, "Output", "FilenameFormatting");
    let raw_format = profile(c, section, "RecFormat2").unwrap_or_default();
    let format = FORMATS.iter().find(|(_, v)| *v == raw_format).map(|(k, _)| *k);
    let replay_secs = profile(c, section, "RecRBTime").and_then(|v| v.parse::<u32>().ok());
    let replay_enabled = profile(c, section, "RecRB").as_deref() == Some("true");
    let replay_active = c
        .request("GetReplayBufferStatus", Value::Null)
        .ok()
        .and_then(|v| v["outputActive"].as_bool())
        .unwrap_or(false);

    Ok(json!({
        "recording": status.output_active,
        "scenes": scenes, "scene": scene, "inputs": inputs, "video": video,
        "record": { "dir": dir, "filename": filename, "format": format, "mode": section },
        "limits": { "max_fps": max_refresh_hz() },
        "replay": { "enabled": replay_enabled, "active": replay_active, "seconds": replay_secs },
    }))
}

pub fn set_scene(c: &mut Client, name: &str) -> Result<()> {
    c.request("SetCurrentProgramScene", json!({ "sceneName": name })).map(drop)
}

pub fn toggle_mute(c: &mut Client, input: &str) -> Result<()> {
    c.request("ToggleInputMute", json!({ "inputName": input })).map(drop)
}

pub fn replay(c: &mut Client, action: &str) -> Result<()> {
    let kind = match action {
        "start" => "StartReplayBuffer",
        "stop" => "StopReplayBuffer",
        "save" => "SaveReplayBuffer",
        other => bail!("unknown replay action: {other} (start, stop, save)"),
    };
    c.request(kind, Value::Null).map(drop)
}

/// A PNG of the current program scene, next to the recordings.
pub fn screenshot(c: &mut Client) -> Result<String> {
    let scene = c.request("GetCurrentProgramScene", Value::Null)?;
    let name = s(&scene, "sceneName").or_else(|| s(&scene, "currentProgramSceneName"));
    let Some(name) = name else { bail!("OBS did not name the current scene") };
    let dir = c
        .request("GetRecordDirectory", Value::Null)
        .ok()
        .and_then(|v| s(&v, "recordDirectory"))
        .unwrap_or_else(|| ".".into());
    let stamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let path = format!("{}/obscura-{stamp}.png", dir.trim_end_matches('/'));
    c.request(
        "SaveSourceScreenshot",
        json!({ "sourceName": name, "imageFormat": "png", "imageFilePath": path }),
    )?;
    Ok(path)
}

/// Changes one recording setting. OBS refuses video changes while recording;
/// that refusal is passed on as the error.
pub fn set(c: &mut Client, key: &str, value: &str) -> Result<()> {
    match key {
        "fps" => {
            let fps: u32 = value.parse().ok().filter(|f| (1..=240).contains(f)).ok_or_else(|| anyhow::anyhow!("fps must be 1-240"))?;
            c.request("SetVideoSettings", json!({ "fpsNumerator": fps, "fpsDenominator": 1 })).map(drop)
        }
        "resolution" => {
            let v = c.request("GetVideoSettings", Value::Null)?;
            let (bw, bh) = (v["baseWidth"].as_u64().unwrap_or(1920), v["baseHeight"].as_u64().unwrap_or(1080));
            let out_h = if value == "native" {
                bh
            } else {
                value.trim_end_matches('p').parse().ok().filter(|h| (144..=4320).contains(h)).ok_or_else(|| anyhow::anyhow!("resolution: native or a height like 1080"))?
            };
            // Keep the aspect ratio; encoders want even sizes.
            let out_w = (bw * out_h / bh) & !1;
            c.request("SetVideoSettings", json!({ "outputWidth": out_w, "outputHeight": out_h & !1 })).map(drop)
        }
        "dir" => {
            if !value.starts_with('/') {
                bail!("dir must be an absolute path");
            }
            c.request("SetRecordDirectory", json!({ "recordDirectory": value })).map(drop)
        }
        "filename" => {
            if value.trim().is_empty() || value.contains('/') {
                bail!("filename pattern must not be empty or contain '/'");
            }
            set_profile(c, "Output", "FilenameFormatting", value)
        }
        "format" => {
            let Some((_, raw)) = FORMATS.iter().find(|(k, _)| *k == value) else {
                bail!("format: mkv, mp4 or mov");
            };
            let section = output_section(c);
            set_profile(c, section, "RecFormat2", raw)
        }
        "replay-seconds" => {
            let secs: u32 = value.parse().ok().filter(|s| (5..=1200).contains(s)).ok_or_else(|| anyhow::anyhow!("replay-seconds must be 5-1200"))?;
            let section = output_section(c);
            set_profile(c, section, "RecRBTime", &secs.to_string())
        }
        other => bail!("unknown setting: {other}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn picks_the_fastest_real_display() {
        let json = r#"[{"name":"eDP-1","refreshRate":144.003},{"name":"HEADLESS-IO","refreshRate":240.0},{"name":"DP-2","refreshRate":59.95}]"#;
        assert_eq!(max_refresh(json), Some(144));
    }

    #[test]
    fn no_answer_when_hyprland_is_silent() {
        assert_eq!(max_refresh(""), None);
        assert_eq!(max_refresh("[]"), None);
    }
}
