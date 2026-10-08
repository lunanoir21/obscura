//! Starting OBS when it is not running.

use std::os::unix::process::CommandExt;
use std::process::{Command, Stdio};

use anyhow::{Context, Result, bail};

/// True when a process called `obs` exists (what `pgrep -x obs` would find).
pub fn obs_running() -> bool {
    process_named(std::path::Path::new("/proc"), "obs")
}

fn process_named(proc_dir: &std::path::Path, name: &str) -> bool {
    std::fs::read_dir(proc_dir).into_iter().flatten().flatten().any(|e| {
        e.file_name().to_string_lossy().bytes().all(|b| b.is_ascii_digit())
            && std::fs::read_to_string(e.path().join("comm")).is_ok_and(|c| c.trim() == name)
    })
}

/// OBS's arguments: minimised to the tray so no window appears, and without the
/// "was OBS shut down properly" dialog a crashed run would otherwise show.
pub fn args(start_recording: bool) -> Vec<&'static str> {
    let mut a = vec!["--minimize-to-tray", "--disable-shutdown-check"];
    if start_recording {
        a.push("--startrecording");
    }
    a
}

/// Starts OBS in the background, detached from whoever called us. A second copy
/// is never started: when OBS already runs the problem is elsewhere (its
/// WebSocket server), and the error says so.
pub fn start_obs(start_recording: bool) -> Result<()> {
    if obs_running() {
        bail!("OBS is running but obscura cannot reach it: check Tools > WebSocket Server Settings and the port in obscura");
    }
    Command::new("obs")
        .args(args(start_recording))
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .process_group(0)
        .spawn()
        .context("cannot start obs")?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_a_process_by_comm() {
        let root = std::env::temp_dir().join(format!("obscura-proc-{}", std::process::id()));
        std::fs::create_dir_all(root.join("123")).unwrap();
        std::fs::write(root.join("123/comm"), "obs\n").unwrap();
        std::fs::create_dir_all(root.join("456")).unwrap();
        std::fs::write(root.join("456/comm"), "firefox\n").unwrap();
        std::fs::create_dir_all(root.join("self")).unwrap();
        std::fs::write(root.join("self/comm"), "obs\n").unwrap();
        assert!(process_named(&root, "obs"));
        assert!(!process_named(&root, "kitty"));
        std::fs::remove_file(root.join("123/comm")).unwrap();
        assert!(!process_named(&root, "obs")); // "self" is not a pid
        std::fs::remove_dir_all(root).ok();
    }

    #[test]
    fn recording_flag_is_optional() {
        assert!(args(true).contains(&"--startrecording"));
        assert!(!args(false).contains(&"--startrecording"));
        assert!(args(false).contains(&"--minimize-to-tray"));
    }
}
