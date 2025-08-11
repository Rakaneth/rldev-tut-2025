package main

rolld20 :: proc() -> int {
	return rand_next_int(1, 20)
}

stat_test :: proc(mob: Mobile, stat: Stat) -> (int, bool) {
	r := rolld20()
	return r, mob.stats[stat] >= r
}

is_slain :: proc(mob: Mobile) -> bool {
	return mob.cur_hp < 0
}

is_exhausted :: proc(mob: Mobile) -> bool {
	return mob.stamina < mob.fatigue
}
