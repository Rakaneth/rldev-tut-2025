package main

import rl "vendor:raylib"

@(private = "file")
_cur_id: ObjId = 1

BP_Base :: struct {
	name:  string,
	desc:  string,
	tile:  Atlas_Tile,
	color: rl.Color,
}

BP_Mobile :: struct {
	hp:         int,
	using base: BP_Base,
}

BP_Consumable :: struct {
	uses:       int,
	using base: BP_Base,
}

Mobile_ID :: enum {
	Hero,
	Bat,
}

Consumable_ID :: enum {
	Potion_Healing,
	Scroll_Lightning,
}

@(rodata)
MOBILES := [Mobile_ID]BP_Mobile {
	.Hero = {name = "Hero", desc = "The Hero!", tile = .Hero, color = rl.WHITE, hp = 30},
	.Bat = {name = "Bat", desc = "A squeaky Bat", tile = .Bat, color = rl.WHITE, hp = 10},
}

@(rodata)
CONSUMABLES := [Consumable_ID]BP_Consumable {
	.Potion_Healing = {
		name = "Potion of Healing",
		desc = "A potion of healing. Smells like fresh blood.",
		tile = .Potion,
		color = rl.RED,
		uses = 3,
	},
	.Scroll_Lightning = {
		name = "Scroll of Lightning",
		desc = "A mystical scroll with a lightning spell inscribed on it",
		tile = .Scroll,
		color = rl.YELLOW,
		uses = 1,
	},
}

factory_make_mobile :: proc(mob_id: Mobile_ID, is_player := false) -> Entity {
	template := MOBILES[mob_id]
	id: ObjId
	z: int

	if is_player {
		id = 0
		z = 3
	} else {
		id = _cur_id
		_cur_id += 1
		z = 2
	}

	e := entity_create(
		id,
		template.name,
		template.desc,
		template.tile,
		Mobile{energy = 100, cur_hp = template.hp, max_hp = template.hp},
		template.color,
		z,
	)

	return e
}

factory_make_consumable :: proc(cons_id: Consumable_ID) -> Entity {
	template := CONSUMABLES[cons_id]

	e := entity_create(
		_cur_id,
		template.name,
		template.desc,
		template.tile,
		Consumable{uses = template.uses},
		template.color,
	)

	_cur_id += 1
	return e
}
