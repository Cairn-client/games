# Cairn games catalog

The data the Cairn launcher (<https://github.com/Cairn-client/Launcher>) reads: the list of games, what it shows and does for each, shared requirements, blocked mod versions and notices.
Everything here is data; nothing in it is run. Same repository conventions (README, `AUTHORS.md`, license) as Unplug (`~/Unplug`, <https://github.com/cmpnn-romain/Unplug>), without versions or releases (see below).

## Layout

| Path | What it is |
| --- | --- |
| `games.json` | the list of games (and, for each game with a mod, the repository that publishes it), shared requirement definitions, packs, blocked mod versions, notices |
| `games/<id>/game.json` | one game: name, developer, Steam ids, description, accent colour, requirements, setup steps, what its mod does |
| `games/<id>/*.jpg, *.png` | its pictures, named in `game.json` (a file name looked up beside the file that names it, never a URL) |
| `tools/Validate-Catalog.ps1` | the checks the launcher applies when it reads the catalog; CI runs it on every push |
| `.github/workflows/validate.yml` | CI: runs the checks above on push to `main` and on pull requests |

## Build and test

```bash
pwsh tools/Validate-Catalog.ps1
```

Run it before every push. There is nothing to build.

## Releases and versions

There are none: the launcher reads `main` directly, at start-up and when it checks for updates, so a commit here reaches players the next time they start. Each file carries its own `schema` number
(`1`); the launcher ignores a file it does not understand and keeps the last good copy, so a mistake never breaks a launcher but the change does not arrive either. Commits follow Conventional Commits.

## Pitfalls

- The checks mirror the launcher's own (`Cairn.Setup/Catalog.cs` in the Launcher repository): ids, paths and limits (`$MaxFile` 256 KB per file, `$MaxPicture` 3 MB per picture). If they change there, change `tools/Validate-Catalog.ps1` too.
- Ids, names and paths must be plain (`^[A-Za-z0-9_-]{1,40}$` for ids); texts are short; a `repo` is `owner/name`.
- A game that has a mod publishes its own `game.json` and pictures as assets of its latest release; the file in `games/<id>/` is used until it does, and for games that have no mod yet.
- A `blocked` entry pulls a mod version (`version`, or every one up to `max`) from what the launcher offers and warns players who have it: be sure before adding one.
- The artwork belongs to the studios and publishers of the games and is here only to identify them; add only what a page needs. Logos are transparent PNGs, backgrounds and heroes JPEG, each under 3 MB.
- Adding a game: `games/<id>/` with `game.json` and its pictures, an entry in `games.json` (with a `repo` once its mod has releases), then the checks.
