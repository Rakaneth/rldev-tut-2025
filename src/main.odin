package main

import "core:c"
import "core:container/queue"
import "core:encoding/cbor"
import "core:fmt"
import "core:io"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"
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
FONT_NUM_GLYPHS :: 73
DMAP_SENTINEL :: 9999
MSG_BUFFER_LEN :: 50
NUM_FLOORS :: 5
F0_MOBS :: 5
F1_MOBS :: 10
F2_MOBS :: 10
F3_MOBS :: 13
F4_MOBS :: 15

GameState :: enum {
	Input,
	Item,
	Move,
	Damage,
	Messages,
}

Sound_Name :: enum {
	Swing,
	Magic,
	Drink,
	Hit,
}

Sounds: [Sound_Name]rl.Sound

/* Game Globals */

_cam := rl.Camera2D {
	zoom = f32(SCR_W) / f32(WORLD_PIX_W),
}
_atlas_texture: rl.Texture2D
_hero_loc: Point
// _hero_screen_pos: [2]f32
// _hero_screen_to: [2]f32
_state: GameState
_cur_map_idx: int
_maps: [NUM_FLOORS]GameMap
_swing_sound: rl.Sound
_magic_sound: rl.Sound
_drink_sound: rl.Sound
_hit_sound: rl.Sound
_dungeon_music: rl.Music
_dam_timer: f32
_font: rl.Font
_font_atlas: rl.Texture2D
_damage := false
_target: union {
	ObjId,
}
_msg_queue_data: [MSG_BUFFER_LEN]cstring
_msg_queue: queue.Queue(cstring)
_sound_queue: queue.Queue(Sound_Name)

/* Setup */

load_sound_from_wave :: proc(data: []byte) -> rl.Sound {
	wav := rl.LoadWaveFromMemory(".wav", raw_data(data), c.int(len(data)))
	return rl.LoadSoundFromWave(wav)
}

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
	_font.glyphs[i] = {
		value = '-',
	}
	_font.recs[i] = {f32(21 * 8), 8, 8, 8}
	i += 1

	j := 0
	for small in 'a' ..= 'z' {
		_font.glyphs[i + j] = {
			value = small,
		}
		_font.recs[i + j] = {f32(j) * 8, 16, 8, 8}
		j += 1
	}
}

/*Game Init Procedures */
init :: proc() {
	rl.InitWindow(SCR_W, SCR_H, TITLE)
	rl.SetTargetFPS(FPS)
	rl.InitAudioDevice()
	rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

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
	_swing_sound = load_sound_from_wave(swing_sound_data)

	magic_sound_data := #load("../assets/sfx/magic1.wav")
	_magic_sound = load_sound_from_wave(magic_sound_data)

	drink_sound_data := #load("../assets/sfx/bubble.wav")
	_drink_sound = load_sound_from_wave(drink_sound_data)

	hit_sound_data := #load("../assets/sfx/random2.wav")
	_hit_sound = load_sound_from_wave(hit_sound_data)

	Sounds = {
		.Swing = _swing_sound,
		.Magic = _magic_sound,
		.Drink = _drink_sound,
		.Hit   = _hit_sound,
	}

	dungeon_mus_data := #load("../assets/sfx/dungeon.xm")
	_dungeon_music = rl.LoadMusicStreamFromMemory(
		".xm",
		raw_data(dungeon_mus_data),
		c.int(len(dungeon_mus_data)),
	)
	rl.SetMusicVolume(_dungeon_music, 0.3)
	queue.init(&_sound_queue)

	if os.exists("./test.dat") {
		load_game()
	} else {
		first_floor := map_make_roomer(40, 30, 5)
		second_floor := map_make_roomer(40, 30, 7)
		third_floor := map_make_roomer(40, 30, 9)
		fourth_floor := map_make_roomer(40, 30, 11)
		fifth_floor := map_make_recursive(39, 29)

		_maps[0] = gamemap_create(first_floor)
		_maps[1] = gamemap_create(second_floor)
		_maps[2] = gamemap_create(third_floor)
		_maps[3] = gamemap_create(fourth_floor)
		_maps[4] = gamemap_create(fifth_floor)

		build_floors()
		spawn(Mobile_ID.Hero, 0, true)
	}

	queue.init_from_slice(&_msg_queue, _msg_queue_data[:])

	_dam_timer = DAMAGE_TIMER
	mobile_update_fov(PLAYER_ID)

	//testing
	poison := Effect {
		duration  = 3,
		effect_id = .Poison,
	}
	player_mob := entity_get_comp_mut(PLAYER_ID, Mobile)
	effect_apply(poison, player_mob)
}

