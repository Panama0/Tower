package main

import "vendor:sdl3"

Pivot :: enum {
    centre,
    top_left,
    top_right,
    bottom_left,
    bottom_right,
}

DIRECTIONS :: [?]Vec2 {
    {0, -1}, // North
    {1, -1}, // North-East
    {1, 0}, // East
    {1, 1}, // South-East
    {0, 1}, // South
    {-1, 1}, // South-West
    {-1, 0}, // West
    {-1, -1}, // North-West
}

DIRECTIONS_INT :: [?]Vec2i {
    {0, -1},
    {1, -1},
    {1, 0},
    {1, 1},
    {0, 1},
    {-1, 1},
    {-1, 0},
    {-1, -1},
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

point_in_circle :: proc(
    point: Vec2,
    circle_origin: Vec2,
    circle_r: f32,
) -> bool {
    dx := point.x - circle_origin.x
    dy := point.y - circle_origin.y
    return dx * dx + dy * dy <= circle_r * circle_r
}

// provides a collider rect that covers the full sprite
default_collider :: proc(spr_width, spr_height: f32) -> sdl3.FRect {
    return {-(spr_width / 2), -(spr_height / 2), spr_width, spr_height}
}

rects_intersect :: proc(first, second: sdl3.FRect) -> bool {
    return(
        (first.x < second.x + second.w) &&
        (first.x + first.w > second.x) &&
        (first.y < second.y + second.h) &&
        (first.y + first.h > second.y) \
    )
}
