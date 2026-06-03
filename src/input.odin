package main

import "vendor:sdl3"

// #todo, remove this and make everything operate via params passed down
// that way we can have helpers elsewhere that use the game's context for this

Bind :: struct {
    button:    Button,
    activator: InputFlag,
}

InputState :: struct {
    keys:             [300]bit_set[InputFlag],
    mouse_x, mouse_y: f32,
    scroll_y:         f32,
}

InputFlag :: enum u8 {
    down,
    pressed,
    released,
    repeat, // just for keysssssssssssss (after the first press. needed for text input stuff)
}

Button :: enum {
    UNKNOWN = 0,

    /**
	*  \name Usage page 0x07
	*
	*  These values are from usage page 0x07 (USB keyboard page).
	*/
    /* @{ */
    A = 4,
    B = 5,
    C = 6,
    D = 7,
    E = 8,
    F = 9,
    G = 10,
    H = 11,
    I = 12,
    J = 13,
    K = 14,
    L = 15,
    M = 16,
    N = 17,
    O = 18,
    P = 19,
    Q = 20,
    R = 21,
    S = 22,
    T = 23,
    U = 24,
    V = 25,
    W = 26,
    X = 27,
    Y = 28,
    Z = 29,
    _1 = 30,
    _2 = 31,
    _3 = 32,
    _4 = 33,
    _5 = 34,
    _6 = 35,
    _7 = 36,
    _8 = 37,
    _9 = 38,
    _0 = 39,
    RETURN = 40,
    ESCAPE = 41,
    BACKSPACE = 42,
    TAB = 43,
    SPACE = 44,
    MINUS = 45,
    EQUALS = 46,
    LEFTBRACKET = 47,
    RIGHTBRACKET = 48,
    BACKSLASH = 49, /**< Located at the lower left of the return
	                 *   key on ISO keyboards and at the right end
	                 *   of the QWERTY row on ANSI keyboards.
	                 *   Produces REVERSE SOLIDUS (backslash) and
	                 *   VERTICAL LINE in a US layout, REVERSE
	                 *   SOLIDUS and VERTICAL LINE in a UK Mac
	                 *   layout, NUMBER SIGN and TILDE in a UK
	                 *   Windows layout, DOLLAR SIGN and POUND SIGN
	                 *   in a Swiss German layout, NUMBER SIGN and
	                 *   APOSTROPHE in a German layout, GRAVE
	                 *   ACCENT and POUND SIGN in a French Mac
	                 *   layout, and ASTERISK and MICRO SIGN in a
	                 *   French Windows layout.
	                 */
    NONUSHASH = 50, /**< ISO USB keyboards actually use this code
	                 *   instead of 49 for the same key, but all
	                 *   OSes I've seen treat the two codes
	                 *   identically. So, as an implementor, unless
	                 *   your keyboard generates both of those
	                 *   codes and your OS treats them differently,
	                 *   you should generate BACKSLASH
	                 *   instead of this code. As a user, you
	                 *   should not rely on this code because SDL
	                 *   will never generate it with most (all?)
	                 *   keyboards.
	                 */
    SEMICOLON = 51,
    APOSTROPHE = 52,
    GRAVE = 53, /**< Located in the top left corner (on both ANSI
	             *   and ISO keyboards). Produces GRAVE ACCENT and
	             *   TILDE in a US Windows layout and in US and UK
	             *   Mac layouts on ANSI keyboards, GRAVE ACCENT
	             *   and NOT SIGN in a UK Windows layout, SECTION
	             *   SIGN and PLUS-MINUS SIGN in US and UK Mac
	             *   layouts on ISO keyboards, SECTION SIGN and
	             *   DEGREE SIGN in a Swiss German layout (Mac:
	             *   only on ISO keyboards), CIRCUMFLEX ACCENT and
	             *   DEGREE SIGN in a German layout (Mac: only on
	             *   ISO keyboards), SUPERSCRIPT TWO and TILDE in a
	             *   French Windows layout, COMMERCIAL AT and
	             *   NUMBER SIGN in a French Mac layout on ISO
	             *   keyboards, and LESS-THAN SIGN and GREATER-THAN
	             *   SIGN in a Swiss German, German, or French Mac
	             *   layout on ANSI keyboards.
	             */
    COMMA = 54,
    PERIOD = 55,
    SLASH = 56,
    CAPSLOCK = 57,
    F1 = 58,
    F2 = 59,
    F3 = 60,
    F4 = 61,
    F5 = 62,
    F6 = 63,
    F7 = 64,
    F8 = 65,
    F9 = 66,
    F10 = 67,
    F11 = 68,
    F12 = 69,
    PRINTSCREEN = 70,
    SCROLLLOCK = 71,
    PAUSE = 72,
    INSERT = 73, /**< insert on PC, help on some Mac keyboards (but
	                           does send code 73, not 117) */
    HOME = 74,
    PAGEUP = 75,
    DELETE = 76,
    END = 77,
    PAGEDOWN = 78,
    RIGHT = 79,
    LEFT = 80,
    DOWN = 81,
    UP = 82,
    NUMLOCKCLEAR = 83, /**< num lock on PC, clear on Mac keyboards
	                             */
    KP_DIVIDE = 84,
    KP_MULTIPLY = 85,
    KP_MINUS = 86,
    KP_PLUS = 87,
    KP_ENTER = 88,
    KP_1 = 89,
    KP_2 = 90,
    KP_3 = 91,
    KP_4 = 92,
    KP_5 = 93,
    KP_6 = 94,
    KP_7 = 95,
    KP_8 = 96,
    KP_9 = 97,
    KP_0 = 98,
    KP_PERIOD = 99,
    NONUSBACKSLASH = 100, /**< This is the additional key that ISO
	                       *   keyboards have over ANSI ones,
	                       *   located between left shift and Y.
	                       *   Produces GRAVE ACCENT and TILDE in a
	                       *   US or UK Mac layout, REVERSE SOLIDUS
	                       *   (backslash) and VERTICAL LINE in a
	                       *   US or UK Windows layout, and
	                       *   LESS-THAN SIGN and GREATER-THAN SIGN
	                       *   in a Swiss German, German, or French
	                       *   layout. */
    APPLICATION = 101, /**< windows contextual menu, compose */
    POWER = 102, /**< The USB document says this is a status flag,
	              *   not a physical key - but some Mac keyboards
	              *   do have a power key. */
    KP_EQUALS = 103,
    M_LEFT = 200,
    M_MIDDLE = 201,
    M_RIGHT = 202,
    SC_DOWN = 203,
    SC_UP = 204,
    count,
}

