//! Where to connect and with which password.
//!
//! Zero-config on purpose: OBS already stores the port and password it expects,
//! so we read them from there. Environment variables override. We never write
//! to OBS's config and never print the password.

use serde::Deserialize;

use crate::paths;

#[derive(Debug, Clone)]
pub struct Connection {
    pub host: String,
    pub port: u16,
    pub password: Option<String>,
    /// `server_enabled` as OBS has it saved, when we could read it.
    pub server_enabled: Option<bool>,
}

#[derive(Deserialize, Default)]
struct ObsConfig {
    server_enabled: Option<bool>,
    server_port: Option<u16>,
    server_password: Option<String>,
    auth_required: Option<bool>,
}

impl Connection {
    pub fn discover() -> Self {
        let obs: ObsConfig = paths::obs_websocket_config()
            .and_then(|p| std::fs::read_to_string(p).ok())
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default();

        let password = std::env::var("OBSCURA_PASSWORD").ok().or_else(|| {
            match obs.auth_required {
                Some(false) => None,
                _ => obs.server_password.filter(|p| !p.is_empty()),
            }
        });
        let port = std::env::var("OBSCURA_PORT")
            .ok()
            .and_then(|p| p.parse().ok())
            .or(obs.server_port)
            .unwrap_or(4455);

        Self {
            host: std::env::var("OBSCURA_HOST").unwrap_or_else(|_| "127.0.0.1".into()),
            port,
            password,
            server_enabled: obs.server_enabled,
        }
    }
}
