package main

import "core:log"
import "core:math"
import "core:slice"
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

// Attack :: distinct [2]int

Attack :: struct {
	dmg:        [2]int,
	on_hit:     f32,
	on_hit_eff: union {
		Effect,
		Effect_Proc,
	},
}


Mobile :: struct {
	energy:    int,
	cur_hp:    int,
	max_hp:    int,
	visible:   Grid(bool),
	vision:    int,
	damage:    int,
	stats:     [Stat]int,
	stamina:   int,
	fatigue:   int,
	base_atk:  Attack,
	atk_stat:  Stat,
	base_hp:   int,
	mobile_id: Mobile_ID,
	effects:   [dynamic]Effect,
	gold:      int,
}

Consumable :: struct {
	uses:          int,
	consumable_id: Consumable_ID,
}

Weapon :: struct {
	atk_mod:  int,
	atk:      Attack,
	equipped: bool,
	atk_stat: Stat,
}

Gold :: struct {
	amt: int,
}

Inventory :: struct {
	capacity: int,
	items:    [dynamic]ObjId,
}

EntityType :: union #no_nil {
	Mobile,
	Consumable,
	Weapon,
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
		delete(variant.effects)
	}
}

entity_get :: proc(id: ObjId) -> Entity {
	return _entity_store[id]
}

entity_get_mut :: proc(id: ObjId) -> ^Entity {
	return &_entity_store[id]
}

entity_get_comp :: proc(id: ObjId, $Val: typeid) -> (EntityInst(Val), bool) #optional_ok {
	maybe_e := _entity_store[id]
	if comp, ok := maybe_e.etype.(Val); ok {
		return {maybe_e, comp}, true
	}

	return {}, false
}

