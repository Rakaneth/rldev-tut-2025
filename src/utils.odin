package main

slice_find :: proc(haystack: $T/[]$U, needle: U) -> (int, bool) #optional_ok {
	for thing, i in haystack {
		if thing == needle {
			return i, true
		}
	}
	return -1, false
}
