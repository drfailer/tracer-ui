package tracer_ui

import "core:strings"
import "core:strconv"
import "core:bufio"
import "core:os"
import "core:mem"
import "core:fmt"
import "core:log"
import "core:slice"

Timestamp :: u64

TracerData :: struct {
    timelines: map[string][dynamic]Trace,
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
    return
}

tracer_data_destroy :: proc(td: ^TracerData) {
    mem.dynamic_arena_destroy(&td.arena)
    delete(td.timelines)
    free(td)
}

tracer_parse_line :: proc(line: string, allocator: mem.Allocator) -> (trace: Trace, timelines: []string, ok: bool) {
    line_parts := strings.split(line, ";")
    defer delete(line_parts)

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
    trace.group = strings.clone(line_parts[2], allocator)
    timelines = strings.split(line_parts[3], ",")

    return trace, timelines, true
}

tracer_parse_file :: proc(filepath: string) -> (td: ^TracerData) {
	file, ferr := os.open(filepath)
	if ferr != 0 {
        log.error("cannot open file.")
		return
	}
	defer os.close(file)

    td = tracer_data_create()
    td.timelines = make(map[string][dynamic]Trace)
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

        trace, timelines, ok := tracer_parse_line(strings.trim(line, "\n"), td.allocator)
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
