package main

import "core:log"
import rl "vendor:raylib"

@(private = "file")
_cur_id: ObjId = 1

BP_Base :: struct {
	name:      string,
	desc:      string,
	tile:      Atlas_Tile,
	color:     rl.Color,
	inventory: int,
}

BP_Mobile :: struct {
	hp:         int,
	using base: BP_Base,
	vision:     int,
	st:         [2]int,
	hd:         [2]int,
	ag:         [2]int,
	wl:         [2]int,
	base_atk:   Attack,
	atk_stat:   Stat,
}

BP_Consumable :: struct {
	uses:       int,
	using base: BP_Base,
}

BP_Weapon :: struct {
	atk_mod: int,
	atk:     Attack,
}

BP_Armor :: struct {
	doj_mod:    int,
	protection: int,
}

Mobile_ID :: enum {
	Hero,
	Aquator,
	Bat,
	Centaur,
	Dragon,
	Emu,
	Flytrap,
	Griffin,
	Hobgoblin,
	IceMonster,
	Jabberwock,
	Kestrel,
	Leprechaun,
	Medusa,
	Nymph,
	Orc,
	Phantom,
	Quagga,
	Rattlesnake,
	Snake,
	Troll,
	UmberHulk,
	Vampire,
	Wraith,
	Xeroc,
	Yeti,
	Zombie,
}

Consumable_ID :: enum {
	Potion_Healing,
	Scroll_Lightning,
	Potion_ST,
	Potion_HD,
	Potion_AG,
	Potion_WL,
}

Weapon_ID :: enum {
	Sword_Brittle,
	Sword_Iron,
	Sword_Steel,
	Sword_Mithril,
	Staff_Cammock,
	Staff_Oak,
	Staff_Ash,
	Staff_Thorn,
	Staff_Mage,
}

Armor_ID :: enum {
	Cloth,
	Leather,
	Chain,
	Lamellar,
	Breastplate,
}


@(rodata)
MOBILES := [Mobile_ID]BP_Mobile {
	.Hero = {
		name = "Hero",
		desc = "The Hero!",
		tile = .Hero,
		color = rl.WHITE,
		inventory = 8,
		hp = 10,
		vision = 6,
		st = {10, 10},
		ag = {10, 10},
		hd = {10, 10},
		wl = {10, 10},
		base_atk = {dmg = {1, 2}},
	},
	.Aquator = {},
	.Bat = {
		name = "Bat",
		desc = "A squeaky Bat",
		tile = .Bat,
		color = rl.WHITE,
		hp = 5,
		vision = 4,
		st = {5, 8},
		ag = {12, 15},
		hd = {8, 10},
		wl = {1, 1},
		base_atk = {dmg = {1, 2}},
		atk_stat = .AG,
	},
	.Centaur = {},
	.Dragon = {},
	.Emu = {
		name = "Emu",
		desc = "A tall, aggressive, flightless bird",
		tile = .Emu,
		color = rl.WHITE,
		hp = 8,
		vision = 8,
		st = {10, 15},
		hd = {10, 15},
		ag = {5, 10},
		wl = {2, 5},
		base_atk = {dmg = {1, 4}},
		atk_stat = .ST,
	},
	.Flytrap = {},
	.Griffin = {},
	.Hobgoblin = {
		name = "Hobgoblin",
		desc = "A hobgoblin, leader of the goblin tribes",
		tile = .Hobgoblin,
		color = rl.WHITE,
		hp = 10,
		vision = 7,
		st = {8, 13},
		hd = {8, 13},
		ag = {10, 15},
		wl = {5, 10},
		base_atk = {dmg = {1, 4}},
		atk_stat = .ST,
	},
	.IceMonster = {},
	.Jabberwock = {},
	.Kestrel = {
		name = "Kestrel",
		desc = "A beautiful bird trapped in the dungeon",
		tile = .Kestrel,
		color = rl.WHITE,
		hp = 5,
		vision = 8,
		st = {1, 5},
		ag = {12, 15},
		hd = {5, 8},
		wl = {1, 1},
		base_atk = {dmg = {1, 1}},
		atk_stat = .AG,
	},
	.Leprechaun = {},
	.Medusa = {},
	.Nymph = {},
	.Orc = {
		name = "Orc",
		desc = "A savage, green-skinned warrior",
		tile = .Orc,
		color = rl.WHITE,
		hp = 15,
		vision = 6,
		st = {12, 15},
		hd = {12, 15},
		ag = {8, 13},
		wl = {8, 13},
		base_atk = {dmg = {1, 6}},
		atk_stat = .ST,
	},
	.Phantom = {},
	.Quagga = {},
	.Rattlesnake = {
		name = "Rattlesnake",
		desc = "A large snake whose rattle warns of danger",
		tile = .Rattlesnake,
		color = rl.WHITE,
		hp = 10,
		vision = 6,
		st = {3, 8},
		hd = {5, 10},
		ag = {12, 17},
		wl = {2, 5},
		base_atk = {dmg = {1, 3}, on_hit = 0.3, on_hit_eff = {effect_id = .Poison, duration = 5}},
		atk_stat = .AG,
	},
	.Snake = {
		name = "Snake",
		desc = "A viper slithering among cracks in the stone",
		tile = .Snake,
		color = rl.WHITE,
		hp = 5,
		vision = 6,
		st = {2, 5},
		hd = {2, 5},
		ag = {10, 15},
		wl = {2, 5},
		base_atk = {dmg = {1, 2}, on_hit = .2, on_hit_eff = {effect_id = .Poison, duration = 3}},
		atk_stat = .AG,
	},
	.Troll = {},
	.UmberHulk = {},
	.Vampire = {},
	.Wraith = {
		name = "Wraith",
		desc = "A vengeful spirit of a lost adventurer",
		tile = .Wraith,
		color = rl.WHITE,
		hp = 10,
		vision = 7,
		st = {5, 10},
		hd = {8, 13},
		ag = {10, 15},
		wl = {13, 18},
		base_atk = {dmg = {1, 4}},
		atk_stat = .WL,
	},
	.Xeroc = {},
	.Yeti = {
		name = "Yeti",
		desc = "A titan of the cold north",
		tile = .Yeti,
		color = rl.WHITE,
		hp = 35,
		vision = 5,
		st = {15, 20},
		hd = {15, 20},
		ag = {5, 10},
		wl = {5, 10},
		base_atk = {dmg = {1, 8}},
		atk_stat = .ST,
	},
	.Zombie = {
		name = "Zombie",
		desc = "A fetid, shambling corpse that was once a man",
		tile = .Zombie,
		color = rl.WHITE,
		hp = 30,
		vision = 4,
		st = {12, 17},
		hd = {15, 20},
		ag = {3, 8},
		wl = {1, 5},
		base_atk = {dmg = {1, 2}},
		atk_stat = .ST,
	},
}

