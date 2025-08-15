package main

import "core:c"
import "core:slice"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

/* swatch */
COLOR_STONE_LIGHT: rl.Color : {192, 192, 192, 255}
COLOR_STONE_DARK: rl.Color : {96, 96, 96, 255}
COLOR_STAIRS: rl.Color : {192, 192, 0, 255}
COLOR_WOOD: rl.Color : {192, 101, 96, 255}
COLOR_UI_TEXT: rl.Color = {192, 192, 0, 255}

/* other UI constants */
ITEM_LIST_Y :: 80

Atlas_Tile :: enum {
	Hero,
	Floor,
	WallHorz,
	WallVert,
	WallTLeft,
	WallTRight,
	WallTUp,
	WallTDown,
	WallCross,
	WallUpEnd,
	WallDownEnd,
	WallLeftEnd,
	WallRightEnd,
	WallLowerLeft,
	WallLowerRight,
	WallUpperLeft,
	WallUpperRight,
	Corridor,
	NullTile,
	Door,
	Stairs,
	WallBlock,
	Bat,
	Potion,
	Scroll,
}

@(rodata)
TextureAtlas := [Atlas_Tile]rl.Rectangle {
	.NullTile       = {0, 0, TILE_SIZE, TILE_SIZE},
	.Hero           = {96, 0, TILE_SIZE, TILE_SIZE},
	.Door           = {80, 32, TILE_SIZE, TILE_SIZE},
	.Stairs         = {80, 16, TILE_SIZE, TILE_SIZE},
	.WallHorz       = {0, 16, TILE_SIZE, TILE_SIZE},
	.WallVert       = {16, 0, TILE_SIZE, TILE_SIZE},
	.WallTRight     = {32, 0, TILE_SIZE, TILE_SIZE},
	.WallTLeft      = {64, 32, TILE_SIZE, TILE_SIZE},
	.WallTUp        = {32, 32, TILE_SIZE, TILE_SIZE},
	.WallTDown      = {64, 0, TILE_SIZE, TILE_SIZE},
	.WallCross      = {48, 16, TILE_SIZE, TILE_SIZE},
	.WallBlock      = {16, 16, TILE_SIZE, TILE_SIZE},
	.WallUpEnd      = {48, 0, TILE_SIZE, TILE_SIZE},
	.WallLeftEnd    = {32, 16, TILE_SIZE, TILE_SIZE},
	.WallRightEnd   = {64, 16, TILE_SIZE, TILE_SIZE},
	.WallDownEnd    = {48, 32, TILE_SIZE, TILE_SIZE},
	.WallLowerLeft  = {112, 0, TILE_SIZE, TILE_SIZE},
	.WallLowerRight = {128, 0, TILE_SIZE, TILE_SIZE},
	.WallUpperLeft  = {144, 0, TILE_SIZE, TILE_SIZE},
	.WallUpperRight = {160, 0, TILE_SIZE, TILE_SIZE},
	.Corridor       = {16, 32, TILE_SIZE, TILE_SIZE},
	.Floor          = {0, 32, TILE_SIZE, TILE_SIZE},
	.Bat            = {16, 48, TILE_SIZE, TILE_SIZE},
	.Potion         = {144, 32, TILE_SIZE, TILE_SIZE},
	.Scroll         = {176, 32, TILE_SIZE, TILE_SIZE},
}

draw_tile :: proc(tile: Atlas_Tile, x: f32, y: f32, tint: rl.Color) {
	src_rect := TextureAtlas[tile]
	dest_rect := rl.Rectangle{x, y, TILE_SIZE, TILE_SIZE}
	rl.DrawTexturePro(_atlas_texture, src_rect, dest_rect, {0, 0}, 0, tint)
}

loc_to_screen :: proc(p: Point) -> [2]f32 {
	return {f32(p.x), f32(p.y)} * TILE_SIZE
}

draw_cell :: proc(tile: Atlas_Tile, world_pos: Point, tint: rl.Color) {
	screen_pos := loc_to_screen(world_pos)
	draw_tile(tile, screen_pos.x, screen_pos.y, tint)
}

