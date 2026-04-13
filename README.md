# HCTrader

A trade monitoring addon for [Turtle WoW](https://turtle-wow.org/) (1.12 client). Captures item links posted in the `[Hardcore]` chat channel and displays them in a searchable, scrollable log window.

## Features

- **Real-time item logging** — automatically captures item links from Hardcore chat
- **Buy / Sell / Other tabs** — WTS messages go to the Buy tab, WTB messages go to the Sell tab. An optional Other tab shows untagged messages (enable in Settings)
- **Level parsing** — extracts player level from messages (e.g. "22+", "9+-") to show levels instantly without a /who query. Falls back to auto /who when no level pattern is found
- **Free item highlighting** — listings containing "free" are highlighted with a golden background
- **Item interactions** — hover an item to see its tooltip; click to view the original message; ctrl-click to preview in the dressing room; shift-click to link in chat
- **Seller interactions** — click a seller name to whisper; shift-click to /who. Guildmates are highlighted in green
- **Search** — filter by item name or seller name
- **Level filter** — toggle +-5 from your level or set a custom range (e.g. 12-41) in Settings. Turtle WoW enforces a +-5 level restriction on trading
- **Auto /who lookup** — automatically queries seller levels in the background when level can't be parsed from the message, respecting the 30-second server cooldown. Includes a cooldown bar with timer and queue display
- **Item watchlist** — add items to a watchlist and get notified when they appear in chat. Search pfQuest's item database (17,700 items) or shift-click/type item names. Configurable notifications: chat message, raid warning text, center screen text, screen flash, and selectable alert sounds. Open via the Watchlist button or `/hct watch`
- **Settings panel** — configure level range, max items, expiry hours, window scale, highlight toggles, and more. Open via the gear button (*) or `/hct settings`
- **Persistent data** — items, seller info (level, race, guild, zone), watchlist, and settings are saved across reloads and relogs

## Installation

1. Download or clone this repository
2. Copy the `HCTrader` folder into your `WoW/Interface/AddOns/` directory
3. Restart your WoW client (a `/reload` is not sufficient for first install)

## Usage

| Command | Description |
|---------|-------------|
| `/hct` | Toggle the HCTrader window |
| `/hct clear` | Clear all logged items and player data |
| `/hct level` | Toggle the level filter on/off |
| `/hct range <n>` | Set level filter +-range (e.g. `/hct range 5`) |
| `/hct range <min>-<max>` | Set custom level range (e.g. `/hct range 3-22`) |
| `/hct settings` | Open the settings panel |
| `/hct watch` | Open the watchlist panel |

## Screenshots

The main window shows a table with columns for time (minutes ago), item link, seller name, faction icon, and level. A search box and level filter button are at the top, along with a /who cooldown bar and auto-fetch toggle.

## License

MIT
