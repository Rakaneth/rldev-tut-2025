package main

import "core:container/queue"
import "core:fmt"
import "core:math/rand"

/* Coordinates */

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

point_by_dir :: proc(pos: Point, dir: Direction) -> Point {
	return pos + Direction_Offsets[dir]
}

/* Rectangles */

Rect :: struct {
	x1: int,
	y1: int,
	x2: int,
	y2: int,
}

rect_from_xywh :: proc(x, y, w, h: int) -> Rect {
	return {x, y, x + w - 1, y + h - 1}
}

rect_intersect :: proc(r1, r2: Rect, padding := 0) -> bool {
	if r1.x1 > r2.x2 + padding ||
	   r1.y1 > r2.y2 + padding ||
	   r2.x1 > r1.x2 + padding ||
	   r2.y1 > r1.y2 + padding {
		return false
	}

	return true
}

rect_width :: proc(r: Rect) -> int {
	return r.x2 - r.x1 + 1
}

rect_height :: proc(r: Rect) -> int {
	return r.y2 - r.y1 + 1
}

/* Grid Structure */

Grid :: struct($Val: typeid) {
	data:   []Val,
	width:  int,
	height: int,
}

grid_create :: proc(
	width, height: int,
	$Val: typeid,
	allocator := context.allocator,
	loc := #caller_location,
) -> Grid(Val) {
	data := make([]Val, width * height, allocator, loc)
	return {data = data, width = width, height = height}
}

grid_destroy :: proc(g: ^$T/Grid) {
	delete(g.data)
}

grid_idx :: proc(grid: $T/Grid, pos: Point) -> int {
	return pos.y * grid.width + pos.x
}

grid_in_bounds :: proc(grid: $T/Grid, pos: Point) -> bool {
	return pos.x >= 0 && pos.y >= 0 && pos.x < grid.width && pos.y < grid.height
}

grid_get :: proc(grid: $T/Grid($Val), pos: Point) -> (Val, bool) #optional_ok {
	if grid_in_bounds(grid, pos) {
		idx := grid_idx(grid, pos)
		return grid.data[idx], true
	}

	return {}, false
}

grid_set :: proc(grid: ^$T/Grid($Val), pos: Point, val: Val) -> bool {
	if grid_in_bounds(grid^, pos) {
		idx := grid_idx(grid^, pos)
		grid.data[idx] = val
		return true
	}

	return false
}

grid_fill :: proc(grid: ^$T/Grid($Val), val: Val) {
	for &item in grid.data {
		item = val
	}
}


/* map-specific functions */
Terrain :: enum {
	NullTile,
	Wall,
	Floor,
	Door,
	StairsDown,
}

TerrainData :: Grid(Terrain)

WALKABLE: bit_set[Terrain] : {.Floor, .StairsDown}

map_debug_print :: proc(m: TerrainData) {
	to_print: rune
	for y in 0 ..< m.height {
		for x in 0 ..< m.width {
			t := grid_get(m, {x, y})
			switch t {
			case .Wall:
				to_print = '#'
			case .Floor:
				to_print = '.'
			case .Door:
				to_print = '+'
			case .StairsDown:
				to_print = '>'
			case .NullTile:
				to_print = 'X'
			}
			fmt.print(to_print)
		}
		fmt.println("")
	}
}

map_is_wall :: proc(m: TerrainData, pos: Point) -> bool {
	return grid_get(m, pos) == Terrain.Wall
}

map_is_wall_or_null :: proc(m: TerrainData, pos: Point) -> bool {
	t := grid_get(m, pos)
	return t == Terrain.Wall || t == Terrain.NullTile
}

map_carve_rect :: proc(m: ^TerrainData, r: Rect) {
	t: Terrain
	for y in r.y1 ..= r.y2 {
		for x in r.x1 ..= r.x2 {
			if x == r.x1 || x == r.x2 || y == r.y1 || y == r.y2 {
				t = .Wall
			} else {
				t = .Floor
			}
			grid_set(m, {x, y}, t)
		}
	}
}

map_random_floor :: proc(m: TerrainData) -> Point {
	result := Point{-1, -1}

	for grid_get(m, result) != Terrain.Floor {
		result.x = rand_next_int(1, m.width - 2)
		result.y = rand_next_int(1, m.height - 2)
	}

	return result
}


map_can_walk :: proc(m: TerrainData, pos: Point) -> bool {
	return grid_get(m, pos) in WALKABLE
}

/* Map Creation */
map_make_arena :: proc(width, height: int) -> TerrainData {
	m := grid_create(width, height, Terrain)
	r := rect_from_xywh(0, 0, m.width, m.height)
	map_carve_rect(&m, r)
	return m
}