entity_get_comp_mut :: proc(id: ObjId, $Val: typeid) -> (EntityInstMut(Val), bool) #optional_ok {
	maybe_e := &_entity_store[id]
	if comp, ok := &maybe_e.etype.(Val); ok {
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
	cur_map := get_cur_map()
	bumped, mob_ok := gamemap_get_mob_at(cur_map, new_pos)
	if map_can_walk(cur_map, new_pos) && !mob_ok {
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
	mob, mob_ok := entity_get_comp_mut(e_id, Mobile)
	if !mob_ok do return

	grid_fill(&mob.visible, false)
	cur_map := get_cur_map()
	p_cur_map := get_cur_map_mut()

	for deg in 0 ..< 360 {
		fx: f32 = math.cos_f32(f32(deg) * math.RAD_PER_DEG)
		fy: f32 = math.sin_f32(f32(deg) * math.RAD_PER_DEG)
		ox := f32(mob.pos.x) + 0.5
		oy := f32(mob.pos.y) + 0.5
		for v in 0 ..< mob.vision {
			map_pos := Point{int(ox), int(oy)}
			grid_set(&mob.visible, map_pos, true)
			if e_id == PLAYER_ID do gamemap_explore(p_cur_map, map_pos)
			if map_is_wall_or_null(cur_map, map_pos) do break
			ox += fx
			oy += fy
		}
	}
}

mob_bump :: proc(bumper_id: ObjId, bumped_id: ObjId) {
	if bumper_id == PLAYER_ID || bumped_id == PLAYER_ID {
		attacker := entity_get_comp_mut(bumper_id, Mobile)
		defender := entity_get_comp_mut(bumped_id, Mobile)
		attacker_visible := is_visible_to_player(bumper_id)
		defender_visible := is_visible_to_player(bumped_id)
		switch {
		case attacker_visible && defender_visible:
			add_msg("%s attacks %s!", attacker.name, defender.name)
		case attacker_visible:
			add_msg("%s attacks something!", attacker.name)
		case defender_visible:
			add_msg("Something attacks %s!", defender.name)
		}
		play_sound(.Swing)
		system_basic_attack(attacker, defender)
	}
}

is_visible :: proc(looker_id: ObjId, subject_id: ObjId) -> bool {
	looker_mob := entity_get_comp(looker_id, Mobile)
	subj_pos := entity_get(looker_id).pos
	return grid_get(looker_mob.visible, subj_pos)
}

is_visible_to_player_pos :: proc(pos: Point) -> bool {
	mob := entity_get_comp(PLAYER_ID, Mobile)
	return grid_get(mob.visible, pos)
}

is_visible_to_player_id :: proc(e_id: ObjId) -> bool {
	e := entity_get(e_id)
	if e_id not_in _entity_store do return false
	if _, found := slice_find(get_cur_map().entities[:], e_id); !found {
		return false
	}
	return is_visible_to_player_pos(e.pos)
}

is_visible_to_player :: proc {
	is_visible_to_player_pos,
	is_visible_to_player_id,
}


entity_pick_up_item :: proc(grabber: ObjId, grabbed: ObjId) {
	grabber_entity := entity_get_mut(grabber)
	grabbed_name := entity_get(grabbed).name
	if grabber_entity.inventory.capacity > len(grabber_entity.inventory.items) {
		append(&grabber_entity.inventory.items, grabbed)
		gamemap_remove_entity(get_cur_map_mut(), grabbed)
	}
	when ODIN_DEBUG {
		log.infof("%v picks up %v at %v", grabber_entity.name, grabbed_name, grabber_entity.pos)
		log.infof("%v's inventory ids: %v", grabber_entity.name, grabber_entity.inventory.items)
	}
	if is_visible_to_player(grabber) {
		add_msg("%s picks up %s", grabber_entity.name, grabbed_name)
	}
}

entity_drop_item :: proc(dropper: ObjId, dropped: ObjId) {
	dropper_entity := entity_get_mut(dropper)
	dropped_entity := entity_get_mut(dropped)

	if idx, idx_ok := slice_find(dropper_entity.inventory.items[:], dropped); idx_ok {
		unordered_remove(&dropper_entity.inventory.items, idx)
		dropped_entity.pos = dropper_entity.pos
		gamemap_add_entity(get_cur_map_mut(), dropped_entity^)
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
	if is_visible_to_player(dropper) {
		add_msg("%s drops %s", dropper_entity.name, dropper_entity.name)
	}
}

mobile_gain_stat :: proc(gainer: ObjId, stat: Stat, amt := 1) {
	if gainer_entity, ok := entity_get_comp_mut(gainer, Mobile); ok {
		gainer_entity.stats[stat] += amt
		if stat == .WL || stat == .HD {
			system_update_vitals(gainer_entity)
		}
	}
}

mobile_use_consumable :: proc(user: ObjId, consumable: ObjId) {
	user_entity, user_ok := entity_get_comp_mut(user, Mobile)
	cons_entity, cons_ok := entity_get_comp_mut(consumable, Consumable)
	if user_ok && cons_ok {
		#partial switch cons_entity.consumable_id {
		case Consumable_ID.Potion_Healing:
			healing := system_roll_dice(6, 2)
			if is_visible_to_player(user) {
				add_msg("%s quaffs a potion of healing", user_entity.name)
			}
			play_sound(.Drink)
			system_mob_heal(user_entity, healing)
		case Consumable_ID.Potion_ST:
			play_sound(.Drink)
			mobile_gain_stat(user, .ST)
			if user == PLAYER_ID {
				add_msg("You grow stronger.")
			}
		case Consumable_ID.Potion_HD:
			play_sound(.Drink)
			mobile_gain_stat(user, .HD)
			if user == PLAYER_ID {
				add_msg("You become hardier.")
			}
		case Consumable_ID.Potion_AG:
			play_sound(.Drink)
			mobile_gain_stat(user, .AG)
			if user == PLAYER_ID {
				add_msg("You become more agile.")
			}
		case Consumable_ID.Potion_WL:
			play_sound(.Drink)
			mobile_gain_stat(user, .WL)
			if user == PLAYER_ID {
				add_msg("You become more willful.")
			}
		case Consumable_ID.Scroll_Lightning:
			if user == PLAYER_ID && _target == nil {
				when ODIN_DEBUG {
					log.infof("No target selected for lightning bolt")
				}
				add_msg("No target.")
				return
			} else if user == PLAYER_ID {
				play_sound(.Magic)
				system_cast_lb(user_entity, entity_get_comp_mut(_target.?, Mobile))
			}
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

mobile_on_death :: proc(dead_id: ObjId) {
	dead_e := entity_get_mut(dead_id)
	add_msg("%s is slain!", dead_e.name)
	if dead_id != PLAYER_ID {
		gamemap_remove_entity(get_cur_map_mut(), dead_id)
		entity_remove(dead_e)
	}
}

/* Custom Entity Iterators */

EntityIterator :: struct {
	index: int,
	data:  []ObjId,
}

make_entity_iterator :: proc(data: []ObjId) -> EntityIterator {
	return {data = data}
}

entities_at_pos_comp :: proc(
	it: ^EntityIterator,
	pos: Point,
	$T: typeid,
) -> (
	val: EntityInst(T),
	idx: int,
	cond: bool,
) {
	cond = it.index < len(it.data)

	for ; cond; cond = it.index < len(it.data) {
		e, ok := entity_get_comp(it.data[it.index])
		if !ok || e.pos != pos {
			it.index += 1
			continue
		}

		val = e
		idx = it.index
		it.index += 1
		break
	}

	return
}

entities_at_pos :: proc(it: ^EntityIterator, pos: Point) -> (val: Entity, idx: int, cond: bool) {
	cond = it.index < len(it.data)

	for ; cond; cond = it.index < len(it.data) {
		e := entity_get(it.data[it.index])
		if e.pos != pos {
			it.index += 1
			continue
		}

		val = e
		idx = it.index
		it.index += 1
		break
	}

	return
}

weapons_in_inv :: proc(it: ^EntityIterator) -> (val: EntityInst(Weapon), idx: int, cond: bool) {
	for ; cond; cond = it.index < len(it.data) {
		weap, ok := entity_get_comp(it.data[it.index], Weapon)
		if !ok {
			it.index += 1
			continue
		}

		val = weap
		idx = it.index
		it.index += 1
		break
	}

	return
}

weapons_in_inv_mut :: proc(
	it: ^EntityIterator,
) -> (
	val: EntityInstMut(Weapon),
	idx: int,
	cond: bool,
) {
	for ; cond; cond = it.index < len(it.data) {
		weap, ok := entity_get_comp_mut(it.data[it.index], Weapon)
		if !ok {
			it.index += 1
			continue
		}

		val = weap
		idx = it.index
		it.index += 1
		break
	}

	return
}

//ALLOCATES fresh copies of entity's allocated items
entity_clone :: proc(
	e: Entity,
	allocator := context.allocator,
	loc := #caller_location,
) -> Entity {
	dpl: Entity
	dpl.name = clone_cstring(e.name)
	dpl.desc = clone_cstring(e.desc)
	dpl.color = e.color
	dpl.pos = e.pos
	dpl.id = e.id
	dpl.tile = e.tile
	dpl.z = e.z
	dpl.inventory = {
		capacity = e.inventory.capacity,
		items    = slice.clone_to_dynamic(e.inventory.items[:], allocator, loc),
	}
	if mob, mob_ok := e.etype.(Mobile); mob_ok {
		dpl.etype = Mobile {
			energy    = mob.energy,
			cur_hp    = mob.cur_hp,
			max_hp    = mob.max_hp,
			visible   = grid_create(mob.visible.width, mob.visible.height, bool, allocator, loc),
			vision    = mob.vision,
			damage    = mob.damage,
			stats     = mob.stats,
			stamina   = mob.stamina,
			fatigue   = mob.fatigue,
			base_atk  = mob.base_atk,
			atk_stat  = mob.atk_stat,
			base_hp   = mob.base_hp,
			mobile_id = mob.mobile_id,
		}
	} else {
		dpl.etype = e.etype
	}

	return dpl
}

mobile_tick_effects :: proc(e_id: ObjId) {
	if mob, mob_ok := entity_get_comp_mut(e_id, Mobile); mob_ok {
		for &eff, i in mob.effects {
			effect_tick(&eff, mob)
		}
	}
}

mobile_get_equipped_weapon :: proc(e_id: ObjId) -> (EntityInst(Weapon), bool) {
	if mob, ok := entity_get_comp(e_id, Mobile); ok {
		it := make_entity_iterator(mob.inventory.items[:])
		for weap in weapons_in_inv(&it) {
			if weap.equipped {
				return weap, true
			}
		}
	}

	return {}, false
}

mobile_get_equipped_weapon_mut :: proc(e_id: ObjId) -> (EntityInstMut(Weapon), bool) {
	if mob, ok := entity_get_comp(e_id, Mobile); ok {
		it := make_entity_iterator(mob.inventory.items[:])
		for weap in weapons_in_inv_mut(&it) {
			if weap.equipped {
				return weap, true
			}
		}
	}

	return {}, false
}

mobile_equip_weapon :: proc(e_id: ObjId, weap_id: ObjId) {
	mob, mob_ok := entity_get_comp_mut(e_id, Mobile)
	weap, weap_ok := entity_get_comp_mut(weap_id, Weapon)
	if mob_ok && weap_ok {
		if old_weap, old_weap_ok := mobile_get_equipped_weapon_mut(e_id); old_weap_ok {
			old_weap.equipped = false
			add_msg("%s unequips %s", mob.name, weap.name)
		}
		weap.equipped = true
		add_msg("%s equips %s", mob.name, weap.name)
	}
}
