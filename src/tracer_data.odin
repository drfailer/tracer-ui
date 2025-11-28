package tracer_ui

import "core:strings"
import "core:strconv"
import "core:bufio"
import "core:os"
import "core:mem"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:slice"
import sgui "deps:sgui"

Timestamp :: u64

GroupInfo :: struct {
    color: sgui.Color,
    ttl_dur: u64,
    event_count: int,
    dur_count: int,
}

TimelineInfo :: struct {
    // TODO
}

TracerData :: struct {
    dus: map[string][dynamic]Du,
    evs: map[string][dynamic]Ev,
    groups_infos: map[string]GroupInfo,
    timelines_infos: map[string]TimelineInfo,
    tstart, tend: Timestamp,
    ttl_time: u64,
    arena: mem.Dynamic_Arena,
    allocator: mem.Allocator,
}

Du :: struct {
    begin, end: Timestamp,
    group: string,
    infos: string,
}

Ev :: struct {
    tp: Timestamp,
    group: string,
    infos: string,
}

Trace :: union { ^Du, ^Ev }

tracer_data_create :: proc() -> (td: ^TracerData) {
    td = new(TracerData)
    mem.dynamic_arena_init(&td.arena)
    td.allocator = mem.dynamic_arena_allocator(&td.arena)
    td.evs = make(map[string][dynamic]Ev)
    td.dus = make(map[string][dynamic]Du)
    td.groups_infos = make(map[string]GroupInfo)
    td.timelines_infos = make(map[string]TimelineInfo)
    return
}

