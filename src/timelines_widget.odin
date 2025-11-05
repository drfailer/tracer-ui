package tracer_ui

import "core:fmt"
import "deps:sgui"
import su "deps:sgui/sdl_utils"

TIMELINE_HEIGHT :: 20
TIMELINE_LEGEND_SPACING :: 10
TIMELINE_SPACING :: 10
TIMELINE_TMARGINE :: 10
TIMELINE_BMARGINE :: 10
TIMELINE_LMARGINE :: 10
TIMELINE_RMARGINE :: 10

NS_PIXEL_RATIO :: 1

EVENT_THICKNESS :: 4

TimelinesWidget :: struct {
    tracer_data: ^TracerData,
    legend: struct {
        timelines: map[string]su.Text,
        w: f32,
    },
    toggle_timelines: map[string]^sgui.Widget,
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
}

timelines_widget_update :: proc(handle: ^sgui.Handle, widget: ^sgui.Widget, user_data: rawptr) -> sgui.ContentSize {
    tw := cast(^TimelinesWidget)user_data
    draw_box := widget.data.(sgui.DrawBox)
    size := sgui.ContentSize{
        TIMELINE_LMARGINE + tw.legend.w + TIMELINE_LEGEND_SPACING \
            + cast(f32)tw.tracer_data.ttl_time * draw_box.zoombox.lvl * NS_PIXEL_RATIO \
            + TIMELINE_RMARGINE,
        TIMELINE_TMARGINE + cast(f32)len(tw.tracer_data.timelines) * (TIMELINE_HEIGHT + TIMELINE_SPACING) + TIMELINE_BMARGINE,
    }
    // fmt.println(size.width)
    return size
}

timelines_widget_draw :: proc(handle: ^sgui.Handle, widget: ^sgui.Widget, user_data: rawptr) {
    tw := cast(^TimelinesWidget)user_data
    draw_box := widget.data.(sgui.DrawBox)

    yoffset := cast(f32)TIMELINE_TMARGINE

    for timeline, traces in tw.tracer_data.timelines {
        if !tw.toggle_timelines[timeline]->value().(bool) do continue

        handle->draw_text(&tw.legend.timelines[timeline], TIMELINE_LMARGINE, cast(f32)yoffset)

        old_rel_rect := handle.rel_rect
        handle.rel_rect.x = old_rel_rect.x + tw.legend.w + TIMELINE_LMARGINE + TIMELINE_LEGEND_SPACING
        defer handle.rel_rect = old_rel_rect

        xoffset := -draw_box.scrollbox.horizontal.position

        for trace in traces {
            dur := trace.end - trace.begin

            if dur == 0 {
                handle->draw_rect(cast(f32)trace.begin * draw_box.zoombox.lvl - EVENT_THICKNESS / 2. + xoffset,
                                  yoffset, EVENT_THICKNESS, TIMELINE_HEIGHT, sgui.Color{0, 0, 255, 255})
            } else {
                sgui.draw_rounded_box_with_border(
                    handle,
                    cast(f32)trace.begin + xoffset, yoffset,
                    cast(f32)dur * draw_box.zoombox.lvl, TIMELINE_HEIGHT,
                    5, 1,
                    sgui.Color{0, 0, 0, 255},
                    sgui.Color{200, 200, 200, 255},
                )
            }
        }

        yoffset += TIMELINE_HEIGHT
        sgui.draw_line(handle, 0, cast(f32)yoffset + TIMELINE_SPACING / 2., widget.w, cast(f32)yoffset + TIMELINE_SPACING / 2., sgui.Color{0, 0, 0, 255})
        yoffset += TIMELINE_SPACING
    }
}
