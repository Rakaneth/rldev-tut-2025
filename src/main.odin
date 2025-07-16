package main

import "core:c"
import "core:fmt"
import rl "vendor:raylib"

SCR_W :: 1024
SCR_H :: 768
TITLE :: "RoguelikeDev RL Tutorial 2025"
WORLD_PIX_W :: 320
WORLD_PIX_H :: 240
TILE_SIZE :: 8
WORLD_TILE_W :: WORLD_PIX_W / TILE_SIZE
WORLD_TILE_H :: WORLD_PIX_H / TILE_SIZE
FPS :: 60
LERP_MOVE_FACTOR :: 0.5
LERP_SNAP_THRESHOLD :: 0.01

Point :: [2]int

Direction :: enum {
	None,
	Up,
	Right,
	Down,
	Left,
}

@(rodata)
Direction_Offsets := [Direction]Point {
	.None  = {0, 0},
	.Up    = {0, -1},
	.Right = {1, 0},
	.Down  = {0, 1},
	.Left  = {-1, 0},
}

Tiles :: enum {
	Hero,
}

GameState :: enum {
	Input,
	Move,
}

@(rodata)
TextureAtlas := [Tiles]rl.Rectangle {
	.Hero = {32, 0, TILE_SIZE, TILE_SIZE},
}

_cam := rl.Camera2D {
	zoom = f32(SCR_W) / f32(WORLD_PIX_W),
}
_atlas_texture: rl.Texture2D
_hero_loc: Point
_hero_screen_pos: [2]f32
_hero_screen_to: [2]f32
_state: GameState

init :: proc() {
	rl.InitWindow(SCR_W, SCR_H, TITLE)
	rl.SetTargetFPS(FPS)
	atlas_data := #load("../assets/gfx/monochrome_tilemap_packed.png")
	atlas_img := rl.LoadImageFromMemory(".png", raw_data(atlas_data[:]), c.int(len(atlas_data)))
	_atlas_texture = rl.LoadTextureFromImage(atlas_img)
	rl.UnloadImage(atlas_img)
}

draw_tile :: proc(tile: Tiles, x: f32, y: f32, tint: rl.Color) {
	src_rect := TextureAtlas[tile]
	dest_rect := rl.Rectangle{x, y, TILE_SIZE, TILE_SIZE}
	rl.DrawTexturePro(_atlas_texture, src_rect, dest_rect, {0, 0}, 0, tint)
}

loc_to_screen :: proc(p: Point) -> [2]f32 {
	return {f32(p.x), f32(p.y)} * 8
}

move_by :: proc(p: Point, dir: Direction) {
	new_pos := p + Direction_Offsets[dir]
	if new_pos.x >= 0 && new_pos.y >= 0 && new_pos.x < WORLD_PIX_W && new_pos.y < WORLD_PIX_H {
		_hero_screen_to = loc_to_screen(new_pos)
		_hero_loc = new_pos
		_state = .Move
	}
}

//Should return false to stop the game
update :: proc() -> bool {
	dt := rl.GetFrameTime()
	switch _state {
	case .Input:
		switch {
		case rl.WindowShouldClose():
			return false
		case rl.IsKeyPressed(.W):
			move_by(_hero_loc, .Up)
		case rl.IsKeyPressed(.A):
			move_by(_hero_loc, .Left)
		case rl.IsKeyPressed(.S):
			move_by(_hero_loc, .Down)
		case rl.IsKeyPressed(.D):
			move_by(_hero_loc, .Right)
		}
	case .Move:
		_hero_screen_pos.x = rl.Lerp(_hero_screen_pos.x, _hero_screen_to.x, LERP_MOVE_FACTOR)
		_hero_screen_pos.y = rl.Lerp(_hero_screen_pos.y, _hero_screen_to.y, LERP_MOVE_FACTOR)
		if rl.Vector2Distance(_hero_screen_pos, _hero_screen_to) < LERP_SNAP_THRESHOLD {
			_hero_screen_pos = _hero_screen_to
		}
		if _hero_screen_pos == _hero_screen_to {
			_state = .Input
		}
	}

	return true
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.BeginMode2D(_cam)
	draw_tile(.Hero, _hero_screen_pos.x, _hero_screen_pos.y, rl.BEIGE)
	rl.EndMode2D()
	rl.DrawFPS(0, SCR_H - 24)
	rl.EndDrawing()
}

shutdown :: proc() {
	rl.UnloadTexture(_atlas_texture)
	rl.CloseWindow()
}

main :: proc() {
	init()
	defer shutdown()

	running := true

	for running {
		running = update()
		draw()
	}
}
