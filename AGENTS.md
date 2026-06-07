# Agent Notes

This is a Godot 4.6 project for a classroom stealth prototype named "逃课模拟器".

## Rules For Code Changes

- The user asked not to run tests or launch Godot automatically. Make code/resource edits only unless they explicitly ask to verify.
- Preserve user-made scene edits. The project may not be a git repository.
- Prefer editing `main.tscn`, `teacher.gd`, `player.gd`, `desks.gd`, and assets in place; avoid broad scene rewrites.
- Use `apply_patch` for manual edits.

## Scene Contracts

- Current startup scene: `dorm_building.tscn` for standalone dorm-downstairs testing.
- Classroom scene: `main.tscn`.
- Teaching-building downstairs scene: `building_downstairs.tscn`.
- Root script: `main.gd`.
- Teacher node: `Teacher` with `teacher.gd`.
- Player node: `Player` with `player.gd`.
- Desks live under `Desks` as `StaticBody2D` nodes named `Desk*`.
- Dorm exit node: `Dorm`.
- Door transition target: `building_downstairs.tscn`.
- `building_downstairs.tscn` uses the same `player.gd` and `assets/player.png`; its player starts at `Vector2(42, 42)` near the left edge and sets `min_y = 0.0`.
- `dorm_building.tscn` uses a white marble floor and the same `player.gd` and `assets/player.png`; its player starts at `Vector2(42, 80)` and sets `min_y = 0.0`. Its second and fourth floor-grid rows use independent `StaticBody2D` cell obstacles under `CellObstacles`, with `Row2Col5` intentionally open. `dorm_building.gd` decorates each obstacle as a pixel dorm room at runtime; `Row2*` rooms draw lower front doors, `Row4*` rooms draw translucent upper front doors, and `TopDormDoors` is generated as non-collision wooden door headers. Door spots are tracked in script; nearby players see `按F进入宿舍`, F hides the player inside, and pressing F again exits from the same door.
- `DormSupervisors` in `dorm_building.tscn` contains three non-collision `Node2D` visual patrols using `dorm_supervisor.gd`: `SupervisorRow1` patrols first-row x `78..978` at y `88`, `SupervisorCol5` patrols fifth-column y `82..430` at x `945`, and `SupervisorRow3` patrols third-row x `78..978` at y `388`.
- Caught feedback uses `Teacher/AngerBubble`; final failure uses `GameOverPopup`.

## Gameplay Logic

- Teacher alternates between moving/facing classroom and facing blackboard.
- Facing classroom shows `Teacher/VisualRoot/SightVisual` and checks caught state.
- Player is caught if above `first_desk_row_y`, regardless of teacher vision.
- Otherwise player is caught only when inside the teacher vision cone and no desk blocks the upward cover ray from player to teacher y-position.
- On the caught transition, teacher shows `Teacher/AngerBubble`, pauses teacher state updates during `anger_bubble_time`, sets `Player.forced_return_delay` from that same value, then calls `Player.force_return_to_spawn()`. Player input stays disabled during the read delay and until forced return finishes.
- Teacher increments `_caught_count` on each caught transition. At `max_caught_count`, it shows `GameOverPopup`, hides vision/caught UI, and calls `Player.lock_control()`.
- `GameOverPopup/RestartButton` is connected to `Main._on_restart_button_pressed()`, which reloads the current scene.
- `Dorm` uses `dorm.gd` and calls `change_scene_to_file(next_scene_path)` when `Player` enters. Default target is `res://building_downstairs.tscn`.
- Desk cover detection depends on desk node names starting with `Desk` or parent being `Desks`.
- Dorm supervisors only move visually and have no physics collision, which prevents blocking or jitter when they overlap the player, rooms, or each other.

## Visual/Asset Rules

- Pixel sprites are stored in `assets/`.
- Important sprites:
  - `assets/teacher.png`
  - `assets/teacher_write.png`
  - `assets/player.png`
  - `assets/desk.png`
  - `assets/door.png`
  - `assets/blackboard.png`
- Keep `Sprite2D.texture_filter = 1` for nearest-neighbor pixel art.
- `desks.gd` automatically hides old desk `ColorRect` visuals and adds `assets/desk.png` to each desk at runtime.
- Teacher walking and writing animations are procedural sprite motion plus texture swapping, not sprite-sheet animations.
- Player facing uses sprite rotation: down is default/front, up is 180 degrees, left/right are -90/90 degrees.
- Player spawn is captured in `player.gd` during `_ready()`. Change the `Player` node position in `main.tscn` to change the return point.

## Encoding Note

Use UTF-8 explicitly when reading or writing files that contain Chinese text. In PowerShell, prefer `Get-Content -Encoding UTF8`, `Set-Content -Encoding UTF8`, and `Select-String -Encoding UTF8`. If mojibake appears, replace the whole affected field with clean UTF-8 text instead of matching the corrupted text.
