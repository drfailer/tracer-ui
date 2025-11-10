package tracer_ui

import "core:os"
import "core:log"
import "core:fmt"
import "deps:sgui"
import su "deps:sgui/sdl_utils"

SIDE_PANNEL_TAG :: 1
TIMELINES_WIDGET_TAG :: 1

set_theme :: proc() {
    using sgui
    OPTS = Opts{
        clear_color = Color{255, 255, 255, 255},
        text_attr = TextAttributes{
            style = TextStyle{
                font = FONT,
                font_size = FONT_SIZE,
                color = Color{0, 0, 0, 255},
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
                colors = [ButtonState]ButtonColors{
                    .Idle = ButtonColors{
                        text = Color{0, 0, 0, 255},
                        border = Color{0, 0, 0, 255},
                        bg = Color{255, 255, 255, 255},
                    },
                    .Hovered = ButtonColors{
                        text = Color{0, 0, 0, 255},
                        border = Color{0, 0, 0, 255},
                        bg = Color{100, 100, 100, 255},
                    },
                    .Clicked = ButtonColors{
                        text = Color{255, 255, 255, 255},
                        border = Color{255, 255, 255, 255},
                        bg = Color{0, 0, 0, 255},
                    },
                },
            },
        },
        radio_button_attr = RadioButtonAttributes{
            style = RadioButtonStyle{
                base_radius = 6,
                border_thickness = 1,
                dot_radius = 2,
                border_color = Color{0, 0, 0, 255},
                background_color = Color{255, 255, 255, 255},
                dot_color = Color{0, 0, 0, 255},
                label_padding = 10,
                label_color = Color{0, 0, 0, 255},
                font = FONT,
                font_size = FONT_SIZE,
            }
        },
        scrollbox_attr = ScrollboxAttributes{
            style = ScrollboxStyle{
                scrollbar_style = ScrollbarStyle{
                    background_color = Color{250, 250, 250, 255},
                    color = [ScrollbarState]Color{
                        .Idle = Color{150, 150, 150, 255},
                        .Hovered = Color{170, 170, 170, 255},
                        .Selected = Color{160, 160, 160, 255},
                    },
                },
            },
        },
    }
}

side_pannel :: proc(timelines_widget: ^TimelinesWidget) -> (pannel: ^sgui.Widget) {
    pannel = sgui.vbox(
        sgui.text("Menu"),
        attr = sgui.BoxAttributes{
            props = sgui.BoxProperties{.FitW},
            style = sgui.BoxStyle{
                active_borders = sgui.ActiveBorders{.Right},
                border_color = sgui.Color{0, 0, 0, 255},
                border_thickness = 1,
                background_color = sgui.Color{240, 240, 250, 255},
                padding = sgui.Padding{4, 4, 4, 4},
                items_spacing = 5,
            }
        }
    )

    sgui.box_add_widget(pannel, sgui.text("groups:"))
    idle_group_button := sgui.radio_button("_idle", default_checked = true)
    timelines_widget.groups["_idle"] = TimelinesWidgetGroupData{
        button = idle_group_button,
        color = sgui.Color{255, 255, 255, 255}, // this group is not drawn directly
    }
    sgui.box_add_widget(pannel, idle_group_button)
    for group, conf in timelines_widget.tracer_data.groups {
        button := sgui.radio_button(group, default_checked = true)
        timelines_widget.groups[group] = TimelinesWidgetGroupData{
            button = button,
            color = conf.color,
        }
        sgui.box_add_widget(pannel, button)
    }

    sgui.box_add_widget(pannel, sgui.text("timelines:"))
    for timeline in timelines_widget.tracer_data.timelines {
        button := sgui.radio_button(timeline, default_checked = true)
        timelines_widget.toggle_timelines[timeline] = button
        sgui.box_add_widget(pannel, button)
    }

    pannel.disabled = true
    return pannel
}

header :: proc() -> ^sgui.Widget {
    return sgui.vbox(
        sgui.hbox(
            sgui.button("MENU", proc(handle: ^sgui.Handle, _: rawptr) {
                sgui.widget_toggle(handle.tagged_widgets[SIDE_PANNEL_TAG], handle)
            }),
            sgui.center(sgui.text("TRACER")),
            attr = sgui.BoxAttributes{
                props = sgui.BoxProperties{.FitH},
            }
        ),
        attr = sgui.BoxAttributes{
            props = sgui.BoxProperties{.FitH},
            style = sgui.BoxStyle{
                active_borders = sgui.ActiveBorders{.Bottom},
                border_color = sgui.Color{0, 0, 0, 255},
                border_thickness = 1,
                background_color = sgui.Color{250, 250, 255, 255},
                padding = sgui.Padding{10, 10, 10, 10},
            }
        }
    )
}

main_ui :: proc(handle: ^sgui.Handle, timelines_widget: ^TimelinesWidget) -> ^sgui.Widget {
    context.allocator = handle.widget_allocator
    side_pannel := side_pannel(timelines_widget)
    sgui.tag_widget(handle, side_pannel, SIDE_PANNEL_TAG)

    return sgui.vbox(
        header(),
        sgui.hbox(
            side_pannel,
            sgui.draw_box(
                timelines_widget_draw,
                timelines_widget_update,
                timelines_widget_init,
                data = timelines_widget,
                attr = sgui.DrawBoxAttributes{
                    props = sgui.DrawBoxProperties{.WithScrollbar, .Zoomable},
                    zoom_min = 1.,
                    zoom_max = 1000.,
                    zoom_step = .5,
                }
            ),
        ),
    )
}
