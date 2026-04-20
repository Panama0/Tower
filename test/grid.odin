package tests

import game "../src/"

import "core:testing"


@(test)
grid_get_grid_pos :: proc(t: ^testing.T) {
    sq_size: f32 = 32

    gp := game.grid_get_grid_pos(sq_size, game.Vec2{100, 100})
    testing.expect(t, gp == game.Vec2i{3, 3}, "positive pos")

    gp_neg := game.grid_get_grid_pos(sq_size, game.Vec2{-1, -1})
    testing.expect(t, gp_neg == game.Vec2i{-1, -1}, "negative pos")

    gp_boundary := game.grid_get_grid_pos(sq_size, game.Vec2{32, 64})
    testing.expect(t, gp_boundary == game.Vec2i{1, 2}, "boundary")

    gp_origin := game.grid_get_grid_pos(sq_size, game.Vec2{0, 0})
    testing.expect(t, gp_origin == game.Vec2i{0, 0}, "origin")
}

@(test)
grid_get_nearest :: proc(t: ^testing.T) {
    sq_size: f32 = 32

    n := game.grid_get_nearest(sq_size, game.Vec2{100, 100})
    testing.expect(t, n == game.Vec2{96, 96}, "positive pos")

    n_neg := game.grid_get_nearest(sq_size, game.Vec2{-1, -1})
    testing.expect(t, n_neg == game.Vec2{-32, -32}, "negative pos")

    n_boundary := game.grid_get_nearest(sq_size, game.Vec2{32, 64})
    testing.expect(t, n_boundary == game.Vec2{32, 64}, "boundary")

    n_origin := game.grid_get_nearest(sq_size, game.Vec2{0, 0})
    testing.expect(t, n_origin == game.Vec2{0, 0}, "origin")
}

@(test)
grid_get_nearest_centre :: proc(t: ^testing.T) {
    sq_size: f32 = 32

    c := game.grid_get_nearest_centre(sq_size, game.Vec2{100, 100})
    testing.expect(t, c == game.Vec2{112, 112}, "positive pos")

    c_neg := game.grid_get_nearest_centre(sq_size, game.Vec2{-1, -1})
    testing.expect(t, c_neg == game.Vec2{-16, -16}, "negative pos")

    c_boundary := game.grid_get_nearest_centre(sq_size, game.Vec2{32, 64})
    testing.expect(t, c_boundary == game.Vec2{48, 80}, "boundary")

    c_origin := game.grid_get_nearest_centre(sq_size, game.Vec2{0, 0})
    testing.expect(t, c_origin == game.Vec2{16, 16}, "origin")
}