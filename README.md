# obscura

A thin control layer for OBS Studio on Hyprland. A small button in your Quickshell bar that grows into a pill while you record, a panel for the details, and a shortcut that works from anywhere.

obscura drives the OBS you already have through its built-in WebSocket server (obs-websocket v5). It does not encode anything itself, so your scenes, sources and encoder settings stay in OBS.

> Status: early. The command line, the bar pill and the panel work; shortcut, hooks and level meters are next. See the roadmap below.

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

## Screen-share picker

OBS asks for the screen through the desktop portal each time it starts, and the stock dialog does not match the rest of the desktop. obscura ships a picker for xdg-desktop-portal-hyprland that is drawn by the Quickshell widget (screens, windows, "remember this choice"). If the widget is not running, the stock dialog appears, so sharing never depends on obscura.

```sh
obscura picker-setup install     # writes custom_picker_binary into ~/.config/hypr/xdph.conf
systemctl --user restart xdg-desktop-portal-hyprland
obscura picker-setup uninstall   # back to the stock dialog
```

Note: xdph does not say who is asking, so every app's share request (browser, Discord) uses this picker.

## Roadmap

- [x] M0: authentication, start/stop/pause from the CLI
- [x] M1: `obscura watch` and the bar pill (live OBS test pending)
- [x] M2: panel (scene, audio sources, replay buffer, recording settings, widget look)
- [x] M3: screen-share picker
- [ ] M4: shortcut, hooks, level meters

## License

MIT
