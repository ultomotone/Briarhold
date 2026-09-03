# CREDITS

Every asset that enters this repo gets a line: name, author, source URL, licence. No exceptions.

## Code and libraries

- Godot Engine 4.7.2 — Juan Linietsky, Ariel Manzur, and contributors — https://godotengine.org — MIT
- GUT 9.7.1 (Godot Unit Test) — Butch Wesley — https://github.com/bitwes/Gut — MIT (`addons/gut`)

## Art

- All meshes are generated in code from primitives (`game/view/*.gd`). No external art yet.

## Design references (structure studied, content never copied)

- Pikipedia — https://www.pikminwiki.com — mechanics reference for the genre.
- Pikifen — Espyo — https://github.com/Espyo/Pikifen — MIT. Studied in source for the squad
  formation formula, carry speed curve and spot claiming, the two-gate shake, hazard status
  fields, the seed-spiral idea, and the mission model. Re-derived at our scale in GDScript;
  no code copied. Notes: `docs/research/pikifen-notes.md`.
