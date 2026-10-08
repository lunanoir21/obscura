use anyhow::{Result, bail};
use clap::{Parser, Subcommand};
use obscura_core::{Client, Connection, client::{ConnectError, events}, control, launch};
use serde_json::json;

#[derive(Parser)]
#[command(name = "obscura", version, about = "Control OBS recording from the terminal")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Print recording state as JSON
    Status,
    /// Start recording
    Start,
    /// Stop recording and print the saved file
    Stop,
    /// Start when idle, stop when recording
    Toggle,
    /// Pause or resume
    Pause,
    /// Print state changes as JSON lines until killed (used by the bar widget)
    Watch,
    /// Scenes, audio inputs, video and recording settings as JSON
    Info,
    /// Switch the current scene
    Scene { name: String },
    /// Toggle mute on an audio input
    Mute { input: String },
    /// Replay buffer: start, stop or save
    Replay { action: String },
    /// Save a PNG of the current scene and print its path
    Shot,
    /// Change a recording setting: fps, resolution, dir, filename, format, replay-seconds
    Set { key: String, value: String },
    /// obscura's own widget settings
    Config {
        #[command(subcommand)]
        action: ConfigCmd,
    },
    /// Send any obs-websocket request and print the response (for debugging)
    #[command(hide = true)]
    Raw { kind: String, data: Option<String> },
    /// Screen-share picker for xdg-desktop-portal-hyprland (run by xdph, not by hand)
    Picker,
    /// Make xdph use obscura's picker, or go back to its own
    PickerSetup {
        #[arg(value_parser = ["install", "uninstall"])]
        action: String,
    },
    /// Print audio input levels as JSON lines until killed (used by the panel)
    Meters,
    /// List the folders inside a path as JSON (for the widget's folder chooser)
    Ls { path: String },
    /// Start OBS in the background (minimised, not recording) if it is not running
    Open,
    /// Check that OBS and its WebSocket server are reachable
    Doctor,
}

#[derive(Subcommand)]
enum ConfigCmd {
    /// Print the settings as JSON
    Get,
    /// Change one: timer_font, timer_size, button_style
    Set { key: String, value: String },
}

