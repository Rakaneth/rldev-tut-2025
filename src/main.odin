package main

import "core:c"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

/* Game Constants */
SCR_W :: 1200
SCR_H :: 900
TITLE :: "RoguelikeDev RL Tutorial 2025"
WORLD_PIX_W :: 640
WORLD_PIX_H :: 480
TILE_SIZE :: 16
WORLD_TILE_W :: WORLD_PIX_W / TILE_SIZE
WORLD_TILE_H :: WORLD_PIX_H / TILE_SIZE
FPS :: 60
LERP_MOVE_FACTOR :: 0.5
LERP_SNAP_THRESHOLD :: 0.01

GameState :: enum {
	Input,
	Move,
}

/* Game Globals */

_cam := rl.Camera2D {
	zoom = f32(SCR_W) / f32(WORLD_PIX_W),
}
_atlas_texture: rl.Texture2D
_hero_loc: Point
// _hero_screen_pos: [2]f32
// _hero_screen_to: [2]f32
_state: GameState
_cur_map: GameMap

/* Game Lifecycle */

init :: proc() {
	rl.InitWindow(SCR_W, SCR_H, TITLE)
	rl.SetTargetFPS(FPS)
	atlas_data := #load("../assets/gfx/lovable-rogue-cut.png")
	atlas_img := rl.LoadImageFromMemory(".png", raw_data(atlas_data[:]), c.int(len(atlas_data)))
	_atlas_texture = rl.LoadTextureFromImage(atlas_img)
	rl.UnloadImage(atlas_img)
	first_floor := map_make_recursive(39, 29, 2)
	_cur_map = gamemap_create(first_floor)
	spawn(Mobile_ID.Hero, true)
	spawn(Mobile_ID.Bat)
	spawn(Consumable_ID.Potion_Healing)
	spawn(Consumable_ID.Scroll_Lightning)

	//_cur_map = map_make_recursive(39, 29)
	//_cur_map = map_make_roomer(39, 29, 5, 7)
	//_hero_loc = map_random_floor(_cur_map)
	//_hero_screen_pos = loc_to_screen(_hero_loc)
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
			entity_move_by(PLAYER_ID, .Up)
		case rl.IsKeyPressed(.A):
			entity_move_by(PLAYER_ID, .Left)
		case rl.IsKeyPressed(.S):
			entity_move_by(PLAYER_ID, .Down)
		case rl.IsKeyPressed(.D):
			entity_move_by(PLAYER_ID, .Right)
		}
	case .Move:
	// _hero_screen_pos.x = rl.Lerp(_hero_screen_pos.x, _hero_screen_to.x, LERP_MOVE_FACTOR)
	// _hero_screen_pos.y = rl.Lerp(_hero_screen_pos.y, _hero_screen_to.y, LERP_MOVE_FACTOR)
	// if rl.Vector2Distance(_hero_screen_pos, _hero_screen_to) < LERP_SNAP_THRESHOLD {
	// 	_hero_screen_pos = _hero_screen_to
	// }
	// if _hero_screen_pos == _hero_screen_to {
	// 	_state = .Input
	// }
	}

	return true
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.BeginMode2D(_cam)
	draw_map(_cur_map)
	//draw_tile(.Hero, _hero_screen_pos.x, _hero_screen_pos.y, rl.BEIGE)
	draw_entities(_cur_map)
	rl.EndMode2D()
	rl.DrawFPS(0, SCR_H - 24)
	rl.EndDrawing()
}

shutdown :: proc() {
	gamemap_destroy(&_cur_map)
	for _, &e in _entity_store {
		entity_destroy(&e)
	}
	delete(_entity_store)
	rl.UnloadTexture(_atlas_texture)
	rl.CloseWindow()
}

spawn :: proc {
	spawn_mobile,
	spawn_consumable,
}

spawn_mobile :: proc(mob_id: Mobile_ID, is_player := false) -> ObjId {
	mob := factory_make_mobile(mob_id, is_player)
	mob.pos = map_random_floor(_cur_map)
	entity_add(mob)
	gamemap_add_entity(&_cur_map, mob)
	return mob.id
}

spawn_consumable :: proc(cons_id: Consumable_ID) -> ObjId {
	cons := factory_make_consumable(cons_id)
	cons.pos = map_random_floor(_cur_map)
	entity_add(cons)
	gamemap_add_entity(&_cur_map, cons)
	return cons.id
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
