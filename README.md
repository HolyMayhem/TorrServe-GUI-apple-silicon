# TorrServer for macOS

**English** | [Русский](README.ru.md)

A native macOS app for controlling TorrServer on Apple Silicon without Terminal.

Its main advantage is that you do not need to use the standard TorrServer Web UI.
You can manage everything directly in the app: add movies using magnet links or
`.torrent` files, organize your library, and start watching in your preferred player.

## Features

- Start, stop, update, and diagnose TorrServer.
- Add movies using magnet links or `.torrent` files directly in the app.
- Search for torrents through Jackett.
- Play content in IINA, VLC, Infuse, or the default media player.
- Use a compact menu bar icon to view server status, streaming speed, and active
  transfer statistics, or quickly start and stop TorrServer.
- Use the interface in English or Russian.

## Installation

Download the DMG from Releases, open it, and drag `TorrServer.app` into the
`Applications` folder.

The Apple Silicon `TorrServer-darwin-arm64` executable is bundled with the app.
Jackett is only required for built-in search.

## Requirements

- macOS 12 or later.
- A Mac with Apple Silicon.
