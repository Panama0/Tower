package main

import "core:fmt"
import "core:log"
import "core:strings"

import "vendor:sdl3"

import r "render"

ButtonChar :: struct {
    upper: u8,
    lower: u8,
}

button_strings: #sparse[Button]ButtonChar = #partial {
    .A = {upper = 'A', lower = 'a'},
    .B = {upper = 'B', lower = 'b'},
    .C = {upper = 'C', lower = 'c'},
    .D = {upper = 'D', lower = 'd'},
    .E = {upper = 'E', lower = 'e'},
    .F = {upper = 'F', lower = 'f'},
    .G = {upper = 'G', lower = 'g'},
    .H = {upper = 'H', lower = 'h'},
    .I = {upper = 'I', lower = 'i'},
    .J = {upper = 'J', lower = 'j'},
    .K = {upper = 'K', lower = 'k'},
    .L = {upper = 'L', lower = 'l'},
    .M = {upper = 'M', lower = 'm'},
    .N = {upper = 'N', lower = 'n'},
    .O = {upper = 'O', lower = 'o'},
    .P = {upper = 'P', lower = 'p'},
    .Q = {upper = 'Q', lower = 'q'},
    .R = {upper = 'R', lower = 'r'},
    .S = {upper = 'S', lower = 's'},
    .T = {upper = 'T', lower = 't'},
    .U = {upper = 'U', lower = 'u'},
    .V = {upper = 'V', lower = 'v'},
    .W = {upper = 'W', lower = 'w'},
    .X = {upper = 'X', lower = 'x'},
    .Y = {upper = 'Y', lower = 'y'},
    .Z = {upper = 'Z', lower = 'z'},
    ._1 = {upper = '!', lower = '1'},
    ._2 = {upper = '@', lower = '2'},
    ._3 = {upper = '#', lower = '3'},
    ._4 = {upper = '$', lower = '4'},
    ._5 = {upper = '%', lower = '5'},
    ._6 = {upper = '^', lower = '6'},
    ._7 = {upper = '&', lower = '7'},
    ._8 = {upper = '*', lower = '8'},
    ._9 = {upper = '(', lower = '9'},
    ._0 = {upper = ')', lower = '0'},
}

Rect :: [4]f32

Window :: struct {
    bounds: Rect,
}

UIContext :: struct {
    current_win:        string,
    //TODO:
    // current_hovered:    string,
    current_interacted: string,
    windows:            map[string]Window,
    cursor_pos:         Vec2,
    line_gap:           f32,
    renderer:           ^r.Renderer,
    // input
    // for future, user call call something like wants_mouse(ui)
    //want_mouse: bool,
    //want_kb: bool,
    mouse_pos:          Vec2,
    clicked:            bool,
    down:               bool,
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

    for id, win in ctx.windows {
    }
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
            ctx.current_interacted = id
        }
    } else if ctx.current_interacted == id {
        ctx.current_interacted = ""
    }

    if ctx.current_interacted == id {
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

ui_textinput :: proc(id: string, buffer: []byte, len: int, cursor_pos: ^int) {
    HEIGHT :: 32
    WIDTH :: 128
    upper := false

    // input
    if ctx.current_interacted == id {
        if key_down(.LSHIFT) {
            upper = true
        }

        // alphanum
        for i in 4 ..= 39 {
            key := Button(i)
            if key_pressed(key) || key_repeat(key) {
                if cursor_pos^ < len - 1 {
                    char: u8
                    if upper {
                        char = button_strings[key].upper
                    } else {
                        char = button_strings[key].lower
                    }
                    buffer[cursor_pos^] = char

                    cursor_pos^ += 1
                }
            }
        }

        // space
        if key_pressed(.SPACE) || key_repeat(.SPACE) {
            if cursor_pos^ < len - 1 {
                buffer[cursor_pos^] = ' '
                cursor_pos^ += 1
            }
        }

        if key_pressed(.BACKSPACE) || key_repeat(.BACKSPACE) {
            if cursor_pos^ > 0 {
                buffer[cursor_pos^ - 1] = 0
                cursor_pos^ -= 1
            }
        }

    }


    // draw
    // outer
    rect := sdl3.FRect{ctx.cursor_pos.x, ctx.cursor_pos.y, WIDTH, HEIGHT}
    r.draw_rect(ctx.renderer^, &rect, 100, 100, 100)

    // text
    text_width, _ := r.measure_text(
        ctx.renderer^,
        fontIDs[.debug],
        transmute(string)buffer,
    )

    offset := max(0, text_width - rect.w)

    // dirty check if buffer is empty
    if buffer[0] != 0 {
        r.draw_text(
            ctx.renderer^,
            fontIDs[.debug],
            transmute(string)buffer,
            ctx.cursor_pos.x,
            ctx.cursor_pos.y,
            {255, 0, 0, 255},
            {offset, 0, WIDTH, 0},
        )
    }

    // cursor
    if ctx.current_interacted == id {
        cursor_x := min(
            ctx.cursor_pos.x + rect.w,
            ctx.cursor_pos.x + text_width,
        )
        cursor_rect := sdl3.FRect {
            cursor_x,
            ctx.cursor_pos.y,
            1,
            font_data[.debug].size_pt + 2,
        }
        r.draw_rect(ctx.renderer^, &cursor_rect, 255, 255, 255)
    }


    if ctx.clicked {
        // check hit
        if point_rect_intersect(
            ctx.mouse_pos,
            {rect.x, rect.y},
            rect.w,
            rect.h,
        ) {
            ctx.current_interacted = id
        } else if ctx.current_interacted == id do ctx.current_interacted = ""
    }
}
