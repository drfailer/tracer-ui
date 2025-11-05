package tracer_ui

import "core:os"
import "core:mem"
import "core:log"
import "core:fmt"
import "deps:sgui"

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    if len(os.args) != 2 {
        log.error("requies arguments.")
    }

    set_theme()

    tracer_data := tracer_parse_file(os.args[1])
    defer tracer_data_destroy(tracer_data)
    timelines_widget := timelines_widget_create(tracer_data)
    defer timelines_widget_destroy(&timelines_widget)

    handle := sgui.create()

    handle->add_layer(main_ui(handle, &timelines_widget))

    sgui.init(handle)
    sgui.run(handle)
    sgui.destroy(handle)
}
