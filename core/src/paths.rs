use std::path::PathBuf;

fn home() -> Option<PathBuf> {
    std::env::var_os("HOME").map(PathBuf::from)
}

fn config_home() -> Option<PathBuf> {
    std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .or_else(|| home().map(|h| h.join(".config")))
}

/// OBS's own obs-websocket settings. Read-only for us.
pub fn obs_websocket_config() -> Option<PathBuf> {
    config_home().map(|c| c.join("obs-studio/plugin_config/obs-websocket/config.json"))
}
