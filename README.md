# HCTrader

A trade monitoring addon for [Turtle WoW](https://turtle-wow.org/) (1.12 client). Captures item links posted in the `[Hardcore]` chat channel and displays them in a searchable, scrollable log window.

## Features

- **Real-time item logging** — automatically captures item links from Hardcore chat
- **Search** — filter by item name or seller name
- **Level filter** — show only sellers within your tradeable level range (Turtle WoW enforces a +-5 level restriction on trading). Configurable range, toggle on/off
- **Auto /who lookup** — automatically queries seller levels in the background, respecting the 30-second server cooldown. Includes a cooldown bar with timer and queue display
- **Persistent data** — items, seller info (level, race, guild, zone), and settings are saved across reloads and relogs
- **Seller interaction** — click a seller name to whisper, shift-click to /who
- **Faction icons** — displays Alliance/Horde icon next to each seller
- **Item tooltips** — hover over an item to see its tooltip, shift-click to link in chat

## Installation

1. Download or clone this repository
2. Copy the `HCTrader` folder into your `WoW/Interface/AddOns/` directory
3. Restart your WoW client (a `/reload` is not sufficient for first install)

## Usage

| Command | Description |
|---------|-------------|
| `/tl` | Toggle the HCTrader window |
| `/tl clear` | Clear all logged items and player data |
| `/tl level` | Toggle the level filter on/off |
| `/tl range <n>` | Set level filter range (default: +-5) |

## Screenshots

The main window shows a table with columns for time (minutes ago), item link, seller name, faction icon, and level. A search box and level filter button are at the top, along with a /who cooldown bar and auto-fetch toggle.

## License

MIT
