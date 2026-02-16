package tracer_ui

import "core:os"
import "core:log"
import "core:fmt"
import "deps:sgui"
import "deps:sgui/widgets"

SIDE_PANNEL_TAG :: 1
TIMELINES_WIDGET_TAG :: 1

IMAGE_PATH :: #config(IMAGE_PATH, "ressources/images")

set_theme :: proc() {
    using widgets
    sgui.OPTS = sgui.Opts{
        clear_color = sgui.Color{255, 255, 255, 255},
    }
    OPTS = Opts{
        text_attr = TextAttributes{
            style = TextStyle{
                font = FONT,
                font_size = FONT_SIZE,
                color = sgui.Color{0, 0, 0, 255},
                wrap_width = 0,
            },
        },
        button_attr = ButtonAttributes{
            style = ButtonStyle{
                label_font_path = FONT,
                label_font_size = FONT_SIZE,
                padding = {2, 2, 2, 2},
                border_thickness = 1,
                corner_radius = 0,
                colors = [sgui.WidgetMouseState]ButtonColors{
                    .Idle = ButtonColors{
                        text = sgui.Color{0, 0, 0, 255},
                        border = sgui.Color{0, 0, 0, 255},
                        bg = sgui.Color{255, 255, 255, 255},
                    },
                    .Hovered = ButtonColors{
                        text = sgui.Color{0, 0, 0, 255},
                        border = sgui.Color{0, 0, 0, 255},
                        bg = sgui.Color{100, 100, 100, 255},
                    },
                    .Clicked = ButtonColors{
                        text = sgui.Color{255, 255, 255, 255},
                        border = sgui.Color{255, 255, 255, 255},
                        bg = sgui.Color{0, 0, 0, 255},
                    },
                },
            },
        },
        radio_button_attr = RadioButtonAttributes{
            style = RadioButtonStyle{
                base_radius = 6,
                border_thickness = 1,
                dot_radius = 2,
                border_color = sgui.Color{0, 0, 0, 255},
                background_color = sgui.Color{255, 255, 255, 255},
                dot_color = sgui.Color{0, 0, 0, 255},
                label_padding = 10,
                label_color = sgui.Color{0, 0, 0, 255},
                font = FONT,
                font_size = FONT_SIZE,
            }
        },
        scrollbars_attr = ScrollbarsAttributes{
            style = ScrollbarStyle{
                track_padding = Padding{2, 2, 2, 2},
                track_color = sgui.Color{240, 240, 240, 255},
                thumb_color = [sgui.WidgetMouseState]sgui.Color{
                    .Idle = sgui.Color{150, 150, 150, 255},
                    .Hovered = sgui.Color{170, 170, 170, 255},
                    .Clicked = sgui.Color{160, 160, 160, 255},
                },
                button_color = [sgui.WidgetMouseState]sgui.Color{
                    .Idle = sgui.Color{150, 150, 150, 255},
                    .Hovered = sgui.Color{170, 170, 170, 255},
                    .Clicked = sgui.Color{160, 160, 160, 255},
                },
            },
        },
    }
}

side_pannel :: proc(timelines_widget: ^TimelinesWidget) -> (pannel: ^sgui.Widget) {
    using widgets
    pannel = vbox(
        text("Menu"),
        attr = BoxAttributes{
            props = BoxProperties{.FitW},
            style = BoxStyle{
                active_borders = ActiveBorders{.Right},
                border_color = sgui.Color{0, 0, 0, 255},
                border_thickness = 1,
                background_color = sgui.Color{240, 240, 250, 255},
                padding = Padding{10, 10, 10, 10},
                items_spacing = 5,
            }
        }
    )

    widgets := make([dynamic]^sgui.Widget)
    defer delete(widgets)

    // toggle groups buttons
    for group in timelines_widget.tracer_data.groups_infos {
        button := radio_button(group, default_checked = true)
        timelines_widget.toggle_groups[group] = button
        append(&widgets, button)
    }
    box_add_widget(pannel, collapsable_section("groups", ..widgets[:]))
    clear(&widgets)

    // toggle timelines buttons
    for timeline in timelines_widget.tracer_data.timelines_infos {
        button := radio_button(timeline, default_checked = true)
        timelines_widget.toggle_timelines[timeline] = button
        append(&widgets, button)
    }
    box_add_widget(pannel, collapsable_section("timelines:", ..widgets[:]))
    clear(&widgets)

    // stats
    for group, group_info in timelines_widget.tracer_data.groups_infos {
        info_str := group_info_to_string(group, group_info)
        defer delete(info_str)
        append(&widgets, text(info_str))
    }
    box_add_widget(pannel, collapsable_section("stats:", ..widgets[:]))
    pannel.disabled = true
    return pannel
}

header :: proc() -> ^sgui.Widget {
    using widgets
    return vbox(
        hbox(
            icon_button(
                IconData{file = IMAGE_PATH + "/sidebar.svg"},
                proc(ui: ^sgui.Ui, _: rawptr) {
                    sgui.widget_toggle(ui->widget(SIDE_PANNEL_TAG), ui)
                },
                w = 20, h = 20,
                attr = {
                    style = {
                        padding = {4, 4, 4, 4},
                        corner_radius = 5,
                        colors = {
                            .Idle = {
                                bg = {255, 255, 255, 255},
                            },
                            .Hovered = {
                                bg = {220, 220, 220, 255},
                            },
                            .Clicked = {
                                bg = {220, 220, 220, 255},
                            },
                        },
                    }
                }
            ),
            sgui.center(text("TRACER")),
            attr = BoxAttributes{
                props = BoxProperties{.FitH},
            }
        ),
        attr = BoxAttributes{
            props = BoxProperties{.FitH},
            style = BoxStyle{
                active_borders = ActiveBorders{.Bottom},
                border_color = sgui.Color{0, 0, 0, 255},
                border_thickness = 1,
                background_color = sgui.Color{250, 250, 255, 255},
                padding = Padding{10, 10, 10, 10},
            }
        },
        z_index = 1,
    )
}

main_ui :: proc(ui: ^sgui.Ui, timelines_widget: ^TimelinesWidget) -> ^sgui.Widget {
    using widgets
    context.allocator = ui.widget_allocator
    side_pannel := side_pannel(timelines_widget)
    ui->store(SIDE_PANNEL_TAG, side_pannel)

    return vbox(
        header(),
        hbox(
            side_pannel,
            draw_box(
                timelines_widget_draw,
                timelines_widget_update,
                timelines_widget_init,
                data = timelines_widget,
                attr = DrawBoxAttributes{
                    props = DrawBoxProperties{.WithScrollbar, .Zoomable},
                    zoom_min = 1.,
                    zoom_max = 1000000.,
                    zoom_step = 10.,
                    scrollbars_attr = OPTS.scrollbars_attr,
                }
            ),
        ),
    )
}
