//! obscura's own small settings (how the widget looks). OBS settings live in
//! OBS; this file holds only what OBS has no place for.

use std::path::PathBuf;

use anyhow::{Result, bail};
use serde_json::{Map, Value, json};

fn path() -> Option<PathBuf> {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
    Some(base.join("obscura/config.json"))
}

fn defaults() -> Map<String, Value> {
    let v = json!({ "timer_font": "Space Mono", "timer_size": 18, "button_style": "circle" });
    v.as_object().cloned().unwrap_or_default()
}

/// Defaults overlaid with whatever the file holds; a missing or broken file
/// just means defaults.
pub fn get() -> Value {
    let mut out = defaults();
    let saved: Option<Map<String, Value>> = path()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .and_then(|s| serde_json::from_str(&s).ok());
    for (k, v) in saved.into_iter().flatten() {
        if out.contains_key(&k) {
            out.insert(k, v);
        }
    }
    Value::Object(out)
}

fn validate(key: &str, value: &str) -> Result<Value> {
    Ok(match key {
        "timer_font" => {
            if value.is_empty() || value.len() > 64 {
                bail!("timer_font: a font family name");
            }
            json!(value)
        }
        "timer_size" => {
            let n: u32 = value.parse().ok().filter(|n| (10..=32).contains(n)).ok_or_else(|| anyhow::anyhow!("timer_size must be 10-32"))?;
            json!(n)
        }
        "button_style" => {
            if !["circle", "pill", "icon"].contains(&value) {
                bail!("button_style: circle, pill or icon");
            }
            json!(value)
        }
        other => bail!("unknown key: {other}"),
    })
}

pub fn set(key: &str, value: &str) -> Result<()> {
    let new = validate(key, value)?;
    let Some(p) = path() else { bail!("no home directory") };
    let mut cur = get();
    cur[key] = new;
    if let Some(dir) = p.parent() {
        std::fs::create_dir_all(dir)?;
    }
    // Write beside, then rename: a crash never leaves half a file.
    let tmp = p.with_extension("json.tmp");
    std::fs::write(&tmp, serde_json::to_vec_pretty(&cur)?)?;
    std::fs::rename(tmp, p)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_out_of_range_and_unknown() {
        assert!(validate("timer_size", "9").is_err());
        assert!(validate("timer_size", "24").is_ok());
        assert!(validate("button_style", "blob").is_err());
        assert!(validate("nope", "1").is_err());
    }
}
