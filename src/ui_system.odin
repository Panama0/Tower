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

UIImage :: struct {
    texture:    ^sdl3.Texture,
    source:     sdl3.FRect,
    use_source: bool,
}

UIStyle :: struct {
    // these control cursor movement aka gaps
    base_width:           f32,
    base_height:          f32,
    line_gap:             f32,
    long_width:           f32, // For long widgets like text input and slider
    // styles
    window_colour:        [4]u8,
    widget_colour:        [4]u8,
    accent_colour:        [4]u8,
    text_colour:          [4]u8,
    input_text_colour:    [4]u8,
    cursor_colour:        [4]u8,

    // Element-specific items
    checkbox_inner_width: f32,
    slider_inner_width:   f32,
}

default_style := UIStyle {
    base_width           = 32,
    base_height          = 32,
    line_gap             = 3,
    long_width           = 128,
    window_colour        = {0, 0, 0, 255},
    widget_colour        = {100, 100, 100, 255},
    accent_colour        = {0, 200, 0, 255},
    text_colour          = {0, 0, 0, 255},
    input_text_colour    = {255, 0, 0, 255},
    cursor_colour        = {255, 255, 255, 255},

    // Element-specific items
    checkbox_inner_width = 16,
    slider_inner_width   = 16,
}

UILayout :: enum {
    Vertical,
    Horizontal,
}

UIContext :: struct {
    current_win:        string,
    //TODO:
    // current_hovered:    string,
    current_interacted: string,
    windows:            map[string]Window,
    cursor_pos:         Vec2,
    renderer:           ^r.Renderer,
    //TODO: stack
    style:              UIStyle,
    layout:             UILayout,
    tallest_height:     f32,
    // composites
    in_composite:       bool,
    composite_w:        f32,
    composite_h:        f32,

    // input
    // for future, user can call something like wants_mouse(ui)
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
        style    = default_style,
    }
}

shutdown :: proc() {

}

//TODO: consume ui input
ui_consume_input :: proc() {
    ctx.clicked = false

    mouse_pos_px := Vec2i{i32(state.input.mouse_x), i32(state.input.mouse_y)}

    ctx.mouse_pos = r.screen_to_world(ctx.renderer^, mouse_pos_px)
    ctx.clicked = key_pressed(.M_LEFT)
    ctx.down = key_down(.M_LEFT)

    for id, win in ctx.windows {
    }
}

// The pointer is only valid until the windows map is modified.
ui_get_current_window :: proc() -> ^Window {
    return &ctx.windows[ctx.current_win]
}

ui_advance_cursor :: proc(width, height: f32) {
    if ctx.in_composite do return

    win := ui_get_current_window()

    switch ctx.layout {
    case .Vertical:
        ctx.cursor_pos.x = win.bounds.x
        ctx.cursor_pos.y += height + ctx.style.line_gap
    case .Horizontal:
        ctx.cursor_pos.x += width + ctx.style.line_gap

        // track tallest
        if height > ctx.tallest_height {
            ctx.tallest_height = height
        }
    }
}

ui_get_cursor_pos :: proc() -> Vec2 {
    return ctx.cursor_pos
}

// use with care!
ui_set_cursor_pos :: proc(pos: Vec2) {
    assert(
        ctx.layout != .Horizontal || pos.y == ctx.cursor_pos.y,
        "Cannot change cursor Y inside a horizontal layout",
    )
    win_bounds := ui_get_current_window().bounds

    // check if in win bounds
    if point_rect_intersect(pos, win_bounds.xy, **win_bounds.zw) {
        ctx.cursor_pos = pos
    } else {
        log.debug("Failed to set cursor pos: OOB")
    }
}


ui_push_horizontal :: proc() {
    assert(
        ctx.current_win != "",
        "Horizontal layouts require an active window",
    )
    assert(
        ctx.layout == .Vertical,
        "Nested horizontal layouts are not supported",
    )
    ctx.tallest_height = 0
    ctx.layout = .Horizontal
}

ui_pop_horizontal :: proc() {
    assert(!ctx.in_composite, "End the composite before popping the horizontal layout")
    assert(
        ctx.current_win != "",
        "Horizontal layouts require an active window",
    )
    assert(
        ctx.layout == .Horizontal,
        "ui_pop_horizontal requires a matching push",
    )
    ctx.layout = .Vertical

    // go down by the tallest element found
    ctx.cursor_pos.x = ui_get_current_window().bounds.x
    ctx.cursor_pos.y += ctx.tallest_height + ctx.style.line_gap
    ctx.tallest_height = 0
}

// begin a composite widget and suppress automatic cursor movement
// make sure to save the cursor pos and restore it after making any manual placements
ui_begin_composite :: proc(w, h: f32) {
    assert(ctx.current_win != "", "Composites require an active window")
    // should we store the cursor pos and restore it for the user? or have them do it...
    assert(!ctx.in_composite, "Already in a composite")
    ctx.in_composite = true
    ctx.composite_w = w
    ctx.composite_h = h
}

ui_end_composite :: proc() {
    assert(ctx.in_composite, "Must be in a composite")
    ctx.in_composite = false

    ui_advance_cursor(ctx.composite_w, ctx.composite_h)
    ctx.composite_w = 0
    ctx.composite_h = 0
}

// WIDGETS

ui_window :: proc(title: string, bounds: Rect) {
    assert(!ctx.in_composite, "End the composite before starting a window")
    assert(
        ctx.layout == .Vertical,
        "End the horizontal layout before starting a window",
    )
    ctx.windows[title] = Window {
        bounds = bounds,
    }

    ctx.current_win = title

    ctx.cursor_pos = bounds.xy
    ctx.layout = .Vertical
    ctx.tallest_height = 0

    // draw
    rect := sdl3.FRect{**bounds.xyzw}
    r.draw_rect(ctx.renderer^, &rect, **ctx.style.window_colour)
}