fn main() {
    if let Err(e) = run() {
        eprintln!("obscura: {e:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    let conn = Connection::discover();
    if matches!(cli.cmd, Cmd::Doctor) {
        return doctor(&conn);
    }
    if let Cmd::PickerSetup { action } = &cli.cmd {
        let msg = if action == "install" {
            obscura_core::install::install()?
        } else {
            obscura_core::install::uninstall()?
        };
        println!("{msg}\nrestart the portal to apply: systemctl --user restart xdg-desktop-portal-hyprland");
        return Ok(());
    }
    if let Cmd::Ls { path } = &cli.cmd {
        println!("{}", control::browse(path)?);
        return Ok(());
    }
    if matches!(cli.cmd, Cmd::Picker) {
        return picker();
    }
    if let Cmd::Config { action } = &cli.cmd {
        match action {
            ConfigCmd::Get => println!("{}", obscura_core::uiconfig::get()),
            ConfigCmd::Set { key, value } => obscura_core::uiconfig::set(key, value)?,
        }
        return Ok(());
    }
    if matches!(cli.cmd, Cmd::Meters) {
        return meters(&conn);
    }
    if matches!(cli.cmd, Cmd::Watch) {
        return watch(&conn);
    }
    let mut c = match Client::connect(&conn, events::NONE) {
        Ok(c) => c,
        // OBS is closed: starting or toggling a recording opens it (and records),
        // `open` just opens it.
        Err(ConnectError::Unreachable(_)) if matches!(cli.cmd, Cmd::Start | Cmd::Toggle | Cmd::Open) => {
            launch::start_obs(!matches!(cli.cmd, Cmd::Open))?;
            return Ok(());
        }
        Err(e) => return Err(e.into()),
    };
    if matches!(cli.cmd, Cmd::Open) {
        return Ok(()); // already reachable
    }
    match cli.cmd {
        Cmd::Status => {
            let s = c.record_status()?;
            println!(
                "{}",
                json!({ "recording": s.output_active, "paused": s.output_paused,
                        "timecode": s.output_timecode, "bytes": s.output_bytes })
            );
        }
        Cmd::Start => {
            if c.record_status()?.output_active {
                bail!("already recording");
            }
            c.start_record()?;
        }
        Cmd::Stop => {
            if !c.record_status()?.output_active {
                bail!("not recording");
            }
            if let Some(path) = c.stop_record()? {
                println!("{}", json!({ "path": path }));
            }
        }
        Cmd::Toggle => {
            if c.record_status()?.output_active {
                if let Some(path) = c.stop_record()? {
                    println!("{}", json!({ "path": path }));
                }
            } else {
                c.start_record()?;
            }
        }
        Cmd::Pause => c.toggle_pause()?,
        Cmd::Info => println!("{}", control::info(&mut c)?),
        Cmd::Scene { name } => control::set_scene(&mut c, &name)?,
        Cmd::Mute { input } => control::toggle_mute(&mut c, &input)?,
        Cmd::Replay { action } => control::replay(&mut c, &action)?,
        Cmd::Shot => println!("{}", json!({ "path": control::screenshot(&mut c)? })),
        Cmd::Set { key, value } => control::set(&mut c, &key, &value)?,
        Cmd::Raw { kind, data } => {
            let data = match data {
                Some(d) => serde_json::from_str(&d)?,
                None => serde_json::Value::Null,
            };
            println!("{}", c.request(&kind, data)?);
        }
        Cmd::Config { .. } => unreachable!(),
        Cmd::Doctor | Cmd::Watch | Cmd::Meters | Cmd::Open | Cmd::Ls { .. } | Cmd::Picker | Cmd::PickerSetup { .. } => unreachable!(),
    }
    Ok(())
}

fn doctor(conn: &Connection) -> Result<()> {
    println!("target      {}:{}", conn.host, conn.port);
    println!("password    {}", if conn.password.is_some() { "found" } else { "none" });
    match conn.server_enabled {
        Some(false) => println!("note        OBS has the WebSocket server switched off (Tools > WebSocket Server Settings)"),
        _ => {}
    }
    match Client::connect(conn, events::NONE) {
        Ok(mut c) => {
            let s = c.record_status()?;
            println!("connection  ok");
            println!("recording   {}", s.output_active);
        }
        Err(e) => println!("connection  failed: {e:#}"),
    }
    Ok(())
}

fn watch(conn: &Connection) -> Result<()> {
    use std::io::Write;
    obscura_core::watch::run(conn, |state| {
        if let Some(path) = state.and_then(|s| s.saved.as_deref()) {
            let cfg = obscura_core::uiconfig::get();
            obscura_core::hooks::on_saved(
                path,
                cfg["notify_saved"].as_bool().unwrap_or(true),
                cfg["copy_path"].as_bool().unwrap_or(false),
            );
        }
        let mut out = std::io::stdout().lock();
        // A closed pipe means the widget is gone: stop instead of lingering.
        state.map_or(true, |s| serde_json::to_writer(&mut out, s).is_ok())
            && out.write_all(b"\n").is_ok()
            && out.flush().is_ok()
    });
    Ok(())
}

/// Asks the widget; if there is none, the stock picker takes over unchanged.
fn picker() -> Result<()> {
    use obscura_core::picker::{Outcome, ask_widget};
    use std::os::unix::process::CommandExt;
    let list = std::env::var("XDPH_WINDOW_SHARING_LIST").unwrap_or_default();
    match ask_widget(&list) {
        Ok(Outcome::Selected(line)) => {
            println!("{line}");
            Ok(())
        }
        Ok(Outcome::Cancelled) => std::process::exit(1),
        Ok(Outcome::NoWidget) | Err(_) => {
            let err = std::process::Command::new("hyprland-share-picker").exec();
            bail!("cannot run hyprland-share-picker: {err}")
        }
    }
}

fn meters(conn: &Connection) -> Result<()> {
    use std::io::Write;
    obscura_core::meters::run(conn, |levels| {
        let mut out = std::io::stdout().lock();
        levels.map_or(true, |l| serde_json::to_writer(&mut out, l).is_ok())
            && out.write_all(b"\n").is_ok()
            && out.flush().is_ok()
    });
    Ok(())
}
