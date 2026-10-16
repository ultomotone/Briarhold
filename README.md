# Briarhold

A thumb-high gnome. A kingdom gone to briar. Sprigs at your heel.

An original creature-commander built for one player. Godot 4.8 (beta), GDScript, a pure deterministic
simulation under a view, every number in JSON, one increment per scheduled build.

## Play

The project runs on Godot 4.8 beta 1. It is not on winget yet: download
`Godot_v4.8-beta1_win64.exe.zip` from https://github.com/godotengine/godot-builds/releases/tag/4.8-beta1
and unzip it to `%USERPROFILE%\Tools\Godot-4.8-beta1`. The launchers and the gate find it there and
fall back to a winget 4.7.2 (`winget install GodotEngine.GodotEngine`), which still passes the gate.

Double-click `Play Briarhold.cmd` to play from source, or `Edit in Godot.cmd` to open the editor.
No export needed; a green tree is playable.

## Develop

    pwsh tools\gate.ps1            # import → typecheck → tests → screenshots
    pwsh tools\gate.ps1 -NoShot    # without the windowed capture
    pwsh tools\gate.ps1 -Export    # also build\Briarhold.exe (needs export templates)

Read `CLAUDE.md`, then `RUN.md`. The doctrine files `00_…13_` are the contract; `docs/ROADMAP.md`
is the work order; `docs/design/CODEX.md` is the design intent.

## Layout

    sim/        the game: pure GDScript, no Node, no Input, no clock, no engine randomness
    game/       view and shell: main driver, terrain, sky, squad, world, HUD, title, pause
    content/    every number and every row (palette, world, sprigs, objects, enemies, hazards)
    tests/      GUT tests mirroring sim/, golden save fixtures
    tools/      gate.ps1, check.gd (typecheck), shot.gd (screenshots)
    docs/       roadmap, design codex, research