get_player :: proc() -> Entity {
	return entity_get(PLAYER_ID)
}

get_player_mut :: proc() -> ^Entity {
	return entity_get_mut(PLAYER_ID)
}

item_try_use :: proc(user: ObjId, idx: int) -> bool {
	user_e, mob_ok := entity_get_comp(user, Mobile)
	if len(user_e.inventory.items) > idx && mob_ok {
		mobile_use_consumable(user, user_e.inventory.items[idx])
		return true
	}

	return false
}

play_sound :: proc(sound: Sound_Name) {
	queue.push_back(&_sound_queue, sound)
}

//returns a value between 0.5 and 1
random_pitch :: proc() -> f32 {
	r := rand_next_float()
	return (r * 0.5) + 0.5
}

move_to_floor :: proc(floor_idx: int) {
	player := get_player()
	player_p := get_player_mut()
	player_m := entity_get_comp_mut(player.id, Mobile)
	gamemap_remove_entity(get_cur_map_mut(), player)
	gamemap_add_entity(&_maps[floor_idx], player)
	_cur_map_idx = floor_idx
	new_map := get_cur_map()
	player_p.pos = map_random_floor(new_map)
	mobile_update_fov(PLAYER_ID)
}

spawn_monsters :: proc(floor_id: int) {
	mob_check := rand_next_int(1, 100)
	mob_to_spawn: Mobile_ID
	mob_sets := [5]bit_set[Mobile_ID]{Tier0, Tier1, Tier2, Tier3, Tier4}
	num_mobs := [5]int{F0_MOBS, F1_MOBS, F2_MOBS, F3_MOBS, F4_MOBS}
	for _ in 0 ..< num_mobs[floor_id] {
		switch {
		case mob_check < 20:
			if floor_id > 0 {
				mob_to_spawn, _ = rand.choice_bit_set(mob_sets[floor_id - 1])
			}

		case mob_check >= 20 && mob_check < 70:
			if floor_id < len(_maps) - 1 {
				mob_to_spawn, _ = rand.choice_bit_set(mob_sets[floor_id])
			}

		case mob_check >= 70 && mob_check < 90:
			mob_to_spawn, _ = rand.choice_bit_set(mob_sets[floor_id + 1])
		case:
			continue
		}
		if mob_to_spawn != .Hero {
			spawn(mob_to_spawn, floor_id)
		}
	}
}

build_floors :: proc() {
	for &m, i in _maps {
		if i < len(_maps) - 1 {
			map_add_stairs(&m.terrain)
		}
		spawn_monsters(i)
	}
}

get_cur_map :: proc() -> GameMap {
	return _maps[_cur_map_idx]
}

get_cur_map_mut :: proc() -> ^GameMap {
	return &_maps[_cur_map_idx]
}


