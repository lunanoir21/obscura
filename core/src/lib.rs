//! obscura core: a small, blocking client for the obs-websocket v5 protocol.
//!
//! Nothing here spawns threads or polls on a timer. A call blocks on the socket
//! with a read timeout, so an idle process costs no CPU.

pub mod auth;
pub mod client;
pub mod config;
pub mod hooks;
pub mod install;
pub mod launch;
pub mod meters;
pub mod control;
pub mod uiconfig;
pub mod paths;
pub mod picker;
pub mod watch;

pub use client::{Client, RecordStatus};
pub use config::Connection;
