//! Points xdg-desktop-portal-hyprland at `obscura picker`, and back.
//!
//! The setting lives in `~/.config/hypr/xdph.conf` as
//! `screencopy { custom_picker_binary = ... }`. We touch only that one line.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result};

const KEY: &str = "custom_picker_binary";

fn conf_path() -> Result<PathBuf> {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))
        .context("no home directory")?;
    Ok(base.join("hypr/xdph.conf"))
}

/// `text` with the picker line set to `value`, or removed when `value` is None.
pub fn edit(text: &str, value: Option<&str>) -> String {
    let is_key = |l: &str| l.trim_start().starts_with(KEY);
    let mut lines: Vec<String> = text.lines().map(str::to_owned).collect();
    match value {
        Some(v) => {
            let line = format!("    {KEY} = {v}");
            if let Some(i) = lines.iter().position(|l| is_key(l)) {
                lines[i] = line;
            } else if let Some(i) = lines.iter().position(|l| {
                let t = l.trim();
                t.starts_with("screencopy") && t.ends_with('{')
            }) {
                lines.insert(i + 1, line);
            } else {
                if lines.last().is_some_and(|l| !l.trim().is_empty()) {
                    lines.push(String::new());
                }
                lines.extend(["screencopy {".to_owned(), line, "}".to_owned()]);
            }
        }
        None => lines.retain(|l| !is_key(l)),
    }
    let mut out = lines.join("\n");
    out.push('\n');
    out
}

fn wrapper(exe: &Path) -> Result<PathBuf> {
    let dir = std::env::var_os("HOME").map(PathBuf::from).context("no home directory")?.join(".local/share/obscura");
    std::fs::create_dir_all(&dir)?;
    let path = dir.join("picker.sh");
    std::fs::write(&path, format!("#!/bin/sh\nexec '{}' picker \"$@\"\n", exe.display()))?;
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755))?;
    Ok(path)
}

pub fn install() -> Result<String> {
    let exe = std::env::current_exe()?.canonicalize()?;
    let script = wrapper(&exe)?;
    let conf = conf_path()?;
    let old = std::fs::read_to_string(&conf).unwrap_or_default();
    if conf.exists() {
        let bak = conf.with_extension("conf.obscura-bak");
        if !bak.exists() {
            std::fs::copy(&conf, bak)?;
        }
    }
    std::fs::write(&conf, edit(&old, Some(&script.display().to_string())))?;
    Ok(format!("{} -> {}", conf.display(), script.display()))
}

pub fn uninstall() -> Result<String> {
    let conf = conf_path()?;
    if let Ok(old) = std::fs::read_to_string(&conf) {
        std::fs::write(&conf, edit(&old, None))?;
    }
    Ok(format!("removed from {}", conf.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn creates_the_block_in_an_empty_file() {
        assert_eq!(edit("", Some("/x/p.sh")), "screencopy {\n    custom_picker_binary = /x/p.sh\n}\n");
    }

    #[test]
    fn adds_to_an_existing_screencopy_block() {
        let out = edit("screencopy {\n    max_fps = 60\n}\n", Some("/x"));
        assert_eq!(out, "screencopy {\n    custom_picker_binary = /x\n    max_fps = 60\n}\n");
    }

    #[test]
    fn replaces_and_removes_only_its_own_line() {
        let a = edit("screencopy {\n    custom_picker_binary = /old\n    max_fps = 60\n}\n", Some("/new"));
        assert!(a.contains("= /new") && !a.contains("/old") && a.contains("max_fps"));
        let b = edit(&a, None);
        assert!(!b.contains(KEY) && b.contains("max_fps"));
    }

    #[test]
    fn leaves_other_sections_alone() {
        let out = edit("other {\n    a = 1\n}\n", Some("/x"));
        assert!(out.starts_with("other {\n    a = 1\n}\n\nscreencopy {"));
    }
}