//Game Update. Should return false to stop the game
update :: proc() -> bool {
	dt := rl.GetFrameTime()
	moved: MoveResult = .NoMove
	player := get_player()
	player_mob := entity_get_comp_mut(PLAYER_ID, Mobile)
	cur_map := get_cur_map()

	#partial switch _state {
	case .Input:
		switch {
		case rl.WindowShouldClose():
			return false
		case rl.IsKeyPressed(.W):
			moved = entity_move_by(PLAYER_ID, .Up)
		case rl.IsKeyPressed(.A):
			moved = entity_move_by(PLAYER_ID, .Left)
		case rl.IsKeyPressed(.S):
			moved = entity_move_by(PLAYER_ID, .Down)
		case rl.IsKeyPressed(.D):
			moved = entity_move_by(PLAYER_ID, .Right)
		case rl.IsKeyPressed(.G):
			for e_id in get_cur_map().entities {
				item := entity_get(e_id)
				if e_id != PLAYER_ID && item.pos == player.pos {
					entity_pick_up_item(PLAYER_ID, e_id)
					moved = .Moved
				}
			}
		case rl.IsKeyPressed(.M):
			_state = .Messages
		case rl.IsKeyPressed(.I):
			_state = .Item
		case rl.IsKeyPressed(.ENTER):
			if grid_get(cur_map.terrain, player.pos) == Terrain.StairsDown {
				move_to_floor(_cur_map_idx + 1)
			}
		case rl.IsMouseButtonPressed(rl.MouseButton.LEFT):
			mouse_map_pos := get_world_mouse_pos()
			if maybe_target, target_ok := gamemap_get_mob_at(cur_map, mouse_map_pos);
			   target_ok && is_visible_to_player(mouse_map_pos) {
				_target = maybe_target.id
			}

		case rl.IsKeyPressed(.ESCAPE):
			return false
		}

		#partial switch moved {
		case .Moved, .Bump:
			_state = .Move
		}

	case .Item:
		to_use := -1
		switch {
		case rl.IsKeyPressed(.ESCAPE):
			_state = .Input
		case rl.IsKeyPressed(.KP_1):
			to_use = 0
		case rl.IsKeyPressed(.KP_2):
			to_use = 1
		case rl.IsKeyPressed(.KP_3):
			to_use = 2
		case rl.IsKeyPressed(.KP_4):
			to_use = 3
		case rl.IsKeyPressed(.KP_5):
			to_use = 4
		case rl.IsKeyPressed(.KP_6):
			to_use = 5
		case rl.IsKeyPressed(.KP_7):
			to_use = 6
		case rl.IsKeyPressed(.KP_8):
			to_use = 7
		}

		if to_use > -1 {
			used := item_try_use(PLAYER_ID, to_use)
			if used {
				_state = .Move
			}
		}

	case .Move:
		damage_step := false
		mobile_update_fov(PLAYER_ID)
		mobile_tick_effects(PLAYER_ID)
		gamemap_dmap_update(get_cur_map_mut(), player.pos)
		e_moved := MoveResult.NoMove

		for e_id in cur_map.entities {
			if e_mob, e_mob_ok := entity_get_comp(e_id, Mobile); e_mob_ok && e_id != PLAYER_ID {
				mobile_update_fov(e_id)
				if is_visible(e_id, PLAYER_ID) {
					mob_move_dir := dmap_get_next_step(cur_map.enemy_dmap, e_mob.pos)
					e_moved = entity_move_by(e_id, mob_move_dir)
				}
				mobile_tick_effects(e_id)
			}
		}
		if _damage {
			_damage = false
			_state = .Damage
		} else {
			_state = .Input
		}

	case .Damage:
		_dam_timer -= dt
		if _dam_timer <= 0 {
			_dam_timer += DAMAGE_TIMER
			for e_id in cur_map.entities {
				if mob, mob_ok := entity_get_comp_mut(e_id, Mobile); mob_ok {
					mob.damage = 0
				}
			}
			_state = .Input
		}
	case .Messages:
		if rl.IsKeyPressed(.ESCAPE) {
			_state = .Input
		}
	}

	if _target != nil && !is_visible_to_player(_target.?) {
		_target = nil
	}

	return true
}

/* Draw */
draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.BeginMode2D(_cam)
	cur_map := get_cur_map()
	#partial switch _state {
	case .Input, .Item, .Move, .Damage:
		draw_map(cur_map)
		draw_entities(cur_map)
		highlight_hover()
		if _target != nil {
			highlight(_target.?, COLOR_TARGET)
		}
		draw_stats()
		if _state == .Item {
			draw_item_menu()
		}
		draw_last_msg()
	case .Messages:
		draw_messages()
	}
	rl.EndMode2D()
	when ODIN_DEBUG {rl.DrawFPS(0, 0)}
	rl.EndDrawing()
}

/* Game Shutdown */
shutdown :: proc() {
	// if err := save_game(); err != .None {
	// 	when ODIN_DEBUG {
	// 		log.errorf("[SHUTDOWN] Error saving game: %v", err)
	// 	}
	// }

	for &gm in _maps {
		gamemap_destroy(&gm)
	}

	for _, &e in _entity_store {
		entity_destroy(&e)
	}

	delete(_entity_store)
	rl.UnloadMusicStream(_dungeon_music)
	rl.UnloadSound(_swing_sound)
	rl.UnloadSound(_magic_sound)
	rl.UnloadSound(_hit_sound)
	rl.UnloadSound(_drink_sound)
	rl.CloseAudioDevice()
	rl.UnloadTexture(_atlas_texture)
	free(_font.glyphs)
	free(_font.recs)
	for msg in _msg_queue_data {
		delete(msg)
	}
	queue.destroy(&_msg_queue)
	queue.destroy(&_sound_queue)
	rl.UnloadTexture(_font_atlas)
	rl.CloseWindow()
}

