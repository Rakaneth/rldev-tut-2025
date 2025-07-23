package main

import rl "vendor:raylib"

/* swatch */
STONE_LIGHT: rl.Color : {192, 192, 192, 255}
STONE_DARK: rl.Color : {96, 96, 96, 255}
STAIRS: rl.Color : {192, 192, 0, 255}
WOOD: rl.Color : {192, 101, 96, 255}

Atlas_Tile :: enum {
	Hero,
	WallUpperLeft,
	WallUpperRight,
	WallLowerLeft,
	WallLowerRight,
	WallHorz,
	WallVertLeft,
	WallVertRight,
	EmptySpace,
	NullTile,
	DoorClosed,
	DoorOpen,
	StairsDown,
}

@(rodata)
TextureAtlas := [Atlas_Tile]rl.Rectangle {
	.Hero           = {32, 0, TILE_SIZE, TILE_SIZE},
	.WallUpperLeft  = {0, 0, TILE_SIZE, TILE_SIZE},
	.WallUpperRight = {24, 0, TILE_SIZE, TILE_SIZE},
	.WallLowerLeft  = {0, 16, TILE_SIZE, TILE_SIZE},
	.WallLowerRight = {24, 16, TILE_SIZE, TILE_SIZE},
	.EmptySpace     = {8, 8, TILE_SIZE, TILE_SIZE},
	.NullTile       = {16, 8, TILE_SIZE, TILE_SIZE},
	.DoorClosed     = {32, 16, TILE_SIZE, TILE_SIZE},
	.DoorOpen       = {40, 16, TILE_SIZE, TILE_SIZE},
	.StairsDown     = {32, 24, TILE_SIZE, TILE_SIZE},
	.WallHorz       = {8, 0, TILE_SIZE, TILE_SIZE},
	.WallVertLeft   = {0, 8, TILE_SIZE, TILE_SIZE},
	.WallVertRight  = {24, 8, TILE_SIZE, TILE_SIZE},
}

TileRender :: struct {
	tile:  Atlas_Tile,
	color: rl.Color,
}

@(rodata)
TerrainToAtlas := [Terrain]TileRender {
	.NullTile       = {.NullTile, rl.RED},
	.WallUpperLeft  = {.WallUpperLeft, STONE_LIGHT},
	.WallUpperRight = {.WallUpperRight, STONE_LIGHT},
	.WallLowerLeft  = {.WallLowerLeft, STONE_LIGHT},
	.WallLowerRight = {.WallLowerRight, STONE_LIGHT},
	.WallHorz       = {.WallHorz, STONE_LIGHT},
	.WallVertLeft   = {.WallVertLeft, STONE_LIGHT},
	.WallVertRight  = {.WallVertRight, STONE_LIGHT},
	.DoorClosed     = {.DoorClosed, WOOD},
	.DoorOpen       = {.DoorOpen, WOOD},
	.StairsDown     = {.StairsDown, STAIRS},
	.Floor          = {.EmptySpace, STONE_LIGHT},
}

draw_tile :: proc(tile: Atlas_Tile, x: f32, y: f32, tint: rl.Color) {
	src_rect := TextureAtlas[tile]
	dest_rect := rl.Rectangle{x, y, TILE_SIZE, TILE_SIZE}
	rl.DrawTexturePro(_atlas_texture, src_rect, dest_rect, {0, 0}, 0, tint)
}

loc_to_screen :: proc(p: Point) -> [2]f32 {
	return {f32(p.x), f32(p.y)} * 8
}

draw_cell :: proc(tile: Atlas_Tile, world_pos: Point, tint: rl.Color) {
	screen_pos := loc_to_screen(world_pos)
	draw_tile(tile, screen_pos.x, screen_pos.y, tint)
}

draw_map :: proc(m: TerrainData) {
	to_draw: TileRender
	for y in 0 ..< m.height {
		for x in 0 ..< m.width {
			pos := Point{x, y}
			to_draw = TerrainToAtlas[grid_get(m, pos)]
			draw_cell(to_draw.tile, pos, to_draw.color)
		}
	}
}
