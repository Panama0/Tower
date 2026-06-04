package main

import "core:log"
import "core:math"

import "vendor:sdl3"

Grid :: struct {
    world_size: Vec2,
    sq_size:    f32,
    grid_size:  Vec2i,
}

make_grid :: proc(worldsize: Vec2, square_size: f32) -> (g: Grid) {
    g.world_size = worldsize
    g.sq_size = square_size

    grid_width := i32(math.ceil(worldsize.x / square_size))
    grid_height := i32(math.ceil(worldsize.y / square_size))

    g.grid_size = {grid_width, grid_height}

    return g
}

grid_get_nearest_centre :: proc(g: Grid, pos: Vec2) -> Vec2 {
    top_left := grid_get_nearest_tl(g, pos)
    return top_left + {g.sq_size / 2, g.sq_size / 2}
}

grid_get_nearest_tl :: proc(g: Grid, pos: Vec2) -> Vec2 {
    gp := grid_get_grid_pos(g, pos)
    return {f32(gp.x) * g.sq_size, f32(gp.y) * g.sq_size}
}

grid_get_grid_pos :: proc(g: Grid, pos: Vec2) -> Vec2i {
    gp_x := pos.x / g.sq_size
    gp_y := pos.y / g.sq_size
    return {i32(math.floor(gp_x)), i32(math.floor(gp_y))}
}

grid_to_world_tl :: proc(g: Grid, gp: Vec2i) -> Vec2 {
    return {f32(gp.x) * g.sq_size, f32(gp.y) * g.sq_size}
}

grid_to_world_centre :: proc(g: Grid, gp: Vec2i) -> Vec2 {
    gp := Vec2{f32(gp.x) * g.sq_size, f32(gp.y) * g.sq_size}
    return gp + {g.sq_size / 2, g.sq_size / 2}
}

// get the index that the grid square would have in a 1d array
grid_to_index :: proc(g: Grid, gp: Vec2i) -> i32 {
    return g.grid_size.x * gp.y + gp.x
}

grid_index_to_grid :: proc(g: Grid, index: int) -> Vec2i {
    return {i32(index) % g.grid_size.x, i32(index) / g.grid_size.x}
}

grid_in_bounds :: proc(g: Grid, gp: Vec2i) -> bool {
    return(
        gp.x >= 0 &&
        gp.y >= 0 &&
        gp.x < g.grid_size.x &&
        gp.y < g.grid_size.y \
    )
}

grid_draw :: proc(renderer: ^sdl3.Renderer, g: Grid) {

    max := grid_get_grid_pos(g, g.world_size)

    // red
    sdl3.SetRenderDrawColor(renderer, 255, 0, 0, 255)

    // horizontal
    for i in 0 ..= max.y {
        y_level := g.sq_size * f32(i)
        sdl3.RenderLine(renderer, 0, y_level, g.world_size.x, y_level)
    }

    // vertical
    for i in 0 ..= max.x {
        x_level := g.sq_size * f32(i)
        sdl3.RenderLine(renderer, x_level, 0, x_level, g.world_size.y)
    }
}
