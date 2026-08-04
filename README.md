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
- Automatically enrich movies and series with posters, descriptions, genres,
  release information, runtime, and ratings from TMDB or OMDb.
- Translate English OMDb descriptions into Russian with Apple Translation.
- Play content in IINA, VLC, Infuse, or the default media player.
- Use a compact menu bar icon to view server status, streaming speed, and active
  transfer statistics, or quickly start and stop TorrServer.
- Use the interface in English or Russian.

## Installation

Download the DMG from Releases, open it, and drag `TorrServer.app` into the
`Applications` folder.

The Apple Silicon `TorrServer-darwin-arm64` executable is bundled with the app.
Jackett is only required for built-in search.
Metadata is optional. Choose TMDB or OMDb and add the corresponding API key in
the app's settings.

## Requirements

- macOS 15 or later.
- A Mac with Apple Silicon.
