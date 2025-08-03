package test

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:math"
import "core:sys/windows"
import "core:time"
import "core:unicode"
import p_str "python_string_functions"
import p_list "python_list_functions"
import p_int "python_int_functions"
import p_float "python_float_functions"
import p_heap "python_heap_functions"
print :: fmt.println
printf :: fmt.printf

DEBUG_MODE :: true

main :: proc() {

    when DEBUG_MODE {
        // tracking allocator
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf(
                    "=== %v allocations not freed: context.allocator ===\n",
                    len(track.allocation_map),
                )
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf(
                    "=== %v incorrect frees: context.allocator ===\n",
                    len(track.bad_free_array),
                )
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }

        // tracking temp_allocator
        track_temp: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track_temp, context.temp_allocator)
        context.temp_allocator = mem.tracking_allocator(&track_temp)

        defer {
            if len(track_temp.allocation_map) > 0 {
                fmt.eprintf(
                    "=== %v allocations not freed: context.temp_allocator ===\n",
                    len(track_temp.allocation_map),
                )
                for _, entry in track_temp.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track_temp.bad_free_array) > 0 {
                fmt.eprintf(
                    "=== %v incorrect frees: context.temp_allocator ===\n",
                    len(track_temp.bad_free_array),
                )
                for entry in track_temp.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track_temp)
        }
    }

    // main work
    print("Hello from Odin!")
    windows.SetConsoleOutputCP(windows.CODEPAGE.UTF8)
    start: time.Time = time.now()

    // code goes here
    print(max_num_of_string_pairs_00([]string{"cd","ac","dc","ca","zz"}))

    // ---------------------------------------------------------------------------------------------------------
    iterations := 1_000
    total_time := time.Duration(0)
    
    for _ in 0 ..< iterations {
        start := time.now()
        // code to test goes here
        max_num_of_string_pairs_00([]string{"cd","ac","dc","ca","zz"})
        total_time += time.since(start)
    }
    print("Average time:", int(total_time) / iterations, "ns")
    // ---------------------------------------------------------------------------------------------------------
    // ---------------------------------------------------------------------------------------------------------

    elapsed: time.Duration = time.since(start)
    print("Odin took:", elapsed)


}

// def maximumNumberOfStringPairs(self, words: List[str]) -> int:
// words = ["cd","ac","dc","ca","zz"] --> 2
// words = ["ab","ba","cc"] --> 1
// words = ["aa","ab"] --> 0


// Average Time in Debug Build:      370 ns
// Average Time in Optimized Build:  180 ns
max_num_of_string_pairs_00 :: proc(l: []string) -> int {
    exists := [6426]u16{}  // 6425 max value of "zz" as u16
    used   := [6426]bool{}
    count  := 0

    for s in l {
        val := u16(s[0] - 'a') << 8 | u16(s[1] - 'a')
        exists[val] += 1
    }

    for s in l {
        val := u16(s[0] - 'a') << 8 | u16(s[1] - 'a')
        rev := u16(s[1] - 'a') << 8 | u16(s[0] - 'a')

        if val == rev {
            // Only count if there are at least 2 and not used yet
            if exists[val] >= 2 && !used[val] {
                used[val] = true
                count += 1
            }
        } else if exists[rev] > 0 && !used[val] && !used[rev] {
            used[val] = true
            used[rev] = true
            count += 1
        }
    }

    return count
}


max_num_of_string_pairs_01 :: proc(l: []string) -> int {
    seen := make(map[u16]bool)
    defer delete(seen)

    count := 0

    for s in l {
        val := u16(s[0] - 'a') << 8 | u16(s[1] - 'a')
        rev := u16(s[1] - 'a') << 8 | u16(s[0] - 'a')

        if rev in seen && !seen[rev] {
            seen[rev] = true
            seen[val] = true
            count += 1
        } else if !(val in seen) {
            seen[val] = false
        }
    }

    return count
}

import "core:simd"

encode :: proc(s: string) -> u16 {
    return u16(s[0] - 'a') << 8 | u16(s[1] - 'a')
}

reverse :: proc(val: u16) -> u16 {
    return (val & 0x00FF) << 8 | (val & 0xFF00) >> 8
}

max_num_of_string_pairs_simd :: proc(l: []string) -> int {
    encoded := make([]u16, len(l))
    for i in 0 ..< len(l) {
        encoded[i] = encode(l[i])
    }

    used := [6426]bool{}
    count := 0

    for i in 0 ..< len(encoded) {
        val := encoded[i]
        rev := reverse(val)

        if used[val] || used[rev] || val == rev {
            continue
        }

        // Create a SIMD vector with 16 lanes filled with rev
        rev_vec := simd.from_array([16]u16{rev, rev, rev, rev, rev, rev, rev, rev,
                                           rev, rev, rev, rev, rev, rev, rev, rev})

        j := 0
        for (j < len(encoded)) {
            // Load up to 16 values from encoded
            // chunk := simd.from_slice(encoded[j:min(j + 16, len(encoded))])
            chunk := simd.from_slice(#simd[16]u16, encoded[j:min(j + 16, len(encoded))])

            mask := simd.lanes_eq(chunk, rev_vec) // simd[16]u16
            bool_mask := simd.to_array(mask)      // [16]u16

            // Convert to [16]bool
            bool_array: [16]bool
            for i in 0 ..< 16 {
                bool_array[i] = bool_mask[i] != 0
            }

            // Convert to simd[16]bool
            bool_simd := simd.from_array(bool_array)

            // Now use reduce_any
            if simd.reduce_any(bool_simd) {
                used[val] = true
                used[rev] = true
                count += 1
                break
            }


            j += 16
        }
    }

    return count
}





