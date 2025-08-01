package main

import "core:math"
import "core:strings"
import rl "vendor:raylib"

ObjId :: u32
PLAYER_ID :: 0

_entity_store: map[ObjId]Entity

Mobile :: struct {
	energy:  int,
	cur_hp:  int,
	max_hp:  int,
	visible: Grid(bool),
	vision:  int,
}

Consumable :: struct {
	uses: int,
}

EntityType :: union #no_nil {
	Mobile,
	Consumable,
}

Entity :: struct {
	id:    ObjId,
	name:  cstring,
	desc:  cstring,
	pos:   Point,
	tile:  Atlas_Tile,
	color: rl.Color,
	etype: EntityType,
	z:     int,
}

EntityInst :: struct($T: typeid) {
	using entity: Entity,
	using type:   T,
}

EntityInstMut :: struct($T: typeid) {
	using entity: ^Entity,
	using type:   ^T,
}

entity_create :: proc(
	id: ObjId,
	name, desc: string,
	tile: Atlas_Tile,
	etype: EntityType,
	color := rl.WHITE,
	z := 1,
	allocator := context.allocator,
	loc := #caller_location,
) -> Entity {
	e := Entity {
		id    = id,
		name  = strings.clone_to_cstring(name, allocator, loc),
		desc  = strings.clone_to_cstring(desc, allocator, loc),
		tile  = tile,
		etype = etype,
		color = color,
		z     = z,
	}
	return e
}

entity_destroy :: proc(e: ^Entity, allocator := context.allocator) {
	delete(e.name, allocator)
	delete(e.desc, allocator)
	#partial switch &variant in e.etype {
	case Mobile:
		grid_destroy(&variant.visible)
	}
}

entity_get :: proc(id: ObjId) -> Entity {
	return _entity_store[id]
}

entity_get_mut :: proc(id: ObjId) -> ^Entity {
	return &_entity_store[id]
}

entity_get_comp :: proc(id: ObjId, $Type: typeid) -> (EntityInst(Type), bool) #optional_ok {
	maybe_e := _entity_store[id]
	if comp, ok := maybe_e.etype.(Type); ok {
		return {maybe_e, comp}, true
	}

	return {}, false
}

entity_get_comp_mut :: proc(id: ObjId, $Type: typeid) -> (EntityInstMut(Type), bool) #optional_ok {
	maybe_e := &_entity_store[id]
	if comp, ok := &maybe_e.etype.(Type); ok {
		return {maybe_e, comp}, true
	}

	return {}, false
}

entity_add :: proc(e: Entity) {
	_entity_store[e.id] = e
}

entity_remove :: proc(e: ^Entity, allocator := context.allocator) {
	delete_key(&_entity_store, e.id)
	entity_destroy(e, allocator)
}

entity_move_by :: proc(e_id: ObjId, dir: Direction) {
	e := entity_get_mut(e_id)
	new_pos := point_by_dir(e.pos, dir)
	_, mob_ok := gamemap_get_mob_at(_cur_map, new_pos)
	if map_can_walk(_cur_map, new_pos) && !mob_ok {
		e.pos = new_pos
	} else if mob_ok {
		rl.PlaySound(_swing_sound)
	}
}

mobile_update_fov :: proc(e_id: ObjId) {
	mob := entity_get_comp_mut(e_id, Mobile)
	grid_fill(&mob.visible, false)

	for deg in 0 ..< 360 {
		fx: f32 = math.cos_f32(f32(deg) * math.RAD_PER_DEG)
		fy: f32 = math.sin_f32(f32(deg) * math.RAD_PER_DEG)
		ox := f32(mob.pos.x) + 0.5
		oy := f32(mob.pos.y) + 0.5
		for v in 0 ..< mob.vision {
			map_pos := Point{int(ox), int(oy)}
			grid_set(&mob.visible, map_pos, true)
			if e_id == PLAYER_ID do gamemap_explore(&_cur_map, map_pos)
			if map_is_wall(_cur_map, map_pos) do break
			ox += fx
			oy += fy
		}
	}
}

is_visible_to_player :: proc(pos: Point) -> bool {
	mob := entity_get_comp(PLAYER_ID, Mobile)
	return grid_get(mob.visible, pos)
}
