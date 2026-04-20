package main

import "core:log"
import "core:math"

import "vendor:sdl3"

grid_get_nearest_centre :: proc(sq_size: f32, pos: Vec2) -> Vec2 {
    top_left := grid_get_nearest(sq_size, pos)
    return top_left + {sq_size / 2, sq_size / 2}
}

// top left
grid_get_nearest :: proc(sq_size: f32, pos: Vec2) -> Vec2 {
    gp := grid_get_grid_pos(sq_size, pos)
    return {f32(gp.x) * sq_size, f32(gp.y) * sq_size}
}

grid_get_grid_pos :: proc(sq_size: f32, pos: Vec2) -> Vec2i {
    gp_x := pos.x / sq_size
    gp_y := pos.y / sq_size
    return {i32(math.floor(gp_x)), i32(math.floor(gp_y))}
}

grid_draw :: proc(renderer: ^sdl3.Renderer, sq_size: f32, world_size: Vec2) {

    max := grid_get_grid_pos(sq_size, world_size)

    // red
    sdl3.SetRenderDrawColor(renderer, 255, 0, 0, 255)

    // horizontal
    for i in 0 ..= max.y {
        y_level := sq_size * f32(i)
        sdl3.RenderLine(renderer, 0, y_level, world_size.x, y_level)
    }

    // vertical
    for i in 0 ..= max.x {
        x_level := sq_size * f32(i)
        sdl3.RenderLine(renderer, x_level, 0, x_level, world_size.y)
    }
}