draw_map :: proc(m: TerrainData) {
	to_draw: Atlas_Tile

	wall_score :: proc(i_m: TerrainData, i_pos: Point) -> int {
		result := 0
		up := point_by_dir(i_pos, .Up)
		right := point_by_dir(i_pos, .Right)
		down := point_by_dir(i_pos, .Down)
		left := point_by_dir(i_pos, .Left)

		if map_is_wall(i_m, up) do result += 1
		if map_is_wall(i_m, right) do result += 2
		if map_is_wall(i_m, down) do result += 4
		if map_is_wall(i_m, left) do result += 8

		return result
	}

	for y in 0 ..< m.height {
		for x in 0 ..< m.width {
			pos := Point{x, y}
			t := grid_get(m, pos)
			if t == Terrain.Wall {
				switch wall_score(m, pos) {
				case 0:
					to_draw = .WallBlock
				case 1:
					to_draw = .WallDownEnd
				case 2:
					to_draw = .WallLeftEnd
				case 3:
					to_draw = .WallLowerLeft
				case 4:
					to_draw = .WallUpEnd
				case 5:
					to_draw = .WallVert
				case 6:
					to_draw = .WallUpperLeft
				case 7:
					to_draw = .WallTRight
				case 8:
					to_draw = .WallRightEnd
				case 9:
					to_draw = .WallLowerRight
				case 10:
					to_draw = .WallHorz
				case 11:
					to_draw = .WallTUp
				case 12:
					to_draw = .WallUpperRight
				case 13:
					to_draw = .WallTLeft
				case 14:
					to_draw = .WallTDown
				case 15:
					ne := Point{1, -1}
					se := Point{1, 1}
					sw := Point{-1, 1}
					nw := Point{-1, -1}

					t_ne := grid_get(m, pos + ne)
					t_se := grid_get(m, pos + se)
					t_nw := grid_get(m, pos + nw)
					t_sw := grid_get(m, pos + sw)

					switch {
					case t_ne == Terrain.Floor &&
					     t_se == Terrain.Floor &&
					     t_nw == Terrain.Floor &&
					     t_sw == Terrain.Floor:
						to_draw = .WallCross
					case t_ne == Terrain.Floor:
						to_draw = .WallLowerLeft
					case t_se == Terrain.Floor:
						to_draw = .WallUpperLeft
					case t_nw == Terrain.Floor:
						to_draw = .WallLowerRight
					case t_sw == Terrain.Floor:
						to_draw = .WallUpperRight
					case:
						to_draw = .NullTile
					}
				}
			} else {
				#partial switch t {
				case .Floor:
					e := point_by_dir(pos, .Left)
					w := point_by_dir(pos, .Right)
					n := point_by_dir(pos, .Up)
					s := point_by_dir(pos, .Down)

					e_null := grid_get(m, e) == Terrain.NullTile
					w_null := grid_get(m, w) == Terrain.NullTile
					n_null := grid_get(m, n) == Terrain.NullTile
					s_null := grid_get(m, s) == Terrain.NullTile

					if (e_null && w_null) || (n_null && s_null) {
						to_draw = .Corridor
					} else {
						to_draw = .Floor
					}
				case .StairsDown:
					to_draw = .Stairs
				case .Door:
					to_draw = .Door
				case .NullTile:
					to_draw = .NullTile
				}
			}
			if is_visible_to_player(pos) {
				draw_cell(to_draw, pos, rl.WHITE)
			} else if gamemap_is_explored(_cur_map, pos) {
				draw_cell(to_draw, pos, rl.BLUE)
			}
		}
	}
}

draw_entities :: proc(gm: GameMap) {
	z_cmp :: proc(a, b: ObjId) -> bool {
		a_e := entity_get(a)
		b_e := entity_get(b)
		return a_e.z < b_e.z
	}

	slice.sort_by(gm.entities[:], z_cmp)
	for e_id in gm.entities {
		e := entity_get(e_id)
		if is_visible_to_player(e.pos) {
			draw_cell(e.tile, e.pos, e.color)
			if mob, mob_ok := e.etype.(Mobile); mob_ok && _state == .Damage && mob.damage > 0 {
				buf: [4]u8
				strconv.itoa(buf[:], mob.damage)
				ptr := raw_data(buf[:])
				draw_combat_text(e, cstring(ptr))
			}
		}
	}
}

