package main

import "core:container/queue"
import "core:fmt"
import "core:math/rand"

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

/* Map Creation */
arena :: proc(width, height: int) -> TerrainData {
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
					between := cur + Direction_Offsets[next_dir]
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
