# Doom Arena (UZDoom mod)

A roguelite arena mod for the classic Doom engine, built on **UZDoom** (GZDoom fork) with **Freedoom** as the IWAD.

Planned gameplay: the player spawns in an open arena (pillars, lava/acid), monsters spawn in waves, kills give XP, each level-up gives +max HP and a choice of upgrades to existing Doom weapons (no new weapons planned for now). After clearing all monsters (and possibly a boss) the player moves on to the next arena.

Current state: a single octagonal arena `ARENA01` with 7 square pillars, colosseum-style spectator tiers along the walls and an acid pool in the center; the player starts in front of a wall switch. Each press (allowed only when no monsters are alive) starts the next level: shows "Level N", spawns that level's monsters, items and one new weapon, and heals players to 100%. Levels are configured in `mod/ARENALVL.txt`; after the last one it repeats with growing counts.

## Layout

| Path | What |
| --- | --- |
| `mod/` | The mod itself, loaded as a folder via `-file mod` |
| `mod/MAPINFO` | Replaces stock episodes; "New Game" goes straight to `ARENA01`; registers `ArenaHandler` |
| `mod/ARENALVL.txt` | Level config (monsters / items / weapon per level), syntax documented in the file |
| `mod/zscript/arena.zs` | `ArenaHandler`: switch logic, spawning, on-screen messages |
| `mod/zscript/levels.zs` | `ArenaLevelConfig`: parser for `ARENALVL` |
| `mod/maps/ARENA01.wad` | **Generated** by `tools/build_arena.py` — don't edit by hand |
| `tools/build_arena.py` | UDMF map generator (geometry, switch, spawn spots). Re-run after editing |
| `tools/devrun.sh` | Quiet dev launch: small window, `-nosound`, own config `config/dev.ini` |
| `tools/devshot/` | Dev-only mod for scripted screenshot scenes (loaded only by devrun) |
| `run.sh` / `run.cmd` | Player launch (macOS+Linux / Windows), windowed 1280x800, config `config/uzdoom.ini` |
| `setup.sh` / `setup.cmd`+`setup.ps1` | Download UZDoom + Freedoom into the project (pinned versions) |
| `engine/`, `iwad/`, `.cache/`, `config/` | Downloaded / local state, gitignored |

Nothing is installed globally; everything lives in the project folder.

License: the mod's own code and data are MIT (`LICENSE`). The engine (UZDoom, GPL) and Freedoom (BSD) are not part of the repo — they are downloaded by the setup scripts and keep their own licenses. Don't copy engine or Freedoom files into the repo.

## Commands

```bash
./setup.sh                          # download engine + freedoom2.wad (run.sh calls it if missing)
python3 tools/build_arena.py        # regenerate mod/maps/ARENA01.wad
./run.sh [uzdoom args]              # play (MAP=ARENA01 by default)
SHOTS=start  tools/devrun.sh        # dev: from the player start: switch, then the arena behind
SHOTS=look   tools/devrun.sh        # dev: 4 screenshots turning around in the center
SHOTS=button tools/devrun.sh        # dev: walk to switch, press it, look at spawned monsters
SHOTS=acid   tools/devrun.sh        # dev: stand in the acid pool, health should drop
SHOTS=levels tools/devrun.sh        # dev: level 1, refused press, kill all, level 2
```

Screenshots land in `config/screenshots/`. The game keeps running after a scene — the caller must terminate it (e.g. a Python wrapper that waits for N PNGs, then `terminate()`).

## Testing / verification rules

- For my own launches **always use `tools/devrun.sh`** (windowed, muted, separate config). Never launch `run.sh` for automated checks — it opens with sound and uses the player's config.
- Console `+wait`/`+exec` on the command line run before the map loads, so screenshots must be taken from ZScript (`level.MakeScreenShot()`, needs `enablescriptscreenshot 1`). Add new scenes to `tools/devshot/zscript.zs`.
- Check engine stdout for ZScript/MAPINFO errors. On a script error the engine prints `Execution could not continue` and hangs instead of exiting — the wrapper must watch for it and kill the process.
- Check engine stdout for `Arena:` config warnings, and look at the screenshots before reporting a visual change as done.

## Engine notes

- UZDoom 5.0.3; ZScript files declare `version "4.10"`. The engine's own ZScript sources (handy for API lookup): `unzip -p engine/macos/UZDoom.app/Contents/Resources/uzdoom.pk3 'zscript/*' 'zscript.txt'`.
- Maps are UDMF (`namespace = "zdoom"`); nodes are built by the engine, so the WAD only contains `ARENA01`, `TEXTMAP`, `ENDMAP`.
- Only use textures/flats that exist in `freedoom2.wad` (check the TEXTURE1 lump / F_START..F_END).
- Gameplay logic is planned in ZScript (`EventHandler`s, custom menus for the upgrade screen; play/ui scopes communicate via `SendNetworkEvent`).

## Git workflow

- After completing a change, **commit to `main` and push without asking the user**. Use clear commit messages describing the change.
- Never commit downloaded binaries or WADs (`engine/`, `iwad/`, `.cache/`) or local `config/`.