tracer_data_destroy :: proc(td: ^TracerData) {
    mem.dynamic_arena_destroy(&td.arena)
    delete(td.evs)
    delete(td.dus)
    delete(td.groups_infos)
    delete(td.timelines_infos)
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

parse_group :: proc(group_str: string, allocator: mem.Allocator) -> (name: string, color: sgui.Color, ok: bool) {
    parts := strings.split(group_str, ",")
    defer delete(parts)

    color = sgui.Color{200, 200, 255, 255}

    name = strings.clone(parts[0], allocator)
    if len(parts) == 1 {
        return name, color, true
    }
    if color, ok = parse_color(parts[1]); !ok {
        log.error("cannot parse color", parts[1])
        return
    }
    return name, color, true
}

index_from :: proc(str: string, idx: int, c: u8) -> (res: int) {
    for res = idx; res < len(str); res += 1 {
        if str[res] == c {
            return res
        }
    }
    return res
}

tracer_parse_type :: proc($type: typeid, data: []byte) -> (res: u64, rest: []byte, ok: bool) {
    if len(data) < size_of(type) {
        log.error("cannot parse type", type_info_of(type), "(string too small)")
        return
    }
    res = (cast(^u64)raw_data(data[0:size_of(type)]))^
    return res, data[size_of(type):], true
}

tracer_parse_string :: proc(data: []byte) -> (res: string, rest: []byte, ok: bool) {
    strsize: u64
    strsize, rest = tracer_parse_type(u64, data) or_return
    if  len(rest) < int(strsize) {
        log.error("cannot parse string of size", strsize, "(data of size", len(rest), ")")
        return
    }
    res = string(rest[0:strsize])
    return res, rest[strsize:], true
}

// [EV::][<tp:8>        ][<group:8+size>][<timeline:8+size>][<infos:8+size>]
// [DU::][<tp1:8><tp2:8>][<group:8+size>][<timeline:8+size>][<infos:8+size>]
// TEST: force 32 bit compare over starting symbol
// NOTE: the symbol is required for future parallel parsing
// EV_TYPE :: (cast(^u32)raw_data("EV::"))^
// DU_TYPE :: (cast(^u32)raw_data("DU::"))^

add_group :: proc(group_name: string, color: sgui.Color, td: ^TracerData) {
    if group_name not_in td.groups_infos {
        td.groups_infos[group_name] = GroupInfo{
            color = color,
        }
    }
}

add_timeline :: proc(timeline_name: string, td: ^TracerData) {
    if timeline_name not_in td.timelines_infos {
        // the map does not copy the key
        name_cpy := strings.clone(timeline_name, td.allocator)
        td.timelines_infos[name_cpy] = TimelineInfo{}
    }
}


tracer_parse_trace :: proc(data: []byte, td: ^TracerData) -> (rest: []byte, ok: bool) {
    group_str, timeline_str, infos_str: string
    group_color: sgui.Color

    // type, rest = tracer_parse_type(u32, data)
    rest = data[4:]
    switch string(data[:4]) {
    case "EV::":
        ev: Ev

        ev.tp, rest, ok = tracer_parse_type(Timestamp, rest) //or_return
        assert(ok)
        group_str, rest, ok = tracer_parse_string(rest) //or_return
        assert(ok)
        timeline_str, rest, ok = tracer_parse_string(rest) //or_return
        assert(ok)
        infos_str, rest, ok = tracer_parse_string(rest) //or_return
        assert(ok)

        err: runtime.Allocator_Error
        ev.infos, err = strings.clone(infos_str, td.allocator)
        assert(err == nil)

        ev.group, group_color, ok = parse_group(group_str, td.allocator) //or_return
        assert(ok)
        add_group(ev.group, group_color, td)
        gi, gi_ok := &td.groups_infos[ev.group]
        assert(gi_ok)
        gi.event_count += 1

        add_timeline(timeline_str, td)
        if timeline_str not_in td.evs {
            td.evs[timeline_str] = make([dynamic]Ev, td.allocator)
        }
        append(&td.evs[timeline_str], ev)
        td.tend = ev.tp
    case "DU::":
        du: Du

        du.begin, rest, ok = tracer_parse_type(Timestamp, rest) //or_return
        assert(ok)
        du.end, rest, ok = tracer_parse_type(Timestamp, rest) //or_return
        assert(ok)
        group_str, rest, ok = tracer_parse_string(rest) //or_return
        assert(ok)
        timeline_str, rest, ok = tracer_parse_string(rest) //or_return
        assert(ok)
        infos_str, rest, ok = tracer_parse_string(rest) //or_return
        assert(ok)

        err: runtime.Allocator_Error
        du.infos, err = strings.clone(infos_str, td.allocator)
        assert(err == nil)

        du.group, group_color, ok = parse_group(group_str, td.allocator) //or_return
        assert(ok)
        add_group(du.group, group_color, td)
        gi, gi_ok := &td.groups_infos[du.group]
        assert(gi_ok)
        gi.dur_count += 1
        gi.ttl_dur += du.end - du.begin

        add_timeline(timeline_str, td)
        if timeline_str not_in td.dus {
            td.dus[timeline_str] = make([dynamic]Du, td.allocator)
        }
        append(&td.dus[timeline_str], du)
        td.tend = du.end
    }
    return rest, true
}

tracer_parse_file :: proc(filepath: string) -> (td: ^TracerData, ok: bool) {
    data: []byte
    data, ok = os.read_entire_file(filepath)
	if !ok {
        log.error("cannot read entire file")
		return
	}
	defer delete(data)

    td = tracer_data_create()

    rest := data[:]
    for len(rest) > 0 {
        rest = tracer_parse_trace(rest, td) or_return
    }
    td.ttl_time = td.tend - td.tstart
    return td, true
}

group_info_to_string :: proc(group: string, group_info: GroupInfo) -> string {
    if group_info.event_count > 0 {
        return fmt.aprintf("{}:\n  - event count: {}", group, group_info.event_count)
    }
    ttl_dur_str := time_to_string(group_info.ttl_dur)
    defer delete(ttl_dur_str)
    avg_dur := cast(f32)group_info.ttl_dur / cast(f32)group_info.dur_count
    avg_dur_str := time_to_string(cast(Timestamp)avg_dur)
    defer delete(avg_dur_str)
    return fmt.aprintf("{}:\n  - dur count: {}\n  - ttl time: {}\n  - avg dur: {}",
        group, group_info.dur_count, ttl_dur_str, avg_dur_str)
}

time_to_string :: proc(t: $T) -> string {
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
    switch t in trace {
    case ^Ev:
        bt_str := time_to_string(t.tp)
        defer delete(bt_str)
        return fmt.aprintf("Event:\n- time point: {}\n- group: {}\n- infos:\n  - {}",
                           bt_str, t.group, t.infos)
    case ^Du:
        dur := t.end - t.begin
        bt_str := time_to_string(t.begin)
        defer delete(bt_str)
        et_str := time_to_string(t.end)
        defer delete(et_str)
        dur_str := time_to_string(dur)
        defer delete(dur_str)
        return fmt.aprintf("Duration:\n- begin: {}\n- end: {}\n- dur: {}\n- group: {}\n- infos:\n  - {}",
            bt_str, et_str, dur_str, t.group, t.infos)
    }
    return ""
}
