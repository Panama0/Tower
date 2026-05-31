package main

import "vendor:sdl3"

Pivot :: enum {
    centre,
    top_left,
    top_right,
    bottom_left,
    bottom_right,
}

pivot_to_vec :: proc(p: Pivot) -> Vec2 {
    switch p {
    case .centre:
        return {0.5, 0.5}
    case .top_left:
        return {0.0, 0.0}
    case .top_right:
        return {1.0, 0.0}
    case .bottom_left:
        return {0.0, 1.0}
    case .bottom_right:
        return {1.0, 1.0}
    }

    return {-1, -1}
}

aabb_to_world :: proc(aabb: sdl3.FRect, point: Vec2) -> sdl3.FRect {
    return {point.x + aabb.x, point.y + aabb.y, aabb.w, aabb.h}
}

// draw a rect and reset the colour after
draw_rect :: proc(
    renderer: ^sdl3.Renderer,
    rect: ^sdl3.FRect,
    r: sdl3.Uint8,
    g: sdl3.Uint8,
    b: sdl3.Uint8,
    a: sdl3.Uint8 = 255,
) {
    old_r, old_g, old_b, old_a: sdl3.Uint8
    sdl3.GetRenderDrawColor(renderer, &old_r, &old_g, &old_b, &old_a)
    sdl3.SetRenderDrawColor(renderer, r, g, b, a)
    sdl3.RenderFillRect(renderer, rect)
    sdl3.SetRenderDrawColor(renderer, r, g, b, a)
}

// returns true if the timer is done and restarts it
timer_done_reset :: proc(timer: ^Timer) -> bool {
    current_time := sdl3.GetTicks()
    if current_time >= timer.next_done_time {
        timer.next_done_time = current_time + timer.interval_ms
        return true
    }

    return false
}
