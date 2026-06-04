package tests

import game "../src/"

import "core:testing"


@(test)
test_grid_get_grid_pos :: proc(t: ^testing.T) {
    grid := game.make_grid({0, 0}, 32)

    gp := game.grid_get_grid_pos(grid, game.Vec2{100, 100})
    testing.expect(t, gp == game.Vec2i{3, 3}, "positive pos")

    gp_neg := game.grid_get_grid_pos(grid, game.Vec2{-1, -1})
    testing.expect(t, gp_neg == game.Vec2i{-1, -1}, "negative pos")

    gp_boundary := game.grid_get_grid_pos(grid, game.Vec2{32, 64})
    testing.expect(t, gp_boundary == game.Vec2i{1, 2}, "boundary")

    gp_origin := game.grid_get_grid_pos(grid, game.Vec2{0, 0})
    testing.expect(t, gp_origin == game.Vec2i{0, 0}, "origin")
}

@(test)
test_grid_get_nearest_tl :: proc(t: ^testing.T) {
    grid := game.make_grid({0, 0}, 32)

    n := game.grid_get_nearest_tl(grid, game.Vec2{100, 100})
    testing.expect(t, n == game.Vec2{96, 96}, "positive pos")

    n_neg := game.grid_get_nearest_tl(grid, game.Vec2{-1, -1})
    testing.expect(t, n_neg == game.Vec2{-32, -32}, "negative pos")

    n_boundary := game.grid_get_nearest_tl(grid, game.Vec2{32, 64})
    testing.expect(t, n_boundary == game.Vec2{32, 64}, "boundary")

    n_origin := game.grid_get_nearest_tl(grid, game.Vec2{0, 0})
    testing.expect(t, n_origin == game.Vec2{0, 0}, "origin")
}

@(test)
test_grid_get_nearest_centre :: proc(t: ^testing.T) {
    grid := game.make_grid({0, 0}, 32)

    c := game.grid_get_nearest_centre(grid, game.Vec2{100, 100})
    testing.expect(t, c == game.Vec2{112, 112}, "positive pos")

    c_neg := game.grid_get_nearest_centre(grid, game.Vec2{-1, -1})
    testing.expect(t, c_neg == game.Vec2{-16, -16}, "negative pos")

    c_boundary := game.grid_get_nearest_centre(grid, game.Vec2{32, 64})
    testing.expect(t, c_boundary == game.Vec2{48, 80}, "boundary")

    c_origin := game.grid_get_nearest_centre(grid, game.Vec2{0, 0})
    testing.expect(t, c_origin == game.Vec2{16, 16}, "origin")
}

@(test)
test_grid_to_world_tl :: proc(t: ^testing.T) {
    grid := game.make_grid({0, 0}, 32)

    gw := game.grid_to_world_tl(grid, game.Vec2i{3, 3})
    testing.expect(t, gw == game.Vec2{96, 96}, "positive gp")

    gw_neg := game.grid_to_world_tl(grid, game.Vec2i{-1, -1})
    testing.expect(t, gw_neg == game.Vec2{-32, -32}, "negative gp")

    gw_boundary := game.grid_to_world_tl(grid, game.Vec2i{1, 2})
    testing.expect(t, gw_boundary == game.Vec2{32, 64}, "boundary")

    gw_origin := game.grid_to_world_tl(grid, game.Vec2i{0, 0})
    testing.expect(t, gw_origin == game.Vec2{0, 0}, "origin")
}

@(test)
test_grid_to_world_centre :: proc(t: ^testing.T) {
    grid := game.make_grid({0, 0}, 32)

    gw := game.grid_to_world_centre(grid, game.Vec2i{3, 3})
    testing.expect(t, gw == game.Vec2{112, 112}, "positive gp")

    gw_neg := game.grid_to_world_centre(grid, game.Vec2i{-1, -1})
    testing.expect(t, gw_neg == game.Vec2{-16, -16}, "negative gp")

    gw_boundary := game.grid_to_world_centre(grid, game.Vec2i{1, 2})
    testing.expect(t, gw_boundary == game.Vec2{48, 80}, "boundary")

    gw_origin := game.grid_to_world_centre(grid, game.Vec2i{0, 0})
    testing.expect(t, gw_origin == game.Vec2{16, 16}, "origin")
}

@(test)
test_grid_in_bounds :: proc(t: ^testing.T) {
    // 640x360 world with 16px squares -> grid_size = {40, 23}
    grid := game.make_grid({640, 360}, 16)

    testing.expect(t, game.grid_in_bounds(grid, {0, 0}), "origin")
    testing.expect(t, game.grid_in_bounds(grid, {10, 10}), "positive interior")
    testing.expect(t, game.grid_in_bounds(grid, {39, 0}), "max valid x")
    testing.expect(t, game.grid_in_bounds(grid, {0, 22}), "max valid y")
    testing.expect(t, game.grid_in_bounds(grid, {39, 22}), "max valid both")

    testing.expect(t, !game.grid_in_bounds(grid, {-1, 0}), "negative x")
    testing.expect(t, !game.grid_in_bounds(grid, {0, -1}), "negative y")
    testing.expect(t, !game.grid_in_bounds(grid, {40, 0}), "past max x")
    testing.expect(t, !game.grid_in_bounds(grid, {0, 23}), "past max y")
    testing.expect(t, !game.grid_in_bounds(grid, {-1, -1}), "both negative")
}

@(test)
test_grid_in_bounds_varying_sizes :: proc(t: ^testing.T) {
    grid := game.make_grid({100, 100}, 10)
    testing.expect(t, grid.grid_size == game.Vec2i{10, 10}, "10x10 grid size")

    testing.expect(t, game.grid_in_bounds(grid, {0, 0}), "origin")
    testing.expect(t, game.grid_in_bounds(grid, {9, 9}), "max index")
    testing.expect(t, !game.grid_in_bounds(grid, {10, 10}), "past max index")
    testing.expect(t, !game.grid_in_bounds(grid, {-1, 0}), "negative")
}

