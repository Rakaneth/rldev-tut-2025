package main

import "core:strings"
import rl "vendor:raylib"

ObjId :: u32
PLAYER_ID :: 0

_entity_store: map[ObjId]Entity

Mobile :: struct {
	energy: int,
	cur_hp: int,
	max_hp: int,
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

	return nil, false
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
	if map_can_walk(_cur_map, new_pos) {
		e.pos = new_pos
	}
}
