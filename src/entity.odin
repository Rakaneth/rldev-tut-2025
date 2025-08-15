package main

import "core:log"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

ObjId :: u32
PLAYER_ID :: 0

_entity_store: map[ObjId]Entity

Stat :: enum {
	ST,
	HD,
	AG,
	WL,
}

Attack :: distinct [2]int

Mobile :: struct {
	energy:   int,
	cur_hp:   int,
	max_hp:   int,
	visible:  Grid(bool),
	vision:   int,
	damage:   int,
	stats:    [Stat]int,
	stamina:  int,
	fatigue:  int,
	base_atk: Attack,
	atk_stat: Stat,
}

Consumable :: struct {
	uses:          int,
	consumable_id: Consumable_ID,
}

Inventory :: struct {
	capacity: int,
	items:    [dynamic]ObjId,
}

EntityType :: union #no_nil {
	Mobile,
	Consumable,
}

Entity :: struct {
	id:        ObjId,
	name:      cstring,
	desc:      cstring,
	pos:       Point,
	tile:      Atlas_Tile,
	color:     rl.Color,
	etype:     EntityType,
	z:         int,
	inventory: Inventory,
}

EntityInst :: struct($T: typeid) {
	using entity: Entity,
	using type:   T,
}

EntityInstMut :: struct($T: typeid) {
	using entity: ^Entity,
	using type:   ^T,
}

MoveResult :: enum {
	NoMove,
	Moved,
	Bump,
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
	delete(e.inventory.items)
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

entity_move_by :: proc(e_id: ObjId, dir: Direction) -> MoveResult {
	e := entity_get_mut(e_id)
	new_pos := point_by_dir(e.pos, dir)
	bumped, mob_ok := gamemap_get_mob_at(_cur_map, new_pos)
	if map_can_walk(_cur_map, new_pos) && !mob_ok {
		e.pos = new_pos
		return .Moved
	}

	if mob_ok {
		mob_bump(e_id, bumped.id)
		return .Bump
	}

	return .NoMove
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
			if map_is_wall_or_null(_cur_map, map_pos) do break
			ox += fx
			oy += fy
		}
	}
}

mob_bump :: proc(bumper_id: ObjId, bumped_id: ObjId) {
	if bumper_id == PLAYER_ID || bumped_id == PLAYER_ID {
		attacker := entity_get_comp_mut(bumper_id, Mobile)
		defender := entity_get_comp_mut(bumped_id, Mobile)
		basic_attack(attacker, defender)
	}
}

is_visible :: proc(looker_id: ObjId, subject_id: ObjId) -> bool {
	looker_mob := entity_get_comp(looker_id, Mobile)
	subj_pos := entity_get(looker_id).pos
	return grid_get(looker_mob.visible, subj_pos)
}

is_visible_to_player :: proc(pos: Point) -> bool {
	mob := entity_get_comp(PLAYER_ID, Mobile)
	return grid_get(mob.visible, pos)
}

entity_pick_up_item :: proc(grabber: ObjId, grabbed: ObjId) {
	grabber_entity := entity_get_mut(grabber)
	if grabber_entity.inventory.capacity > len(grabber_entity.inventory.items) {
		append(&grabber_entity.inventory.items, grabbed)
		gamemap_remove_entity(&_cur_map, grabbed)
	}
	when ODIN_DEBUG {
		grabbed_name := entity_get(grabbed).name
		log.infof("%v picks up %v at %v", grabber_entity.name, grabbed_name, grabber_entity.pos)
		log.infof("%v's inventory ids: %v", grabber_entity.name, grabber_entity.inventory.items)
	}
}

entity_drop_item :: proc(dropper: ObjId, dropped: ObjId) {
	dropper_entity := entity_get_mut(dropper)
	dropped_entity := entity_get_mut(dropped)

	if idx, idx_ok := slice_find(dropper_entity.inventory.items[:], dropped); idx_ok {
		unordered_remove(&dropper_entity.inventory.items, idx)
		dropped_entity.pos = dropper_entity.pos
		gamemap_add_entity(&_cur_map, dropped_entity^)
	}

	when ODIN_DEBUG {
		log.infof(
			"%v drops %v at %v",
			dropper_entity.name,
			dropped_entity.name,
			dropped_entity.pos,
		)
		log.infof("%v's inventory ids: %v", dropper_entity.name, dropper_entity.inventory.items)
	}
}

mobile_gain_stat :: proc(gainer: ObjId, stat: Stat, amt := 1) {
	if gainer_entity, ok := entity_get_comp_mut(gainer, Mobile); ok {
		gainer_entity.stats[stat] += amt
	}
}

mobile_use_consumable :: proc(user: ObjId, consumable: ObjId) {
	user_entity, user_ok := entity_get_comp_mut(user, Mobile)
	cons_entity, cons_ok := entity_get_comp_mut(consumable, Consumable)
	if user_ok && cons_ok {
		#partial switch cons_entity.consumable_id {
		case Consumable_ID.Potion_Healing:
			healing := roll_dice(6, 2)
			mob_heal(user_entity, healing)
		case Consumable_ID.Potion_ST:
			mobile_gain_stat(user, .ST)
		case Consumable_ID.Potion_HD:
			mobile_gain_stat(user, .HD)
		case Consumable_ID.Potion_AG:
			mobile_gain_stat(user, .AG)
		case Consumable_ID.Potion_WL:
			mobile_gain_stat(user, .WL)
		}
		cons_entity.uses -= 1
		if cons_entity.uses < 1 {
			entity_inv_remove_item(user, consumable)
		}
		when ODIN_DEBUG {
			log.infof("%v uses %v", user_entity.name, cons_entity.name)
		}
	}
}

entity_inv_remove_item :: proc(e_id: ObjId, item_id: ObjId) {
	entity := entity_get_mut(e_id)
	if idx, ok := slice_find(entity.inventory.items[:], item_id); ok {
		unordered_remove(&entity.inventory.items, idx)
		item := entity_get_mut(item_id)
		entity_remove(item)
	}
}