Tier0: bit_set[Mobile_ID] = {.Bat, .Kestrel, .Snake, .Emu}
Tier1: bit_set[Mobile_ID] = {.Hobgoblin, .Orc, .Rattlesnake, .Zombie}
Tier2: bit_set[Mobile_ID] = {.Troll, .Centaur, .Aquator, .Leprechaun, .Wraith, .Flytrap}
Tier3: bit_set[Mobile_ID] = {.Griffin, .IceMonster, .Nymph, .Phantom, .Quagga, .UmberHulk}
Tier4: bit_set[Mobile_ID] = {.Dragon, .Jabberwock, .Yeti, .Medusa, .Vampire, .Wraith}
StatPots: bit_set[Consumable_ID] = {.Potion_ST, .Potion_HD, .Potion_AG, .Potion_WL}
Consums: bit_set[Consumable_ID] = {.Potion_Healing, .Scroll_Lightning}


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
	.Potion_ST = {
		name = "Potion of Strength",
		desc = "A mysterious brew. Smells like a gymnasium.",
		tile = .Potion,
		color = rl.ORANGE,
		uses = 1,
	},
	.Potion_HD = {
		name = "Potion of Hardiness",
		desc = "A mysterious brew. Powdered crystals float in the mixture.",
		tile = .Potion,
		color = rl.DARKBROWN,
		uses = 1,
	},
	.Potion_AG = {
		name = "Potion of Agility",
		desc = "A mysterious brew. Smells like a fresh breeze.",
		tile = .Potion,
		color = rl.GREEN,
		uses = 1,
	},
	.Potion_WL = {
		name = "Potion of Will",
		desc = "A mysterious brew. Smells like a burning candle.",
		tile = .Potion,
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

	st := rand_next_int(template.st.x, template.st.y)
	ag := rand_next_int(template.ag.x, template.ag.y)
	hd := rand_next_int(template.hd.x, template.hd.y)
	wl := rand_next_int(template.wl.x, template.wl.y)

	if is_player {
		new_stats: [4]int
		system_roll_fallen_hero_stats(new_stats[:])
		st = new_stats[0]
		hd = new_stats[1]
		ag = new_stats[2]
		wl = new_stats[3]
	}
	hp := template.hp + hd * 2

	e := entity_create(
		id,
		template.name,
		template.desc,
		template.tile,
		Mobile {
			energy = 100,
			cur_hp = hp,
			max_hp = hp,
			vision = template.vision,
			stamina = hd + wl,
			stats = {.ST = st, .HD = hd, .AG = ag, .WL = wl},
			base_atk = template.base_atk,
			atk_stat = template.atk_stat,
			base_hp = template.hp,
			mobile_id = mob_id,
		},
		template.color,
		z,
	)

	e.inventory.capacity = template.inventory
	when ODIN_DEBUG {
		log.infof("%v", e)
	}

	return e
}

factory_make_consumable :: proc(cons_id: Consumable_ID) -> Entity {
	template := CONSUMABLES[cons_id]

	e := entity_create(
		_cur_id,
		template.name,
		template.desc,
		template.tile,
		Consumable{uses = template.uses, consumable_id = cons_id},
		template.color,
	)

	_cur_id += 1
	return e
}
