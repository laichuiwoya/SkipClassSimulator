# 逃课模拟器

Godot 4.6 classroom stealth prototype. The player observes the teacher, uses desks as cover, and moves toward the dorm exit door.

## Run

Open this folder in Godot and run the main scene:

- Project file: `project.godot`
- Main scene: `welcome.tscn`
- Viewport: `1050x620`

## Gameplay Rules

- The teacher patrols horizontally in front of the blackboard.
- When the teacher faces the classroom, a cone-shaped vision area is shown.
- The player is caught when either rule is true:
  - The player is above the first desk row.
  - The player is inside the teacher vision cone and no desk blocks the player's vertical cover line.
- On the first caught frame, the teacher shows an angry speech bubble. Both teacher and player pause long enough to read the bubble; then the player is forced back to the spawn position with input disabled.
- After 3 caught events, the game ends and shows `你已成为老师关注对象`.
- The game over popup is drawn above the scene and includes a `重新开始` button that reloads the current scene.
- Desks are natural cover. The cover check casts upward from the player toward the teacher's y-position and treats `Desks/Desk*` bodies as blockers.
- The dorm exit is the brown door at the bottom-right edge of the room.
- Reaching the door switches to `building_downstairs.tscn` instead of showing a victory message.

## Project Structure

- `welcome.tscn` - startup welcome screen for `逃课模拟器`, with generated pixel-art cover art plus `开始游戏` and `退出游戏` buttons.
- `welcome.gd` - welcome screen button logic; start enters `main.tscn`, quit exits the game.
- `dorm_building.tscn` - dorm-downstairs scene; it uses a white marble floor and a player that reuses the classroom movement/animation setup. The second and fourth floor-grid rows are independent cell obstacles decorated as pixel dorm rooms, with the second-row fifth cell open.
- `dorm_building.gd` - decorates dorm-downstairs cell obstacles as pixel dorm rooms with 3D room faces; second-row rooms show lower front doors, fourth-row rooms show translucent upper front doors, and the top of the scene gets wooden door headers. When the player stands near any dorm door/header, a bubble prompts `按F进入宿舍`; pressing F hides the player inside that dorm, and pressing F again exits from the same door.
- In `dorm_building.tscn`, being seen by a dorm supervisor shows that supervisor's `想溜走？快回教室！` bubble, then reloads the current dorm-building level so the player and supervisors restart from their spawn state. The found count survives those reloads; after 3 finds, the popup says `你被宿管记住了` and offers `重新开始` plus `从此关重新开始`.
- The bottom-left dorm room `Row4Col1` is the win dorm. Pressing F to enter it prints `成功回到宿舍，游戏胜利`.
- `Row4Col1` is visually marked with a gold highlight and `我的宿舍` sign so players can identify it quickly.
- `dorm_supervisor.gd` - non-blocking dorm supervisor patrol logic used by the three visual supervisors in `dorm_building.tscn`.
- `building_downstairs.tscn` - teaching-building downstairs scene; it can transition to `dorm_building.tscn`.
- `main.tscn` - classroom scene, nodes, collision shapes, visual dressing, and exported node paths.
- `building_downstairs.gd` - downstairs scene logic.
- `main.gd` - root scene helpers, including the restart button callback.
- `teacher.gd` - teacher patrol, turn timing, cone vision, angry bubble, walking animation, writing animation.
- `player.gd` - player movement, minimum y boundary, facing direction, walking animation. Left/right walking rotates the sprite toward the movement direction.
- `player.gd` also stores the spawn position and handles forced return after being caught.
- `desks.gd` - applies `assets/desk.png` to every desk under `Desks`.
- `dorm.gd` - door transition logic.
- `assets/` - generated pixel-art PNG sprites and Godot import metadata.

## Pixel Assets

Current generated assets:

- `assets/teacher.png`
- `assets/teacher_write.png`
- `assets/player.png`
- `assets/desk.png`
- `assets/door.png`
- `assets/blackboard.png`
- `assets/welcome_cover.png`

Keep sprites on `Sprite2D` with nearest filtering (`texture_filter = 1`) to preserve pixel art.

## Tuning Points

Teacher exports in `teacher.gd`:

- `patrol_left_x`, `patrol_right_x` - patrol range along the blackboard.
- `vision_range`, `vision_half_angle_degrees`, `vision_segments` - vision cone behavior and display.
- `first_desk_row_y` - y threshold for automatic caught state above the first row.
- `min_move_time`, `max_move_time`, `min_blackboard_time`, `max_blackboard_time` - teacher state timing.
- `max_caught_count` - number of caught events before game over.

Player exports in `player.gd`:

- `speed` - movement speed.
- `min_y` - prevents the player from walking too far above the classroom play area.
- `forced_return_speed` - speed used when the teacher sends the player back to spawn.
- `forced_return_delay` - pause before forced return begins; teacher sets it from `anger_bubble_time`.

In `building_downstairs.tscn`, the local `Player` uses `min_y = 0.0` so the classroom upper-bound rule does not restrict the downstairs scene.

Dorm-downstairs supervisor patrols in `dorm_building.tscn`:

- `SupervisorRow1` randomly patrols horizontally inside the first floor-grid row, pausing before each turn.
- `SupervisorCol5` randomly patrols vertically inside the fifth floor-grid column, pausing before each turn.
- `SupervisorRow3` randomly patrols horizontally inside the third floor-grid row, pausing before each turn.
- After every pause, supervisors choose a random target in the opposite direction. `SupervisorRow1` starts at the left side and moves right first; the other two supervisors randomize their spawn point and initial direction.
- Supervisors watch a straight line across the full width of their current row or column in their current facing direction. Detection includes the player's collision size, so hugging room blocks or screen edges still counts if the player is in sight.
- Dorm supervisors are `Node2D` visual patrols without physics collision, so overlapping the player, rooms, or each other will not block movement.

## Development Notes

- Do not remove desk `StaticBody2D` nodes or collision shapes when changing desk visuals; detection and cover rely on them.
- If adding more desks, place them under `Desks` and name them with the `Desk` prefix so cover detection and `desks.gd` keep working.
- Keep `Teacher/AngerBubble` wired to the teacher through `anger_bubble`.
- Keep `GameOverPopup` wired to the teacher through `game_over_popup`.
- Keep `Player/Sprite2D` and `Teacher/Sprite2D` paths stable unless updating exported paths in the scripts.
