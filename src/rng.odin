package main

import "core:math/rand"

//range [low, high]
rand_next_int :: proc(low, high: int) -> int {
	low_val := min(low, high)
	high_val := max(low, high)
	val_range := high_val - low_val + 1
	return rand.int_max(val_range) + low_val
}

rand_next_bool :: proc() -> bool {
	return rand.int63() & 1 == 1
}

rand_next_float :: proc() -> f32 {
	return rand.float32()
}
