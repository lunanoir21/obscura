use anyhow::{Result, bail};
use clap::{Parser, Subcommand};
use obscura_core::{Client, Connection, client::events};
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
    /// Check that OBS and its WebSocket server are reachable
    Doctor,
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
    if matches!(cli.cmd, Cmd::Watch) {
        return watch(&conn);
    }
    let mut c = Client::connect(&conn, events::NONE)?;
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
        Cmd::Doctor | Cmd::Watch => unreachable!(),
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
        let mut out = std::io::stdout().lock();
        // A closed pipe means the widget is gone: stop instead of lingering.
        state.map_or(true, |s| serde_json::to_writer(&mut out, s).is_ok())
            && out.write_all(b"\n").is_ok()
            && out.flush().is_ok()
    });
    Ok(())
}
