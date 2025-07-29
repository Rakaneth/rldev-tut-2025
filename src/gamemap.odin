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

Terrain :: enum {
	NullTile,
	WallUpperLeft,
	WallUpperRight,
	WallLowerLeft,
	WallLowerRight,
	WallHorz,
	WallVertLeft,
	WallVertRight,
	WallTLeft,
	WallTRight,
	Floor,
	DoorClosed,
	DoorOpen,
	StairsDown,
}

WALL_SET: bit_set[Terrain] : {
	.WallUpperLeft,
	.WallUpperRight,
	.WallHorz,
	.WallLowerLeft,
	.WallLowerRight,
	.WallVertLeft,
	.WallVertRight,
	.WallTLeft,
	.WallTRight,
}


/* map-specific functions */
TerrainData :: Grid(Terrain)
WallFloor :: Grid(bool)

wf_debug_print :: proc(m: WallFloor) {
	for y in 0 ..< m.height {
		for x in 0 ..< m.width {
			to_print := grid_get(m, {x, y}) ? "." : "#"
			fmt.print(to_print)
		}
		fmt.println("")
	}
}

map_is_wall :: proc(m: TerrainData, pos: Point) -> bool {
	return grid_get(m, pos) in WALL_SET
}

map_carve_rect :: proc(m: ^TerrainData, r: Rect) {
	t: Terrain
	for y in r.y1 ..= r.y2 {
		for x in r.x1 ..= r.x2 {
			switch {
			case x == r.x1 && y == r.y1:
				t = .WallUpperLeft
			case x == r.x1 && y == r.y2:
				t = .WallLowerLeft
			case x == r.x2 && y == r.y1:
				t = .WallUpperRight
			case x == r.x2 && y == r.y2:
				t = .WallLowerRight
			case y == r.y1 || y == r.y2:
				t = .WallHorz
			case x == r.x1:
				t = .WallVertLeft
			case x == r.x2:
				t = .WallVertRight
			case:
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

/* Map Creation */
map_make_arena :: proc(width, height: int) -> TerrainData {
	m := grid_create(width, height, Terrain)
	to_set: Terrain
	x_edge := m.width - 1
	y_edge := m.height - 1
	for y in 0 ..< m.height {
		for x in 0 ..< m.width {
			switch {
			case x == 0 && y == 0:
				to_set = .WallUpperLeft
			case x == x_edge && y == 0:
				to_set = .WallUpperRight
			case x == 0 && y == y_edge:
				to_set = .WallLowerLeft
			case x == x_edge && y == y_edge:
				to_set = .WallLowerRight
			case x == 0:
				to_set = .WallVertLeft
			case x == x_edge:
				to_set = .WallVertRight
			case y == 0 || y == y_edge:
				to_set = .WallHorz
			case:
				to_set = .Floor
			}
			grid_set(&m, {x, y}, to_set)
		}
	}
	return m
}

wf_recursive :: proc(width, height: int, rand_factor: int = 0) -> WallFloor {
	assert(width & 1 == 1 && height & 1 == 1)
	q: queue.Queue(Point)
	queue.init(&q)
	defer queue.destroy(&q)
	m := grid_create(width, height, bool)
	cur: Point = {
		1 + 2 * (rand_next_int(1, width - 1) / 2),
		1 + 2 * (rand_next_int(1, height - 1) / 2),
	}
	grid_set(&m, cur, true)
	queue.push_back(&q, cur)
	next: Point
	blocked := false
	dirs: [4]Direction = {.Down, .Left, .Right, .Up}
	rand.shuffle(dirs[:])

	can_use :: proc(wf: WallFloor, pos: Point) -> bool {
		return grid_in_bounds(wf, pos) && !grid_get(wf, pos) && pos.x >= 1 && pos.y >= 1
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
					grid_set(&m, next, true)
					grid_set(&m, between, true)
					queue.push_back(&q, next)
					cur = next
					break
				}
			}
		}
	}

	return m
}

wf_post_process :: proc(wf: WallFloor) -> TerrainData {
	m := grid_create(wf.width, wf.height, Terrain)

	when ODIN_DEBUG {
		wf_debug_print(wf)
	}

	wall_score :: proc(w_f: WallFloor, pos: Point) -> int {
		result := 0
		up := point_by_dir(pos, .Up)
		right := point_by_dir(pos, .Right)
		down := point_by_dir(pos, .Down)
		left := point_by_dir(pos, .Left)

		if grid_in_bounds(w_f, up) && !grid_get(w_f, up) do result += 1
		if grid_in_bounds(w_f, right) && !grid_get(w_f, right) do result += 2
		if grid_in_bounds(w_f, down) && !grid_get(w_f, down) do result += 4
		if grid_in_bounds(w_f, left) && !grid_get(w_f, left) do result += 8

		return result
	}

	t: Terrain

	for y in 0 ..< wf.height {
		for x in 0 ..< wf.width {
			if grid_get(wf, {x, y}) {
				grid_set(&m, {x, y}, Terrain.Floor)
				continue
			}

			ws := wall_score(wf, {x, y})
			n: Terrain
			switch ws {
			case 0, 15:
				/* no T piece or full block in tileset */
				t = .NullTile
			case 1, 4, 5, 11:
				n = grid_get(m, {x, y - 1})
				if n == Terrain.WallUpperLeft ||
				   n == Terrain.WallVertLeft ||
				   n == Terrain.WallTLeft {
					t = .WallVertLeft
				} else if n == Terrain.WallUpperRight ||
				   n == Terrain.WallVertRight ||
				   n == Terrain.WallTRight {
					t = .WallVertRight
				}
			case 2, 8, 10:
				t = .WallHorz
			case 3:
				t = .WallLowerLeft
			case 6:
				t = .WallUpperLeft
			case 7:
				t = .WallTLeft
			case 9:
				t = .WallLowerRight
			case 12:
				t = .WallUpperRight
			case 13:
				t = .WallTRight
			case 14:
				t = .WallUpperRight /* maybe the hard corner? */
			}
			grid_set(&m, {x, y}, t)
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