map_make_recursive :: proc(width, height: int, rand_factor: int = 0) -> TerrainData {
	assert(width & 1 == 1 && height & 1 == 1)
	q: queue.Queue(Point)
	queue.init(&q)
	defer queue.destroy(&q)
	m := grid_create(width, height, Terrain)
	grid_fill(&m, Terrain.Wall)
	cur: Point = {
		1 + 2 * (rand_next_int(1, width - 1) / 2),
		1 + 2 * (rand_next_int(1, height - 1) / 2),
	}
	grid_set(&m, cur, Terrain.Floor)
	queue.push_back(&q, cur)
	next: Point
	blocked := false
	dirs: [4]Direction = {.Down, .Left, .Right, .Up}
	rand.shuffle(dirs[:])

	can_use :: proc(i_m: TerrainData, pos: Point) -> bool {
		return(
			grid_in_bounds(i_m, pos) &&
			grid_get(i_m, pos) == Terrain.Wall &&
			pos.x >= 1 &&
			pos.y >= 1 &&
			pos.x < i_m.width - 1 &&
			pos.y < i_m.width - 2 \
		)
	}

	for queue.len(q) > 0 {
		blocked = false
		cur = queue.pop_front(&q)
		for !blocked {
			blocked = true
			if rand_next_int(0, rand_factor) == 0 do rand.shuffle(dirs[:])
			for next_dir in dirs {
				offset := Direction_Offsets[next_dir] * 2
				next = cur + offset
				if can_use(m, next) {
					blocked = false
					between := point_by_dir(cur, next_dir)
					grid_set(&m, next, Terrain.Floor)
					grid_set(&m, between, Terrain.Floor)
					queue.push_back(&q, next)
					cur = next
					break
				}
			}
		}
	}

	return m
}

map_make_roomer :: proc(
	width, height: int,
	min_dim := 3,
	max_dim := 9,
	tries := 1000,
) -> TerrainData {
	rect_list := make([dynamic]Rect)
	defer delete(rect_list)

	rect_in_bounds :: proc(m: TerrainData, r: Rect) -> bool {
		return grid_in_bounds(m, {r.x1, r.y1}) && grid_in_bounds(m, {r.x2, r.y2})
	}

	m := grid_create(width, height, Terrain)
	outer: for _ in 0 ..< tries {
		new_x := rand_next_int(min_dim, m.width - min_dim)
		new_y := rand_next_int(min_dim, m.height - min_dim)
		new_w := rand_next_int(min_dim, max_dim)
		new_h := rand_next_int(min_dim, max_dim)
		new_r := rect_from_xywh(new_x, new_y, new_w, new_h)

		if rect_in_bounds(m, new_r) {
			for old_r in rect_list {
				if rect_intersect(new_r, old_r, 2) do continue outer
			}
			append(&rect_list, new_r)
		}
	}

	for r in rect_list {
		map_carve_rect(&m, r)
	}

	return m
}

/* Full GameMap structure */

GameMap :: struct {
	using terrain: TerrainData,
	entities:      [dynamic]ObjId,
	explored:      Grid(bool),
}

gamemap_create :: proc(
	m: TerrainData,
	allocator := context.allocator,
	loc := #caller_location,
) -> GameMap {
	return {
		terrain = m,
		entities = make([dynamic]ObjId, allocator, loc),
		explored = grid_create(m.width, m.height, bool),
	}
}

gamemap_destroy :: proc(gm: ^GameMap) {
	grid_destroy(&gm.terrain)
	grid_destroy(&gm.explored)
	delete(gm.entities)
}

gamemap_add_entity :: proc(gm: ^GameMap, e: Entity) {
	if maybe_mob, ok := entity_get_comp_mut(e.id, Mobile); ok {
		grid_destroy(&maybe_mob.visible)
		maybe_mob.visible = grid_create(gm.width, gm.height, bool)
	}
	append(&gm.entities, e.id)
}

gamemap_remove_entity :: proc(gm: ^GameMap, e: Entity) {
	unordered_remove(&gm.entities, e.id)
}

gamemap_explore :: proc(gm: ^GameMap, pos: Point) {
	grid_set(&gm.explored, pos, true)
}

gamemap_is_explored :: proc(gm: GameMap, pos: Point) -> bool {
	return grid_get(gm.explored, pos)
}

gamemap_get_mob_at :: proc(gm: GameMap, pos: Point) -> (EntityInst(Mobile), bool) {
	for e_id in gm.entities {
		maybe_mob, ok := entity_get_comp(e_id, Mobile)
		if ok && maybe_mob.pos == pos {
			return maybe_mob, true
		}
	}

	return {}, false
}

gamemap_get_mob_at_mut :: proc(gm: GameMap, pos: Point) -> (EntityInstMut(Mobile), bool) {
	for e_id in gm.entities {
		maybe_mob, ok := entity_get_comp_mut(e_id, Mobile)
		if ok && maybe_mob.pos == pos {
			return maybe_mob, true
		}
	}

	return {}, false
}
