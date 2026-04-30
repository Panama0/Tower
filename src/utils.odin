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
