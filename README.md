# Cairn games catalog

The list of games the [Cairn launcher](https://github.com/Cairn-client/launcher) knows about, and what the launcher shows and does for each.
The launcher reads these files at start-up (and keeps the last good copy, so it works offline). **Adding a game, changing a description,
a requirement or a picture, announcing a known issue, or pulling a bad mod version is a commit here, not a new launcher.**

Everything here is data. Nothing in it is run, and the launcher checks every file before using it: ids, names and paths must be plain,
texts are short, and a picture is a file name looked up beside the file that names it, never a URL of its own. A file the launcher
does not understand is ignored and the previous copy stays in use.

## Layout

| Path | What it is |
| --- | --- |
| `games.json` | the list of games (and, for each game with a mod, the repository that publishes it), shared requirement definitions, blocked mod versions, notices |
| `games/<id>/game.json` | one game: name, studio, Steam ids, description, accent colour, requirements, what its mod does |
| `games/<id>/*.jpg, *.png` | its pictures, named in `game.json` |
| `tools/Validate-Catalog.ps1` | the checks (CI runs it on every push; run it before you push) |

A game that has a mod publishes its own `game.json` and pictures as assets of its latest release (see `docs/CATALOG.md` in the launcher
repository); the file in `games/<id>/` is what is used until it does, and for games that have no mod yet.

## `games.json`

```json
{
  "schema": 1,
  "games":  [ { "id": "kcd2", "repo": "Cairn-client/mod-kcd2" }, { "id": "cp77" } ],
  "packs":  [ { "id": "core", "repo": "Cairn-client/core" } ],
  "components": { "kcd2-game": { "kind": "steam-app", "name": "Kingdom Come: Deliverance II", "appId": 1771300 } },
  "blocked": [ { "pack": "kcd2", "version": "0.1.0", "reason": "Saves can be lost." } ],
  "notices": [ { "id": "sleep-2026-10", "title": "Sleep", "text": "Both players must agree to sleep.", "kind": "known-issue", "games": ["kcd2"] } ]
}
```

* **games** -- `id` is the game's short name; `repo` (optional) is the GitHub repository whose releases carry the game's mod pack and its `game.json`.
* **packs** -- repositories of packs that are not a game's mod (content, shared parts). A pack that another one `dependsOn` is looked up here.
* **components** -- something a game needs, defined once and named by the games that need it (`"requires": ["kcd2-game"]`).
  `steam-app` is checked and linked by the launcher; other kinds are shown by name.
* **blocked** -- a mod version (`version`) or every version up to one (`max`) that must not be offered; the launcher warns a player who has it.
* **notices** -- a known issue or news for the players, shown on Home and under Help. Optional `games` (only for players who have one of them),
  `fromLauncher` / `untilLauncher` (launcher versions) and `until` (a date, UTC) say when it applies.

## `games/<id>/game.json`

```json
{
  "schema": 1, "id": "cp77", "name": "Cyberpunk 2077", "developer": "CD Projekt Red", "franchise": "Cyberpunk",
  "supported": false, "steamAppId": 1091500, "exe": "Cyberpunk2077.exe",
  "description": "Take on Night City with a friend.", "accent": "#F3E02A",
  "images": { "background": "background.jpg", "logo": "logo.png", "hero": "hero.jpg", "poster": "poster.jpg", "screenshots": ["shot-1.jpg", "shot-2.jpg"] },
  "requires": [ "kcd2-game" ],
  "features": [ { "title": "Sessions", "items": [ { "name": "Host and join", "detail": "...", "status": "ready" } ] } ],
  "content": [ "kcd2-start-saves" ]
}
```

`supported: false` lists a game that has no multiplayer yet (its page shows, Host and Join stay off). `status` is `ready` (default), `inTest` or `planned`.
`content` names content packs (listed under `packs`) the game's page offers.

## Adding a game

1. Make `games/<id>/` with `game.json` and the pictures it names (a logo as a transparent PNG; backgrounds and heroes as JPEG, each under 3 MB).
2. Add `{ "id": "<id>" }` to `games.json` (give it a `repo` once its mod has releases).
3. `pwsh tools/Validate-Catalog.ps1`, then push to `main`. Launchers pick it up the next time they start or check for updates.

The artwork belongs to the studios and publishers of the games; it is here only to identify them. Cairn is unofficial and not affiliated with them.
