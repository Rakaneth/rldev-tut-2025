package main

import "core:c"
import "core:fmt"
import "core:log"
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
DAMAGE_TIMER :: 0.3
FONT_NUM_GLYPHS :: 46

GameState :: enum {
	Input,
	Move,
	Damage,
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
_swing_sound: rl.Sound
_dungeon_music: rl.Music
_dam_timer: f32
_font: rl.Font
_font_atlas: rl.Texture2D

/* Game Lifecycle */

build_font :: proc() {
	_font.baseSize = 8
	_font.glyphCount = FONT_NUM_GLYPHS
	_font.glyphs = raw_data(make([]rl.GlyphInfo, FONT_NUM_GLYPHS))
	_font.recs = raw_data(make([]rl.Rectangle, FONT_NUM_GLYPHS))
	_font.texture = _font_atlas
	i := 0
	for glyph in 'A' ..= 'Z' {
		_font.glyphs[i] = {
			value = glyph,
		}
		_font.recs[i] = {f32(i) * 8, 0, 8, 8}
		i += 1
	}
	for num_glyph in '0' ..= '9' {
		_font.glyphs[i] = {
			value = num_glyph,
		}
		_font.recs[i] = {f32(i - 26) * 8, 8, 8, 8}
		i += 1
	}
	for punc in ":[]/.,!/\"'" {
		_font.glyphs[i] = {
			value = punc,
		}
		_font.recs[i] = {f32(i - 26) * 8, 8, 8, 8}
		i += 1
	}
}

init :: proc() {
	rl.InitWindow(SCR_W, SCR_H, TITLE)
	rl.SetTargetFPS(FPS)
	rl.InitAudioDevice()

	atlas_data := #load("../assets/gfx/lovable-rogue-cut.png")
	atlas_img := rl.LoadImageFromMemory(".png", raw_data(atlas_data), c.int(len(atlas_data)))
	_atlas_texture = rl.LoadTextureFromImage(atlas_img)
	rl.UnloadImage(atlas_img)

	font_data := #load("../assets/gfx/lovable-rogue-font.png")
	font_img := rl.LoadImageFromMemory(".png", raw_data(font_data), c.int(len(atlas_data)))
	_font_atlas = rl.LoadTextureFromImage(font_img)
	rl.UnloadImage(font_img)

	build_font()

	swing_sound_data := #load("../assets/sfx/swing.wav")
	swing_sound_wav := rl.LoadWaveFromMemory(
		".wav",
		raw_data(swing_sound_data),
		c.int(len(swing_sound_data)),
	)
	_swing_sound = rl.LoadSoundFromWave(swing_sound_wav)
	// _swing_sound = rl.LoadSound("./swing.wav")

	dungeon_mus_data := #load("../assets/sfx/dungeon.xm")
	_dungeon_music = rl.LoadMusicStreamFromMemory(
		".xm",
		raw_data(dungeon_mus_data),
		c.int(len(dungeon_mus_data)),
	)
	rl.SetMusicVolume(_dungeon_music, 0.5)
	// _dungeon_music = rl.LoadMusicStream("./dungeon.xm")

	// first_floor := map_make_recursive(39, 29, 1)
	// first_floor := map_make_arena(21, 21)
	first_floor := map_make_roomer(40, 30, 5)
	_cur_map = gamemap_create(first_floor)
	spawn(Mobile_ID.Hero, true)
	spawn(Mobile_ID.Bat)
	spawn(Consumable_ID.Potion_Healing)
	spawn(Consumable_ID.Scroll_Lightning)

	_dam_timer = DAMAGE_TIMER
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
		mobile_update_fov(PLAYER_ID)

	case .Move:
	// _hero_screen_pos.x = rl.Lerp(_hero_screen_pos.x, _hero_screen_to.x, LERP_MOVE_FACTOR)
	// _hero_screen_pos.y = rl.Lerp(_hero_screen_pos.y, _hero_screen_to.y, LERP_MOVE_FACTOR)
	// if rl.Vector2Distance(_hero_screen_pos, _hero_screen_to) < LERP_SNAP_THRESHOLD {
	// 	_hero_screen_pos = _hero_screen_to
	// }
	// if _hero_screen_pos == _hero_screen_to {
	// 	_state = .Input
	// }
	case .Damage:
		_dam_timer -= dt
		if _dam_timer <= 0 {
			_dam_timer += DAMAGE_TIMER
			for e_id in _cur_map.entities {
				if mob, mob_ok := entity_get_comp_mut(e_id, Mobile); mob_ok {
					mob.damage = 0
				}
			}
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
	//draw_tile(.Hero, _hero_screen_pos.x, _hero_screen_pos.y, rl.BEIGE)
	draw_entities(_cur_map)
	draw_stats()
	rl.EndMode2D()
	when ODIN_DEBUG {rl.DrawFPS(0, 0)}
	rl.EndDrawing()
}

shutdown :: proc() {
	gamemap_destroy(&_cur_map)
	for _, &e in _entity_store {
		entity_destroy(&e)
	}
	delete(_entity_store)
	rl.UnloadMusicStream(_dungeon_music)
	rl.UnloadSound(_swing_sound)
	rl.CloseAudioDevice()
	rl.UnloadTexture(_atlas_texture)
	// rl.UnloadFontData(_font.glyphs, FONT_NUM_GLYPHS)
	// rl.UnloadFont(_font)
	free(_font.glyphs)
	free(_font.recs)
	rl.UnloadTexture(_font_atlas)
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
		logger := log.create_console_logger(log.Level.Info)
		context.logger = logger
		defer log.destroy_console_logger(logger)
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

	if rl.IsMusicValid(_dungeon_music) && rl.IsMusicReady(_dungeon_music) {
		rl.PlayMusicStream(_dungeon_music)
	}

	running := true

	for running {
		rl.UpdateMusicStream(_dungeon_music)
		running = update()
		draw()
	}
}
