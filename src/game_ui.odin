package main

import "core:log"
import "core:strconv"
import "vendor:sdl3"

HOTBAR_SLOTS :: 10

UIState :: struct {
    renderer:     ^sdl3.Renderer,
    w, h:         int,
    // add here
    hotbar_items: [HOTBAR_SLOTS]Item, // position on hotbar to item
    hotbar_index: int,
}

@(private = "file")
ui_state: UIState

ui_init :: proc(renderer: ^sdl3.Renderer, w, h: int) {
    ui_state.renderer = renderer
    ui_state.w = w
    ui_state.h = h

}


// update UI
// could convert to its own binding map later...
ui_update :: proc() {
    if key_pressed(.SC_UP) {
        ui_state.hotbar_index += 1
        ui_state.hotbar_index %= HOTBAR_SLOTS
        state.gs.selected_item = ui_state.hotbar_items[ui_state.hotbar_index]

        consume_key_pressed(.SC_UP)
    }

    if key_pressed(.SC_DOWN) {
        ui_state.hotbar_index -= 1
        if ui_state.hotbar_index < 0 {
            ui_state.hotbar_index = HOTBAR_SLOTS - 1
        }
        state.gs.selected_item = ui_state.hotbar_items[ui_state.hotbar_index]

        consume_key_pressed(.SC_DOWN)
    }

    // number keys for direct slot selection
    for slot in 0 ..< HOTBAR_SLOTS {
        btn := Button(int(Button._1) + slot)
        if key_pressed(btn) {
            ui_state.hotbar_index = slot
            state.gs.selected_item = ui_state.hotbar_items[slot]

            consume_key_pressed(btn)
        }
    }

}

// for save/load
ui_set_hotbar_items :: proc(items: [HOTBAR_SLOTS]Item) {
    for i, item in items {
        ui_state.hotbar_items[item] = i
    }


    state.gs.selected_item = ui_state.hotbar_items[ui_state.hotbar_index]
}

ui_draw_hud :: proc() {
    HOTBAR_SLOT_SIZE :: 32
    HOTBAR_GAP :: 50
    HOTBAR_OFFSET_Y :: 10
    HOTBAR_SELECTED_WIDTH :: 10

    renderer := ui_state.renderer

    // calculate hotbar offset to make centered
    hotbar_width := HOTBAR_GAP * HOTBAR_SLOTS
    offset := ui_state.w - hotbar_width
    if offset < 0 do log.debug("Hotbar does not fit")
    hotbar_offset_x := offset / 2

    // draw hotbar
    for i in 0 ..< HOTBAR_SLOTS {
        pos := sdl3.FRect {
            f32(hotbar_offset_x) + HOTBAR_GAP * f32(i),
            HOTBAR_OFFSET_Y,
            HOTBAR_SLOT_SIZE,
            HOTBAR_SLOT_SIZE,
        }

        // draw selected
        if i == ui_state.hotbar_index {
            half_width: f32 = HOTBAR_SELECTED_WIDTH / 2

            pos_selected := sdl3.FRect {
                pos.x - half_width,
                pos.y - half_width,
                pos.w + HOTBAR_SELECTED_WIDTH,
                pos.h + HOTBAR_SELECTED_WIDTH,
            }
            draw_rect(renderer, &pos_selected, 0, 0, 0)
        }

        // draw regular empty slots
        draw_rect(renderer, &pos, 150, 150, 150, 150)

        // draw item
        item_at_slot := ui_state.hotbar_items[i]
        if item_at_slot != .none {
            sprite := state.sprites[item_data[item_at_slot].sprite]

            src := sprite.uv
            dest := sdl3.FRect {
                pos.x,
                pos.y,
                f32(sprite.width),
                f32(sprite.height),
            }
            sdl3.RenderTexture(renderer, state.atlas.texture, &src, &dest)
        }

        // draw text on top left
        b: [4]byte
        draw_text(
            renderer,
            .normal,
            strconv.write_int(b[:], i64(i + 1), 10),
            pos.x,
            pos.y,
        )
    }
}
