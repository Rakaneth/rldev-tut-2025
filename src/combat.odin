package main

import "core:log"
import "core:slice"

/* Game System */

system_roll_dice :: proc(sides: int, num := 1) -> int {
	acc := 0
	for _ in 0 ..< num {
		acc += rand_next_int(1, sides)
	}
	return acc
}

system_rolld20 :: proc() -> int {
	return system_roll_dice(20)
}

@(private = "file")
sum_lambda :: proc(a, b: int) -> int {
	return a + b
}

system_roll_fallen_hero_stats :: proc(out: []int) {
	assert(len(out) >= 4)
	for i in 0 ..< 4 {
		rolls: [4]int
		for &r in rolls {
			r = rand_next_int(1, 6)
		}
		slice.sort(rolls[:])
		when ODIN_DEBUG {
			log.infof("DICE: rolling fallen hero stat %v: %v", i, rolls)
		}
		out[i] = slice_reduce(rolls[1:], sum_lambda)
	}
	when ODIN_DEBUG {
		log.infof("DICE: fallen hero stats: %v", out)
	}
}

system_stat_test :: proc(mob: Mobile, stat: Stat) -> (int, bool) {
	r := system_rolld20()
	return r, mob.stats[stat] >= r
}

system_is_slain :: proc(mob: Mobile) -> bool {
	return mob.cur_hp <= 0
}

system_is_exhausted :: proc(mob: Mobile) -> bool {
	return mob.stamina <= mob.fatigue
}

//Sets global: _damage
system_mob_take_damage :: proc(e_mob: EntityInstMut(Mobile), dmg: int) {
	e_mob.damage = dmg
	e_mob.cur_hp -= dmg
	when ODIN_DEBUG {
		log.infof("[SYSTEM] %v takes %v damage", e_mob.name, dmg)
	}
	_damage = true
}

//Returns the real amount healed for messaging/debugging
system_mob_heal :: proc(e_mob: EntityInstMut(Mobile), amt: int) -> int {
	old_hp := e_mob.cur_hp
	e_mob.cur_hp = min(e_mob.max_hp, e_mob.cur_hp + amt)
	real_healed := e_mob.cur_hp - old_hp
	when ODIN_DEBUG {
		log.infof("[SYSTEM] %v healed for %v (real %v)", e_mob.name, amt, real_healed)
	}
	return real_healed

}

system_basic_attack :: proc(attacker, defender: EntityInstMut(Mobile)) {
	att_stam_cost := 1
	/*
		Homage to Dragonbane: 
		nat 1s are called "dragons"
		nat 20s are called "demons"
	*/
	if att_roll, hit := system_stat_test(attacker.type^, attacker.atk_stat); hit {
		dragon := att_roll == 1
		raw_dmg := rand_next_int(attacker.base_atk.x, attacker.base_atk.y)
		str_bonus := attacker.atk_stat == .ST ? max(0, attacker.stats[.ST] - 16) : 0
		dmg := raw_dmg + str_bonus

		when ODIN_DEBUG {
			log.infof(
				"[SYSTEM] %v hits %v with a roll of %v (test %v of %v); %v base damage",
				attacker.name,
				defender.name,
				att_roll,
				attacker.atk_stat,
				attacker.stats[attacker.atk_stat],
				dmg,
			)
		}

		if dragon {
			att_stam_cost = 0

			when ODIN_DEBUG {
				log.infof(
					"[SYSTEM] %v rolls a DRAGON on attack! No stam cost, no dodging",
					attacker.name,
				)
			}
			system_mob_take_damage(defender, dmg)
			return
		}

		if def_roll, dodge := system_stat_test(defender.type^, .AG); dodge {
			defender.fatigue += dmg
			when ODIN_DEBUG {
				log.infof("COMBAT: %v dodges, gaining %v fatigue", defender.name, dmg)
			}
		} else {
			when ODIN_DEBUG {
				log.infof("COMBAT: %v fails to dodge", defender.name)
			}
			system_mob_take_damage(defender, dmg)
		}
	} else {
		demon := att_roll == 20
		if demon {
			att_stam_cost = 3
			when ODIN_DEBUG {
				log.infof("COMBAT: %v rolls a DEMON on attack! Increased fatigue!", attacker.name)
			}
		}
		when ODIN_DEBUG {
			log.infof(
				"COMBAT: %v misses the attack with a roll of %v (test %v of %v)",
				attacker.name,
				att_roll,
				attacker.atk_stat,
				attacker.stats[attacker.atk_stat],
			)
		}
	}

	attacker.fatigue += att_stam_cost
}

system_update_vitals :: proc(gainer: EntityInstMut(Mobile)) {
	gainer.max_hp = gainer.base_hp + gainer.stats[.HD] * 2
	gainer.stamina = gainer.stats[.HD] + gainer.stats[.WL]
}
