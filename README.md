# obscura

A thin control layer for OBS Studio on Hyprland. A small button in your Quickshell bar that grows into a pill while you record, a panel for the details, and a shortcut that works from anywhere.

obscura drives the OBS you already have through its built-in WebSocket server (obs-websocket v5). It does not encode anything itself, so your scenes, sources and encoder settings stay in OBS.

> Status: early. The command line and the bar pill work; the panel is next. See the roadmap below.

## Design goals

- **Idle costs nothing.** No polling loop. The client blocks on the socket; an idle process uses no CPU.
- **Never lie about state.** The recording dot lights only when OBS reports it started.
- **Fail fast.** If OBS is not running, a command returns in milliseconds with a clear message.
- **Zero config.** Port and password are read from OBS's own settings. Nothing is written back.

## Use

```sh
obscura doctor   # check OBS and its WebSocket server
obscura toggle   # start, or stop and print the saved file
obscura status   # recording state as JSON
obscura pause
```

Enable the server in OBS first: Tools > WebSocket Server Settings.

Bind it in Hyprland:

```
bind = SUPER ALT, R, exec, obscura toggle
```

## Roadmap

- [x] M0: authentication, start/stop/pause from the CLI
- [x] M1: `obscura watch` and the bar pill (live OBS test pending)
- [ ] M2: panel (scene, sources, replay buffer, recording settings)
- [ ] M3: shortcut, settings, hooks

## License

MIT
