package main

import "vendor:sdl3"


Direction :: enum {
    north,
    north_east,
    east,
    south_east,
    south,
    south_west,
    west,
    north_west,
}

direction_vectors: [Direction]Vec2 = {
    .north      = {0, -1},
    .north_east = {1, -1},
    .east       = {1, 0},
    .south_east = {1, 1},
    .south      = {0, 1},
    .south_west = {-1, 1},
    .west       = {-1, 0},
    .north_west = {-1, -1},
}

direction_vectors_int: [Direction]Vec2i = {
    .north      = {0, -1},
    .north_east = {1, -1},
    .east       = {1, 0},
    .south_east = {1, 1},
    .south      = {0, 1},
    .south_west = {-1, 1},
    .west       = {-1, 0},
    .north_west = {-1, -1},
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
