package main

import "core:mem"
import "core:strings"

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


//ALLOCATES a new cstring
clone_cstring :: proc(
	c_str: cstring,
	allocator := context.allocator,
	loc := #caller_location,
) -> cstring {
	return strings.clone_to_cstring(string(c_str), allocator, loc)
}

//ALLOCATES a new map
clone_map :: proc(
	m: map[$K]$V,
	allocator := context.allocator,
	loc := #caller_location,
) -> map[K]V {
	result := make(map[K]V, allocator = allocator, loc = loc)
	for k, v in m {
		result[k] = v
	}
	return result
}