ui_window_end :: proc() {
    assert(!ctx.in_composite, "End the composite before ending the window")
    assert(
        ctx.layout == .Vertical,
        "End the horizontal layout before ending the window",
    )
    ctx.current_win = ""
}

ui_button :: proc(label: string) -> bool {
    // draw
    rect := sdl3.FRect {
        ctx.cursor_pos.x,
        ctx.cursor_pos.y,
        ctx.style.base_width,
        ctx.style.base_height,
    }
    r.draw_rect(ctx.renderer^, &rect, **ctx.style.widget_colour)

    // draw the text
    r.draw_text(
        ctx.renderer^,
        fontIDs[.debug],
        label,
        **ctx.cursor_pos,
        sdl3.Color{**ctx.style.text_colour},
    )

    // advance cursor
    ui_advance_cursor(rect.w, rect.h)

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
    // draw
    // outer
    rect := sdl3.FRect {
        ctx.cursor_pos.x,
        ctx.cursor_pos.y,
        ctx.style.base_width,
        ctx.style.base_height,
    }
    r.draw_rect(ctx.renderer^, &rect, **ctx.style.widget_colour)


    // inner
    if data^ {
        rect := sdl3.FRect {
            ctx.cursor_pos.x,
            ctx.cursor_pos.y,
            ctx.style.checkbox_inner_width,
            ctx.style.checkbox_inner_width,
        }
        r.draw_rect(ctx.renderer^, &rect, **ctx.style.accent_colour)
    }

    // advance cursor
    ui_advance_cursor(rect.w, rect.h)

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
    // draw
    // outer
    rect := sdl3.FRect {
        ctx.cursor_pos.x,
        ctx.cursor_pos.y,
        ctx.style.long_width,
        ctx.style.base_height,
    }
    r.draw_rect(ctx.renderer^, &rect, **ctx.style.widget_colour)

    rect_max := f64(rect.x) + f64(rect.w) - f64(ctx.style.slider_inner_width)

    // slider's pos in the rect
    slider_pos := map_range_values(data^, min, max, f64(rect.x), rect_max)

    // inner
    rect_inner := sdl3.FRect {
        f32(slider_pos),
        ctx.cursor_pos.y,
        ctx.style.slider_inner_width,
        ctx.style.base_height,
    }
    r.draw_rect(ctx.renderer^, &rect_inner, **ctx.style.accent_colour)

    // text
    r.draw_text(
        ctx.renderer^,
        fontIDs[.debug],
        fmt.tprintf("%.2f", data^),
        **ctx.cursor_pos,
        sdl3.Color{**ctx.style.text_colour},
    )

    // advance cursor
    ui_advance_cursor(rect.w, rect.h)

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
            f64(ctx.mouse_pos.x) - f64(ctx.style.slider_inner_width) / 2,
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

// text is always wrapped to the window
ui_text :: proc(
    text: string,
    width: f32,
    style: FontStyle,
    colour := ctx.style.text_colour,
) {
    width := width

    if width == 0 {
        win := ui_get_current_window()
        width = win.bounds.w
    }

    // draw
    w, h := r.draw_text_wrapped(
        ctx.renderer^,
        fontIDs[style],
        text,
        **ctx.cursor_pos,
        width,
        sdl3.Color{**colour},
    )

    // advance cursor
    ui_advance_cursor(w, max(h, ctx.style.base_height))
}

ui_textinput :: proc(
    id: string,
    buffer: []byte,
    len: int,
    txt_cursor_pos: ^int,
) {
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
                if txt_cursor_pos^ < len - 1 {
                    char: u8
                    if upper {
                        char = button_strings[key].upper
                    } else {
                        char = button_strings[key].lower
                    }
                    buffer[txt_cursor_pos^] = char

                    txt_cursor_pos^ += 1
                }
            }
        }

        // space
        if key_pressed(.SPACE) || key_repeat(.SPACE) {
            if txt_cursor_pos^ < len - 1 {
                buffer[txt_cursor_pos^] = ' '
                txt_cursor_pos^ += 1
            }
        }

        if key_pressed(.BACKSPACE) || key_repeat(.BACKSPACE) {
            if txt_cursor_pos^ > 0 {
                buffer[txt_cursor_pos^ - 1] = 0
                txt_cursor_pos^ -= 1
            }
        }

    }


    // draw
    // outer
    rect := sdl3.FRect {
        ctx.cursor_pos.x,
        ctx.cursor_pos.y,
        ctx.style.long_width,
        ctx.style.base_height,
    }
    r.draw_rect(ctx.renderer^, &rect, **ctx.style.widget_colour)

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
            **ctx.cursor_pos,
            sdl3.Color{**ctx.style.input_text_colour},
            {offset, 0, ctx.style.long_width, 0},
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
        r.draw_rect(ctx.renderer^, &cursor_rect, **ctx.style.cursor_colour)
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

    // advance cursor
    ui_advance_cursor(rect.w, rect.h)
}

ui_image :: proc(image: UIImage, width, height: f32) {
    assert(image.texture != nil, "ui_image requires a texture")
    assert(width > 0 && height > 0, "ui_image requires positive dimensions")

    rect := sdl3.FRect{**ctx.cursor_pos, width, height}
    source_rect := image.source
    source: ^sdl3.FRect
    if image.use_source {
        source = &source_rect
    }

    sdl3.RenderTexture(ctx.renderer.sdl_renderer, image.texture, source, &rect)

    // advance cursor
    ui_advance_cursor(rect.w, rect.h)
}
