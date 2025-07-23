package main

import "core:c"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

SCR_W :: 1200
SCR_H :: 900
TITLE :: "RoguelikeDev RL Tutorial 2025"
WORLD_PIX_W :: 320
WORLD_PIX_H :: 240
TILE_SIZE :: 8
WORLD_TILE_W :: WORLD_PIX_W / TILE_SIZE
WORLD_TILE_H :: WORLD_PIX_H / TILE_SIZE
FPS :: 60
LERP_MOVE_FACTOR :: 0.5
LERP_SNAP_THRESHOLD :: 0.01

GameState :: enum {
	Input,
	Move,
}

_cam := rl.Camera2D {
	zoom = f32(SCR_W) / f32(WORLD_PIX_W),
}
_atlas_texture: rl.Texture2D
_hero_loc: Point
_hero_screen_pos: [2]f32
_hero_screen_to: [2]f32
_state: GameState
_cur_map: TerrainData

init :: proc() {
	rl.InitWindow(SCR_W, SCR_H, TITLE)
	rl.SetTargetFPS(FPS)
	atlas_data := #load("../assets/gfx/monochrome_tilemap_packed.png")
	atlas_img := rl.LoadImageFromMemory(".png", raw_data(atlas_data[:]), c.int(len(atlas_data)))
	_atlas_texture = rl.LoadTextureFromImage(atlas_img)
	rl.UnloadImage(atlas_img)
	_cur_map = arena(11, 13)
	_hero_loc = {1, 1}
	_hero_screen_pos = loc_to_screen(_hero_loc)
}

move_by :: proc(p: Point, dir: Direction) {
	new_pos := p + Direction_Offsets[dir]
	if new_pos.x >= 0 &&
	   new_pos.y >= 0 &&
	   new_pos.x < WORLD_TILE_W &&
	   new_pos.y < WORLD_TILE_H &&
	   !map_is_wall(_cur_map, new_pos) {
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
	draw_map(_cur_map)
	draw_tile(.Hero, _hero_screen_pos.x, _hero_screen_pos.y, rl.BEIGE)
	rl.EndMode2D()
	rl.DrawFPS(0, SCR_H - 24)
	rl.EndDrawing()
}

shutdown :: proc() {
	grid_destroy(&_cur_map)
	rl.UnloadTexture(_atlas_texture)
	rl.CloseWindow()
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
		defer {
			if len(track.allocation_map) > 0 {
				for _, entry in track.allocation_map {
					fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	init()
	defer shutdown()

	running := true

	for running {
		running = update()
		draw()
	}
}
