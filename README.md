# absolute-server-template

The template every Absolute game server image starts from. Press **Use this
template**, fill in `manifest.env`, write the game's quirks, and you have a
server image that already meets the Absolute engineering standard.

It exists because the alternative is fifty diverging copies of the same update
logic — and the update logic is the part that most needs to be right.

## What you get

| | |
|---|---|
| [`manifest.env`](manifest.env) | Everything that differs between one game and another. Validated at start; a placeholder app id or a wrong stop signal stops the container rather than being guessed. |
| [`scripts/common`](scripts/common) | The shared library: logging, paths, process matching, the credential guard, pinned downloads, SteamCMD build ids. Game-agnostic by construction. |
| [`scripts/manifest`](scripts/manifest) | Loads and validates the manifest. Fails closed. |
| [`Dockerfile`](Dockerfile) | The image. A new game normally changes four things: the `GAME_ID` default, the packages its engine needs, `EXPOSE`, and the default port. |
| [`config/supervisord.conf`](config/supervisord.conf) | Supervises **the game process itself**, not a wrapper, and sends its output to the container's stdout. |
| [`tests/unit/`](tests/unit) | The fast tier. No Docker, no network, under a second, and it fails when any of the above stops being true. |
| [`tests/e2e/`](tests/e2e) | The merge tier, against the real image. Readiness is a bound port, not a log line. It runs in every repository cut from this one; here, with no game to run it against, the job skips itself, and the template merges on lint, build and conformance instead. |
| [`.github/dependabot.yml`](.github/dependabot.yml) | Weekly, grouped updates for the pinned action SHAs and the base image digest. A pin nothing moves is a pin that rots; `tests/unit/test_dependabot.sh` fails when a new kind of dependency appears without cover. |
| [`docs/INSTALL.md`](docs/INSTALL.md) | The install guide skeleton, written to the documentation standard. |
| [`.absolute/policy.yml`](.absolute/policy.yml) | This repository's answers to the standard, which your game repo inherits and edits. |

## Starting a new game

1. **Use this template** on GitHub, named `absolute-<game>-server`.
2. Fill in `manifest.env`. Every field is documented in place; the ones that
   bite are `STOP_SIGNAL` (the wrong one corrupts saves), `READY_LOG_PATTERN`
   (the difference between a health check that works and one that lies) and the
   public/private port split.
3. Run `bash tests/run_unit.sh`. It fails until the manifest is real.
4. Add the game's quirks in `scripts/quirks`, not in `scripts/common`. If you
   find yourself writing `if [[ "${GAME_ID}" == ... ]]` in the shared library,
   the value belongs in the manifest.
5. Work through [`CHECKLIST.md`](CHECKLIST.md). A game ships when every item is
   done, not when it boots once.

## What the manifest replaces

The three original images — Valheim, Rust, Palworld — were the same program with
the constants swapped: the app id, the binary name, the process name, the stop
signal, the ready line, the ports, the save paths. Those are now data:

```sh
GAME_ID=satisfactory            STEAM_APP_ID=1690800
STEAM_PLATFORM=linux            STEAM_BRANCH=public
SERVER_PROCESS=FactoryServer    READY_LOG_PATTERN='Server startup complete'
PUBLIC_PORTS=7777/udp           STOP_SIGNAL=INT
SAVE_PATHS=saved                SNAPSHOT_PATHS=/opt/satisfactory/server
```

## What this template refuses to repeat

Three defects from the earlier hand-written images are designed out here, and
each one cost real time to find:

- **The game is the supervised process.** `scripts/server` execs the binary
  instead of backgrounding it and looping, so supervisor's `startsecs`,
  `startretries`, `autorestart` and `stopsignal` govern the game. A wrapper
  that outlives its child makes all of them decoration, and a server that can
  never start crash-loops forever while the container reports healthy.
- **The server's output reaches `docker logs`.** A log an operator cannot see
  during an incident may as well not exist — and in CI it meant assertions
  counting matches in a stream that could not contain the answer.
- **Readiness is a capability, not a string.** The e2e waits for a bound port.
  Guessing which startup line a build prints cost a day across two
  repositories, in four separate ways.

## Status

The container layer landed with the first game
([absolute-satisfactory-server](https://github.com/abspwgm/absolute-satisfactory-server)),
which is what the standard requires: a thing is not proven until a suite has
passed on it.

Two things are still missing and are recorded as dated exceptions in
[`.absolute/policy.yml`](.absolute/policy.yml): the generic snapshot/hold/restore
CLI, and the scheduled build watch. Both belong here rather than in each game.

## Licence

Apache-2.0. See [`LICENSE`](LICENSE).
