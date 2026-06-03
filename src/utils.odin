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


// returns true if the timer is done and restarts it
timer_done_reset :: proc(timer: ^Timer) -> bool {
    current_time := sdl3.GetTicks()
    if current_time >= timer.next_done_time {
        timer.next_done_time = current_time + timer.interval_ms
        return true
    }

    return false
}

point_in_circle :: proc(px, py, cx, cy, r: f32) -> bool {
    dx := px - cx
    dy := py - cy
    return dx * dx + dy * dy <= r * r
}

// provides a collider rect that covers the full sprite
default_collider :: proc(spr_width, spr_height: f32) -> sdl3.FRect {
    return {-(spr_width / 2), -(spr_height / 2), spr_width, spr_height}
}
