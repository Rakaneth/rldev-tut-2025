package main

rolld20 :: proc() -> int {
	return rand_next_int(1, 20)
}

stat_check :: proc(mob: Mobile, stat: Stat) -> (int, bool) {
	r := rolld20()
	return r, mob.stats[stat] >= r
}
