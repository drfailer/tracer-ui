package tracer_ui

import "core:fmt"
import "core:time"
import "deps:sgui"
import "core:math"
import su "deps:sgui/sdl_utils"

TIMELINE_HEIGHT :: 20
TIMELINE_LEGEND_SPACING :: 10
TIMELINE_SPACING :: 10
TIMELINE_TMARGINE :: 10
TIMELINE_BMARGINE :: 10
TIMELINE_LMARGINE :: 10
TIMELINE_RMARGINE :: 10

EVENT_THICKNESS :: 2

TimelinesWidget :: struct {
    tracer_data: ^TracerData,
    legend: struct {
        timelines: map[string]su.Text,
        w: f32,
        marker_text: su.Text,
    },
    toggle_timelines: map[string]^sgui.Widget,
    hovered_trace: ^Trace,
    hovered_trace_text: su.Text,
    hover_stopwatch: time.Stopwatch,
}

timelines_widget_create :: proc(tracer_data: ^TracerData) -> (tw: TimelinesWidget) {
    tw.tracer_data = tracer_data
    tw.legend.timelines = make(map[string]su.Text)
    tw.toggle_timelines = make(map[string]^sgui.Widget)
    return tw
}

timelines_widget_destroy :: proc(tw: ^TimelinesWidget) {
    delete(tw.legend.timelines)
    delete(tw.toggle_timelines)
}

timelines_widget_init :: proc(handle: ^sgui.Handle, widget: ^sgui.Widget, user_data: rawptr) {
    tw := cast(^TimelinesWidget)user_data

    time.stopwatch_start(&tw.hover_stopwatch)

    font := su.font_cache_get_font(&handle.font_cache, sgui.FONT, sgui.FONT_SIZE)
    tw.hovered_trace_text = su.text_create(handle.text_engine, font, "desc")
    su.text_update_color(&tw.hovered_trace_text, su.Color{0, 0, 0, 255})
    tw.legend.marker_text = su.text_create(handle.text_engine, font, "0 ns")
    su.text_update_color(&tw.legend.marker_text, su.Color{0, 0, 0, 255})

    for timeline in tw.tracer_data.timelines {
        text := su.text_create(
            handle.text_engine,
            su.font_cache_get_font(&handle.font_cache, sgui.FONT, sgui.FONT_SIZE),
            timeline)
        su.text_update_color(&text, su.Color{0, 0, 0, 255})
        w, h := su.text_size(&text)
        tw.legend.timelines[timeline] = text
        tw.legend.w = max(tw.legend.w, w)
    }
    sgui.add_event_handler(handle, widget, proc(widget: ^sgui.Widget, event: sgui.MouseMotionEvent, handle: ^sgui.Handle) -> bool {
        tw := cast(^TimelinesWidget)widget.data.(sgui.DrawBox).user_data
        time.stopwatch_reset(&tw.hover_stopwatch)
        time.stopwatch_start(&tw.hover_stopwatch)
        tw.hovered_trace = nil
        return false
    })
}

timelines_widget_update :: proc(handle: ^sgui.Handle, widget: ^sgui.Widget, user_data: rawptr) -> sgui.ContentSize {
    tw := cast(^TimelinesWidget)user_data
    draw_box := widget.data.(sgui.DrawBox)
    px_tp_ratio :=  draw_box.zoombox.lvl * widget.w / cast(f32)tw.tracer_data.ttl_time
    size := sgui.ContentSize{
        TIMELINE_LMARGINE + tw.legend.w + TIMELINE_LEGEND_SPACING \
            + cast(f32)tw.tracer_data.ttl_time * px_tp_ratio \
            + TIMELINE_RMARGINE,
        TIMELINE_TMARGINE + cast(f32)len(tw.tracer_data.timelines) * (TIMELINE_HEIGHT + TIMELINE_SPACING) + TIMELINE_BMARGINE,
    }
    return size
}

get_time_axis_markers :: proc(tstart, tttl: f32) -> (mstart, mstep: f32) {
    mstep = tttl / 3
    mstart = mstep * math.ceil(tstart / mstep)
    return mstart, mstep
}

