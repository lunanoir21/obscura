//! What happens when a recording has been saved.
//!
//! Built-in: a notification and, if switched on, the path on the clipboard.
//! Yours: every executable in `~/.config/obscura/hooks/saved.d/` runs with the
//! file path as its first argument and in `OBSCURA_PATH`.
//!
//! Hooks never block the caller and never fail it: they run on their own
//! threads and their errors are ignored.

use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

fn spawn(mut cmd: Command) {
    std::thread::spawn(move || {
        let _ = cmd
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .and_then(|mut c| c.wait());
    });
}

pub fn hooks_dir() -> Option<PathBuf> {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
    Some(base.join("obscura/hooks/saved.d"))
}

/// Executable files in a directory, sorted by name. Missing directory: none.
pub fn scripts_in(dir: &Path) -> Vec<PathBuf> {
    use std::os::unix::fs::PermissionsExt;
    let mut found: Vec<PathBuf> = std::fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_file() && p.metadata().is_ok_and(|m| m.permissions().mode() & 0o111 != 0))
        .collect();
    found.sort();
    found
}

pub fn on_saved(path: &str, notify: bool, copy_path: bool) {
    let name = Path::new(path).file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    if notify {
        let mut c = Command::new("notify-send");
        let title = if crate::uiconfig::lang() == "tr" { "Kayıt kaydedildi" } else { "Recording saved" };
        c.args(["-a", "obscura", "-i", "media-record", title, &name]);
        spawn(c);
    }
    if copy_path {
        let mut c = Command::new("sh");
        c.args(["-c", r#"printf %s "$1" | wl-copy"#, "sh", path]);
        spawn(c);
    }
    if let Some(dir) = hooks_dir() {
        for script in scripts_in(&dir) {
            let mut c = Command::new(script);
            c.arg(path).env("OBSCURA_PATH", path);
            spawn(c);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;

    #[test]
    fn lists_only_executable_files_in_order() {
        let dir = std::env::temp_dir().join(format!("obscura-hooks-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        for (name, mode) in [("20-b.sh", 0o755), ("10-a.sh", 0o755), ("notes.txt", 0o644)] {
            let p = dir.join(name);
            std::fs::write(&p, "#!/bin/sh\n").unwrap();
            std::fs::set_permissions(&p, std::fs::Permissions::from_mode(mode)).unwrap();
        }
        let names: Vec<_> = scripts_in(&dir).iter().map(|p| p.file_name().unwrap().to_string_lossy().into_owned()).collect();
        assert_eq!(names, ["10-a.sh", "20-b.sh"]);
        assert!(scripts_in(&dir.join("missing")).is_empty());
        std::fs::remove_dir_all(dir).ok();
    }
}
