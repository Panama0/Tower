package main

import "core:fmt"

import "vendor:sdl3"

import r "render"

WidgetID :: distinct u16

Rect :: [4]f32

Window :: struct {
    bounds: Rect,
}

UIContext :: struct {
    current_win: string,
    // current_hovered:    string,
    // current_interacted: string,
    windows:     map[string]Window,
    cursor_pos:  Vec2,
    line_gap:    f32,
    renderer:    ^r.Renderer,
    // input
    mouse_pos:   Vec2,
    clicked:     bool,
    down:        bool,
}

ctx: UIContext

init :: proc(renderer: ^r.Renderer) {
    ctx = UIContext {
        renderer = renderer,
    }

    ctx.line_gap = 3
}

shutdown :: proc() {

}

//TODO: consume
ui_consume_input :: proc() {
    ctx.clicked = false

    mouse_pos_px := Vec2i{i32(state.input.mouse_x), i32(state.input.mouse_y)}

    ctx.mouse_pos = r.screen_to_world(ctx.renderer^, mouse_pos_px)
    ctx.clicked = key_pressed(.M_LEFT)
    ctx.down = key_down(.M_LEFT)

    // if !ctx.down {
    //     ctx.current_interacted = ""
    // }
}

ui_advance_cursor :: proc(height: f32) {
    win := ctx.windows[ctx.current_win]
    ctx.cursor_pos.x = win.bounds.x
    ctx.cursor_pos.y += height + ctx.line_gap
}

ui_get_cursor_pos :: proc() -> Vec2 {
    return ctx.cursor_pos
}

// WIDGETS

ui_window :: proc(title: string, bounds: Rect) {
    ctx.windows[title] = Window {
        bounds = bounds,
    }

    ctx.current_win = title

    ctx.cursor_pos = bounds.xy

    // draw
    rect := sdl3.FRect{**bounds.xyzw}
    r.draw_rect(ctx.renderer^, &rect, 0, 0, 0)
}

ui_window_end :: proc() {
    ctx.current_win = ""
}

ui_button :: proc(label: string) -> bool {
    HEIGHT :: 32
    // draw
    rect := sdl3.FRect{ctx.cursor_pos.x, ctx.cursor_pos.y, 32, 32}
    r.draw_rect(ctx.renderer^, &rect, 100, 100, 100)

    // draw the text
    r.draw_text(ctx.renderer^, fontIDs[.debug], label, **ctx.cursor_pos)

    // advance cursor
    ui_advance_cursor(HEIGHT)

    if ctx.clicked {
        // check hit
        if point_rect_intersect(
            ctx.mouse_pos,
            {rect.x, rect.y},
            rect.w,
            rect.h,
        ) {
            return true
        }
    }

    return false
}

ui_check_box :: proc(id: string, data: ^bool) {
    HEIGHT :: 32
    // draw
    // outer
    rect := sdl3.FRect{ctx.cursor_pos.x, ctx.cursor_pos.y, 32, 32}
    r.draw_rect(ctx.renderer^, &rect, 100, 100, 100)


    // inner
    INNER_WIDTH :: 16
    if data^ {
        rect := sdl3.FRect {
            ctx.cursor_pos.x,
            ctx.cursor_pos.y,
            INNER_WIDTH,
            INNER_WIDTH,
        }
        r.draw_rect(ctx.renderer^, &rect, 0, 200, 0)
    }

    // advance cursor
    ui_advance_cursor(HEIGHT)

    if ctx.clicked {
        // check hit
        if point_rect_intersect(
            ctx.mouse_pos,
            {rect.x, rect.y},
            rect.w,
            rect.h,
        ) {
            // flip
            data^ = !data^
        }
    }
}

ui_slider :: proc(id: string, data: ^f64, min, max: f64) {
    HEIGHT :: 32
    // draw
    // outer
    rect := sdl3.FRect{ctx.cursor_pos.x, ctx.cursor_pos.y, 128, 32}
    r.draw_rect(ctx.renderer^, &rect, 100, 100, 100)

    INNER_WIDTH :: 16
    rect_max := f64(rect.x) + f64(rect.w) - INNER_WIDTH

    // slider's pos in the rect
    slider_pos := map_range_values(data^, min, max, f64(rect.x), rect_max)

    // inner
    rect_inner := sdl3.FRect {
        f32(slider_pos),
        ctx.cursor_pos.y,
        INNER_WIDTH,
        32,
    }
    r.draw_rect(ctx.renderer^, &rect_inner, 0, 200, 0)

    // text
    r.draw_text(
        ctx.renderer^,
        fontIDs[.debug],
        fmt.tprintf("%.2f", data^),
        **ctx.cursor_pos,
    )

    // advance cursor
    ui_advance_cursor(HEIGHT)

    if ctx.down {
        // check hit
        if point_rect_intersect(
            ctx.mouse_pos,
            {rect.x, rect.y},
            rect.w,
            rect.h,
        ) {

            mouse_pos := map_range_values(
                f64(ctx.mouse_pos.x) - INNER_WIDTH / 2,
                f64(rect.x),
                rect_max,
                min,
                max,
            )

            // clamp to the input range
            mouse_pos = clamp(mouse_pos, min, max)
            data^ = mouse_pos
        }
    }
}

// text is wrapped to the window
ui_text :: proc(text: string, style: FontStyle, colour := Colour{}) {
    BASE_HEIGHT :: 32

    win := ctx.windows[ctx.current_win]
    // draw
    w, h := r.draw_text_wrapped(
        ctx.renderer^,
        fontIDs[style],
        text,
        **ctx.cursor_pos,
        win.bounds.w,
        (sdl3.Color)(colour),
    )

    // advance cursor
    if h > BASE_HEIGHT {
        ui_advance_cursor(h)
    } else {

        ui_advance_cursor(BASE_HEIGHT)
    }
}