timelines_widget_time_axis_draw :: proc(
    handle: ^sgui.Handle,
    widget: ^sgui.Widget,
    tw: ^TimelinesWidget,
    px_tp_ratio, position: f32
) -> (xoffset, yoffset: f32) {
    text_w, text_h := su.text_size(&tw.legend.marker_text)
    yoffset = cast(f32)TIMELINE_TMARGINE + text_h
    xoffset = tw.legend.w + TIMELINE_LMARGINE + TIMELINE_LEGEND_SPACING

    // draw time axis
    tstart := position / px_tp_ratio
    tttl := (widget.w - xoffset) / px_tp_ratio
    tend := tstart + tttl
    legend_start, legend_step := get_time_axis_markers(tstart, tttl)
    for legend := legend_start; legend < tend; legend += legend_step {
        legend_x := legend * px_tp_ratio - position
        if legend_x > 0 {
            tp_str := timestamp_to_string(cast(u64)legend)
            defer delete(tp_str)
            su.text_update_text(&tw.legend.marker_text, tp_str)
            text_w, _ := su.text_size(&tw.legend.marker_text)
            text_x := legend_x + xoffset - text_w / 2
            sgui.draw_text(handle, &tw.legend.marker_text, text_x, cast(f32)TIMELINE_TMARGINE)
            sgui.draw_rect(handle, legend_x + xoffset, cast(f32)yoffset - 2, 1, 4, sgui.Color{0, 0, 0, 255})
        }
    }
    sgui.draw_line(handle, tw.legend.w + TIMELINE_LMARGINE + TIMELINE_LEGEND_SPACING, cast(f32)yoffset, widget.w, cast(f32)yoffset, sgui.Color{0, 0, 0, 255})
    yoffset += TIMELINE_TMARGINE + TIMELINE_SPACING
    return
}

timelines_widget_draw :: proc(handle: ^sgui.Handle, widget: ^sgui.Widget, user_data: rawptr) {
    tw := cast(^TimelinesWidget)user_data
    draw_box := widget.data.(sgui.DrawBox)
    px_tp_ratio := draw_box.zoombox.lvl * widget.w / cast(f32)tw.tracer_data.ttl_time

    xoffset, yoffset := timelines_widget_time_axis_draw(handle, widget, tw, px_tp_ratio, draw_box.scrollbars.horizontal.position)

    for timeline, traces in tw.tracer_data.timelines {
        if !sgui.radio_button_value(tw.toggle_timelines[timeline]) do continue

        sgui.draw_text(handle, &tw.legend.timelines[timeline], TIMELINE_LMARGINE, cast(f32)yoffset)

        old_rel_rect := handle.rel_rect
        handle.rel_rect.x = old_rel_rect.x + tw.legend.w + TIMELINE_LMARGINE + TIMELINE_LEGEND_SPACING
        defer handle.rel_rect = old_rel_rect

        xoffset = -draw_box.scrollbars.horizontal.position

        for &trace in traces {
            dur := trace.end - trace.begin

            if dur == 0 {
                x : f32 = cast(f32)trace.begin * px_tp_ratio - EVENT_THICKNESS / 2. + xoffset
                y : f32 = yoffset
                w : f32 = EVENT_THICKNESS
                h : f32 = TIMELINE_HEIGHT

                if x + w < 0 {
                    continue
                } else if x > widget.w {
                    break
                }

                sgui.draw_rect(handle, x, y, w, h, tw.tracer_data.groups_infos[trace.group].color)
                if sgui.mouse_on_region(handle, x, y, w, h) {
                    tw.hovered_trace = &trace
                }
            } else {
                x : f32 = cast(f32)trace.begin * px_tp_ratio + xoffset
                y : f32 = yoffset
                w : f32 = cast(f32)dur * px_tp_ratio
                h : f32 = TIMELINE_HEIGHT

                if x + w < 0 {
                    continue
                } else if x > widget.w {
                    break
                }

                sgui.draw_rounded_box_with_border(handle, x, y, w, h, 6, 1,
                    sgui.Color{200, 200, 200, 255}, tw.tracer_data.groups_infos[trace.group].color)
                if sgui.mouse_on_region(handle, x, y, w, h) {
                    tw.hovered_trace = &trace
                }
            }
        }

        yoffset += TIMELINE_HEIGHT
        sgui.draw_line(handle, 0, cast(f32)yoffset + TIMELINE_SPACING / 2., widget.w, cast(f32)yoffset + TIMELINE_SPACING / 2., sgui.Color{0, 0, 0, 255})
        yoffset += TIMELINE_SPACING

        if time.duration_seconds(time.stopwatch_duration(tw.hover_stopwatch)) > 0.8 {
            sgui.add_ordered_draw(handle, 0, proc(handle: ^sgui.Handle, draw_data: rawptr) {
                tw := cast(^TimelinesWidget)draw_data

                if tw.hovered_trace == nil do return
                desc := trace_to_string(tw.hovered_trace^)
                defer delete(desc)
                su.text_update_text(&tw.hovered_trace_text, desc)
                w, h := su.text_size(&tw.hovered_trace_text)
                padding := cast(f32)4
                sgui.draw_rect(
                    handle,
                    handle.mouse_x - w - 2 * padding, handle.mouse_y,
                    w + 2 * padding, h + 2 * padding,
                    sgui.Color{0, 0, 0, 255}
                )
                sgui.draw_rect(
                    handle,
                    handle.mouse_x - w - 2 * padding + 1, handle.mouse_y + 1,
                    w + 2 * padding - 2, h + 2 * padding - 2,
                    sgui.Color{240, 240, 240, 255}
                )
                sgui.draw_text(handle, &tw.hovered_trace_text, handle.mouse_x - w - padding, handle.mouse_y + padding)
            }, tw)
        }
    }
}
