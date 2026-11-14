# Recent Changes

## Gameplay

- Added a reusable jump orb with Small, Medium, and Large strengths, matching colors, and jump-on-button-press behavior. See [jump_orb_area.gd](Scripts/jump_orb_area.gd) and [player.gd](Scripts/player.gd).
- Added a death screen with main menu, level select, restart, and quit options. Player health is clamped to 0-100.
- Added reusable Coins and Helium collectibles. Coins increase the player's total; Helium temporarily reduces gravity. The HUD shows coins, and the death screen shows collectible totals. Removed the redundant standalone coin scene and script.
- Added crouch and jump input buffers for floor and wall contact. Each press is consumed once, so holding jump does not cause repeated jumps. Crouch buffers activate on contact while crouch remains held.
- Added stronger crouch wall jumps that push the player away from the wall, and automatic uncrouching when leaving a surface.
- Reduced movement speed by 30% while crouching on a floor, including while sprinting. Wall crouching does not apply the slowdown.
- Added crouch/jump buffer states and buffer-used states to the player debug readout.

## Menus and audio

- Added a Credits screen for GuayabR (programming and scene design), Mitchell (menu and music design), and Mihir (art design).
- Added master and music volume controls, saved in `user://settings.json`. Settings errors are shown in the settings screen.

## Updates since the first changelog

- Replaced the jump orb's polygon visuals with tintable `Sprite2D`s using `Resources/misc/cover_mask.png`, scaled to preserve their original sizes.
- Updated health deterioration rates while moving: 0.5 in a wall-jump area, 0 in the air or while idle on a regular surface, 1 on a regular surface, 1.5 while sprinting, 1.4 while sprinting and crouching, and 0.9 while crouching. Wall-jump-area deterioration remains active while idle, including when standing on a floor beside a wall.
- Buffered jump and crouch inputs now cancel if their keys are released before contact.