/* Entity Spawn Functions */
spawn :: proc {
	spawn_mobile,
	spawn_consumable,
}

spawn_mobile :: proc(mob_id: Mobile_ID, floor_idx: int, is_player := false) -> ObjId {
	mob := factory_make_mobile(mob_id, is_player)
	mob.pos = map_random_floor(_maps[floor_idx])
	entity_add(mob)
	gamemap_add_entity(&_maps[floor_idx], mob)
	return mob.id
}

spawn_consumable :: proc(cons_id: Consumable_ID, floor_idx: int) -> ObjId {
	cons := factory_make_consumable(cons_id)
	cons.pos = map_random_floor(_maps[floor_idx])
	entity_add(cons)
	gamemap_add_entity(&_maps[floor_idx], cons)
	return cons.id
}


/* Messaging */

//ALLOCATES a new cstring, uses `rl.TextFormat` under the hood
add_msg :: proc(msg: cstring, args: ..any) {
	formatted := strings.clone_from_cstring(rl.TextFormat(msg, ..args))

	if queue.len(_msg_queue) >= MSG_BUFFER_LEN {
		to_delete := queue.pop_back(&_msg_queue)
		delete(to_delete)
	}
	queue.push_front(&_msg_queue, strings.clone_to_cstring(formatted))
	delete(formatted)
}

/* Saving / Loading */

SaveLoad_Err :: enum {
	None,
	Failed_Save_Marshal,
	Failed_Save_Write,
	Failed_Load_Unmarshal,
	Failed_Load_Read,
}

GameSave :: struct {
	entities:    map[ObjId]Entity,
	maps:        []GameMap,
	cur_map_idx: int,
}

save_game :: proc(loc := #caller_location) -> (err: SaveLoad_Err) {
	gs: GameSave
	gs.entities = _entity_store
	gs.cur_map_idx = _cur_map_idx
	gs.maps = _maps[:]

	data, marshal_err := cbor.marshal_into_bytes(gs, loc = loc)
	defer delete(data)

	if marshal_err != nil {
		when ODIN_DEBUG {
			log.error("[SAVE] Failed to marshal save file")
		}
		err = .Failed_Save_Marshal
		return
	}

	if !os.write_entire_file("test.dat", data) {
		when ODIN_DEBUG {
			log.error("[SAVE] Failed to write save file")
		}
		err = .Failed_Save_Write
		return
	}

	return
}

load_game :: proc(loc := #caller_location) -> (err: SaveLoad_Err) {
	gs: GameSave
	data, read_ok := os.read_entire_file("./test.dat", loc = loc)
	if !read_ok {
		when ODIN_DEBUG {
			log.error("[LOAD] Failed to read save file!")
		}
		err = .Failed_Load_Read
		return
	}
	defer delete(data)


	unmarshal_err := cbor.unmarshal_from_bytes(
		data,
		&gs,
		allocator = context.temp_allocator,
		loc = loc,
	)
	if unmarshal_err != nil {
		when ODIN_DEBUG {
			log.error("[LOAD] Failed to load save!")
		}
		err = .Failed_Load_Unmarshal
		return
	}

	for idx, &e in gs.entities {
		_entity_store[idx] = entity_clone(e)
	}

	for &m, i in gs.maps {
		_maps[i] = gamemap_clone(m)
	}

	_cur_map_idx = gs.cur_map_idx

	return
}

/* Main */

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
	cur_snd: rl.Sound

	for running {
		rl.UpdateMusicStream(_dungeon_music)
		running = update()
		draw()
		if queue.len(_sound_queue) > 0 && !rl.IsSoundPlaying(cur_snd) {
			snd_name := queue.pop_front(&_sound_queue)
			new_snd := Sounds[snd_name]
			if new_snd == cur_snd {
				rl.SetSoundPitch(new_snd, random_pitch())
			} else {
				rl.SetSoundPitch(new_snd, 1)
			}
			cur_snd = new_snd
			rl.PlaySound(cur_snd)
		}
		free_all(context.temp_allocator)
	}
}
