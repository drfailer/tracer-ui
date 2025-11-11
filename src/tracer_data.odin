package tracer_ui

import "core:strings"
import "core:strconv"
import "core:bufio"
import "core:os"
import "core:mem"
import "core:fmt"
import "core:log"
import "core:slice"
import sgui "deps:sgui"

Timestamp :: u64

GroupConfig :: struct {
    color: sgui.Color,
}

TracerData :: struct {
    timelines: map[string][dynamic]Trace,
    groups: map[string]GroupConfig,
    ttl_time: u64,
    arena: mem.Dynamic_Arena,
    allocator: mem.Allocator,
}

Trace :: struct {
    begin, end: Timestamp,
    group: string,
}

tracer_data_create :: proc() -> (td: ^TracerData) {
    td = new(TracerData)
    mem.dynamic_arena_init(&td.arena)
    td.allocator = mem.dynamic_arena_allocator(&td.arena)
    td.timelines = make(map[string][dynamic]Trace)
    td.groups = make(map[string]GroupConfig)
    return
}

tracer_data_destroy :: proc(td: ^TracerData) {
    mem.dynamic_arena_destroy(&td.arena)
    delete(td.timelines)
    delete(td.groups)
    free(td)
}

parse_color :: proc(color_str: string) -> (color: sgui.Color, ok: bool) {
    color.r = cast(u8)strconv.parse_uint(color_str[1:3], 16) or_return
    color.g = cast(u8)strconv.parse_uint(color_str[3:5], 16) or_return
    color.b = cast(u8)strconv.parse_uint(color_str[5:7], 16) or_return
    a, aok := strconv.parse_uint(color_str[7:], 16)
    color.a = cast(u8)a if aok else 255
    return color, true
}

tracer_parse_line :: proc(
    line: string,
    allocator: mem.Allocator
) -> (trace: Trace, timelines: []string, group_config: GroupConfig, ok: bool) {
    line_parts := strings.split(line, ";")
    defer delete(line_parts)

    group_config.color = sgui.Color{200, 200, 255, 255}

    if len(line_parts) != 4 {
        log.error("syntax error.")
        return
    }

    switch line_parts[0] {
    case "ev":
        trace.begin = strconv.parse_u64(line_parts[1]) or_return
        trace.end = trace.begin
    case "dur":
        dur_parts := strings.split(line_parts[1], ",")
        defer delete(dur_parts)
        trace.begin = strconv.parse_u64(dur_parts[0]) or_return
        trace.end = strconv.parse_u64(dur_parts[1]) or_return
    }
    color_idx := strings.index(line_parts[2], "#")
    if color_idx > 0 {
        color_str := strings.substring_from(line_parts[2], color_idx) or_return
        group_str := strings.substring_to(line_parts[2], color_idx) or_return
        group_config.color = parse_color(color_str) or_return
        trace.group = strings.clone(group_str, allocator)
    } else {
        trace.group = strings.clone(line_parts[2], allocator)
    }
    timelines = strings.split(line_parts[3], ",")

    return trace, timelines, group_config, true
}

tracer_parse_file :: proc(filepath: string) -> (td: ^TracerData) {
	file, ferr := os.open(filepath)
	if ferr != 0 {
        log.error("cannot open file.")
		return
	}
	defer os.close(file)

    td = tracer_data_create()
    min_timestamp, max_timestamp : Timestamp = 0, 0

	reader: bufio.Reader
	buffer: [1024]byte
    stream := os.stream_from_handle(file)
	bufio.reader_init_with_buf(&reader, stream, buffer[:])
	defer bufio.reader_destroy(&reader)

    for line_idx := 0;; line_idx += 1 {
		line, err := bufio.reader_read_string(&reader, '\n')
		if err != nil {
			break
		}
		defer delete(line)

        trace, timelines, group_config, ok := tracer_parse_line(strings.trim(line, "\n"), td.allocator)
        defer delete(timelines)
        if !ok {
            log.error("cannot parse line ", line_idx)
        }

        min_timestamp = min(min_timestamp, trace.begin)
        max_timestamp = max(max_timestamp, trace.end)

        for timeline in timelines {
            if timeline not_in td.timelines {
                td.timelines[strings.clone(timeline, td.allocator)] = make([dynamic]Trace, td.allocator)
            }
            if trace.group not_in td.groups {
                td.groups[trace.group] = group_config
            }
            append(&td.timelines[timeline], trace)
        }
    }

    for _, traces in td.timelines {
        slice.sort_by(traces[:], proc(a, b: Trace) -> bool {
            return a.begin < b.begin
        })
    }
    td.ttl_time = max_timestamp - min_timestamp
    return td
}

timestamp_to_string :: proc(t: Timestamp) -> string {
    if t > 1_000_000_000 {
        return fmt.aprintf("%.3f s", cast(f32)t / 1_000_000_000)
    } else if t > 1_000_000 {
        return fmt.aprintf("%.3f ms", cast(f32)t / 1_000_000)
    } else if t > 1_000 {
        return fmt.aprintf("%.3f us", cast(f32)t / 1_000)
    }
    return fmt.aprintf("{} ns", t)
}

trace_to_string :: proc(trace: Trace) -> string {
    dur := trace.end - trace.begin
    if dur == 0 {
        bt_str := timestamp_to_string(trace.begin)
        defer delete(bt_str)
        return fmt.aprintf("Event:\n- time point: {}\n- group: {}", bt_str, trace.group)
    }
    bt_str := timestamp_to_string(trace.begin)
    defer delete(bt_str)
    et_str := timestamp_to_string(trace.end)
    defer delete(et_str)
    dur_str := timestamp_to_string(dur)
    defer delete(dur_str)
    return fmt.aprintf("Duration:\n- begin: {}\n- end: {}\n- dur: {}\n- group: {}",
                       bt_str, et_str, dur_str, trace.group)
}