@(private = "file")
map_sdl_mousebutton :: proc(mouse_button: u8) -> Button {
    switch mouse_button {
    case 1:
        return .M_LEFT
    case 2:
        return .M_MIDDLE
    case 3:
        return .M_RIGHT
    }

    return .UNKNOWN
}

@(private = "file")
map_sdl_scrollwheel :: proc(scroll_value: f32) -> Button {
    if scroll_value < 0 {
        return .SC_DOWN
    } else if scroll_value > 0 {
        return .SC_UP
    } else do return .UNKNOWN
}

key_pressed :: proc(code: Button) -> bool {
    return .pressed in state.input.keys[code]
}

key_released :: proc(code: Button) -> bool {
    return .released in state.input.keys[code]
}

key_down :: proc(code: Button) -> bool {
    return .down in state.input.keys[code]
}

key_repeat :: proc(code: Button) -> bool {
    return .repeat in state.input.keys[code]
}

// consuming keys is a very helpful pattern that simplifies gameplay / UI input a shit ton
consume_key_pressed :: proc(code: Button) {
    state.input.keys[code] -= {.pressed}
}

consume_key_released :: proc(code: Button) {
    state.input.keys[code] -= {.released}
}

reset_input_state :: proc(input: ^InputState) {
    for &key in state.input.keys {
        key -= ~{.down} // clear all except down flag
    }
    state.input.scroll_y = 0
}

handle_sdl_events :: proc() {
    ev: sdl3.Event
    for sdl3.PollEvent(&ev) {
        #partial switch ev.type {
        case .QUIT:
            state.running = false

        case .MOUSE_MOTION:
            state.input.mouse_x = ev.motion.x
            state.input.mouse_y = ev.motion.y

        case .MOUSE_WHEEL:
            button := map_sdl_scrollwheel(ev.wheel.y)
            state.input.scroll_y = ev.wheel.y
            state.input.keys[button] += {.down, .pressed}

        case .MOUSE_BUTTON_UP:
            button := map_sdl_mousebutton(ev.button.button)
            if .down in state.input.keys[button] {
                state.input.keys[button] -= {.down}
                state.input.keys[button] += {.released}
            }

        case .MOUSE_BUTTON_DOWN:
            button := map_sdl_mousebutton(ev.button.button)
            if !(.down in state.input.keys[button]) {
                state.input.keys[button] += {.down, .pressed}
            }

        case .KEY_UP:
            if .down in state.input.keys[ev.key.scancode] {
                state.input.keys[ev.key.scancode] -= {.down}
                state.input.keys[ev.key.scancode] += {.released}
            }
        case .KEY_DOWN:
            if !ev.key.repeat &&
               !(.down in state.input.keys[ev.key.scancode]) {
                state.input.keys[ev.key.scancode] += {.down, .pressed}
            }
            if ev.key.repeat {
                state.input.keys[ev.key.scancode] += {.repeat}
            }
        }

    }
}