draw_stats :: proc() {
	mob_player := entity_get_comp(PLAYER_ID, Mobile)
	text_size: f32 = TILE_SIZE * 5 / 7
	text := rl.TextFormat(
		"ST: %d HD: %d AG: %d WL: %d HP: %d/%d STAM: %d FTG: %d",
		mob_player.stats[.ST],
		mob_player.stats[.HD],
		mob_player.stats[.AG],
		mob_player.stats[.WL],
		mob_player.cur_hp,
		mob_player.max_hp,
		mob_player.stamina,
		mob_player.fatigue,
	)
	text_w := rl.MeasureTextEx(_font, text, text_size, 0)
	rl.DrawRectangle(0, 29 * 16, c.int(text_w.x), c.int(text_w.y), rl.BLACK)
	rl.DrawTextEx(_font, text, {0, 29 * 16}, text_size, 0, COLOR_UI_TEXT)
}

draw_combat_text :: proc(e: Entity, text: cstring) {
	pix_pos := loc_to_screen(e.pos)
	//rl.DrawText(text, i32(pix_pos.x), i32(pix_pos.y), TILE_SIZE / 2, rl.WHITE)
	rl.DrawTextEx(_font, text, {pix_pos.x, pix_pos.y}, TILE_SIZE / 2, 0, rl.WHITE)
}


draw_item_menu :: proc() {
	item_ids := get_player().inventory.items
	font_size := f32(TILE_SIZE * 3 / 4)

	i := 0

	if len(item_ids) > 0 {
		for item_id in item_ids {
			item := entity_get_comp(item_id, Consumable)
			txt := rl.TextFormat("%d: %s x%d", i + 1, item.name, item.uses)
			rl.DrawTextEx(
				_font,
				txt,
				{0, f32(ITEM_LIST_Y + f32(i) * font_size)},
				font_size,
				0,
				COLOR_UI_TEXT,
			)
			i += 1
		}
		rl.DrawTextEx(
			_font,
			"[ESC] to close backpack",
			{0, f32(ITEM_LIST_Y + f32(i) * font_size)},
			font_size,
			0,
			COLOR_UI_TEXT,
		)
	} else {
		rl.DrawTextEx(_font, "No items in backpack", {0, ITEM_LIST_Y}, font_size, 0, COLOR_UI_TEXT)
		rl.DrawTextEx(
			_font,
			"[ESC] to close backpack",
			{0, ITEM_LIST_Y + font_size},
			font_size,
			0,
			COLOR_UI_TEXT,
		)
	}
}

highlight :: proc(e_id: ObjId) {
	e := entity_get(e_id)
	s_pos := loc_to_screen(e.pos)
	rect := rl.Rectangle{s_pos.x, s_pos.y, TILE_SIZE, TILE_SIZE}
	rl.DrawRectangleLinesEx(rect, 2, COLOR_UI_TEXT)
}

screen_to_loc :: proc(scr_pos: rl.Vector2) -> Point {
	world_pix_pos := rl.GetScreenToWorld2D(scr_pos, _cam)
	return {int(world_pix_pos.x / TILE_SIZE), int(world_pix_pos.y / TILE_SIZE)}
}

get_world_mouse_pos :: proc() -> Point {
	raw_mouse_pos := rl.GetMousePosition()
	mouse_map_pos := screen_to_loc(raw_mouse_pos)
	return mouse_map_pos
}

highlight_hover :: proc() {
	mouse_map_pos := get_world_mouse_pos()
	top_e, num_e := gamemap_get_entity_at(_cur_map, mouse_map_pos)
	if num_e == 1 {
		highlight(top_e.id)
		tooltip(top_e.id)
	}
}

tooltip :: proc(e_id: ObjId) {
	text_size := f32(TILE_SIZE * 3 / 4)
	border :: 1
	padding := text_size / 2
	e := entity_get(e_id)
	s_pos := loc_to_screen(e.pos)
	desc_m := rl.MeasureTextEx(_font, e.desc, text_size, 0)
	rect := rl.Rectangle {
		s_pos.x - border,
		s_pos.y - border - (3 * text_size),
		desc_m.x + border + padding,
		(desc_m.y + border) * 3,
	}
	rl.DrawRectangleRec(rect, rl.BLACK)
	rl.DrawRectangleLinesEx(rect, border, COLOR_UI_TEXT)
	rl.DrawTextEx(_font, e.name, {rect.x + border, rect.y + border}, text_size, 0, COLOR_UI_TEXT)
	rl.DrawTextEx(
		_font,
		e.desc,
		{rect.x + border, rect.y + (text_size * 2) + border},
		text_size,
		0,
		COLOR_UI_TEXT,
	)
}
