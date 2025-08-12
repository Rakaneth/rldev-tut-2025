package main

slice_find :: proc(haystack: $T/[]$U, needle: U) -> (int, bool) #optional_ok {
	for thing, i in haystack {
		if thing == needle {
			return i, true
		}
	}
	return -1, false
}

slice_reduce :: proc(items: $T/[]$U, reducer: proc(u1, u2: U) -> U) -> U {
	result: U = items[0]
	for i in 1 ..< len(items) {
		result = reducer(result, items[i])
	}
	return result
}
