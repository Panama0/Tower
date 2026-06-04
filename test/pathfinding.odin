package tests

import game "../src/"
import "core:fmt"
import "core:testing"

import "core:math"


@(test)
manhattan_distance :: proc(t: ^testing.T) {
    dist := game.manhattan(game.Vec2i{0, 0}, game.Vec2i{3, 4})
    testing.expect(
        t,
        dist == 7,
        "manhattan distance between (0,0) and (3,4) is 7",
    )

    dist = game.manhattan(game.Vec2i{-2, -3}, game.Vec2i{1, 1})
    testing.expect(t, dist == 7, "manhattan distance with negatives")

    dist = game.manhattan(game.Vec2i{0, 0}, game.Vec2i{0, 0})
    testing.expect(t, dist == 0, "manhattan distance from zero to zero")
}

@(test)
euclidian_heuristic :: proc(t: ^testing.T) {
    dist := game.octile(game.Vec2i{0, 0}, game.Vec2i{0, 1})
    testing.expect(t, dist == 1, "euclidian adjacent vertical")

    dist = game.octile(game.Vec2i{0, 0}, game.Vec2i{1, 1})
    testing.expect(t, dist == math.SQRT_TWO, "euclidian diagonal is sqrt2")

    dist = game.octile(game.Vec2i{0, 0}, game.Vec2i{2, 0})
    testing.expect(t, dist == 2, "euclidian two steps horizontal")

    dist = game.octile(game.Vec2i{0, 0}, game.Vec2i{2, 1})
    dx := f32(2)
    dy := f32(1)
    expected := (dx + dy) + (math.SQRT_TWO - 2) * math.min(dx, dy)
    testing.expect(
        t,
        dist == expected,
        "euclidian (2,1) matches octile formula",
    )
}

@(test)
node_less_comparison :: proc(t: ^testing.T) {
    n1 := game.Node {
        gCost = 5,
        hCost = 10,
    }
    n2 := game.Node {
        gCost = 10,
        hCost = 10,
    }
    n3 := game.Node {
        gCost = 5,
        hCost = 10,
    }

    testing.expect(
        t,
        game.node_less(&n1, &n2),
        "node with lower total cost is less",
    )
    testing.expect(
        t,
        !game.node_less(&n2, &n1),
        "node with higher total cost is not less",
    )
    testing.expect(t, !game.node_less(&n1, &n1), "equal nodes are not less")
    testing.expect(
        t,
        !game.node_less(&n1, &n3),
        "identical nodes are not less",
    )
}

@(test)
pathfinding_generate_and_delete_graph :: proc(t: ^testing.T) {
    // 640x360 world with 16px grid -> 40 columns * 23 rows = 920 nodes
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    testing.expect(t, graph.nodes != nil, "graph is not nil")
    testing.expect(
        t,
        len(graph.nodes) == 920,
        "graph has 920 nodes for 640x360 with grid 16",
    )

    grid2 := game.make_grid({100, 100}, 10)
    graph2 := game.pathfinding_generate_graph(grid2)
    defer game.pathfinding_delete_graph(graph2)

    testing.expect(
        t,
        len(graph2.nodes) == 100,
        "graph has 100 nodes for 100x100 with grid 10 (10*10)",
    )
}

@(test)
pathfinding_get_node_index :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    n := game.get_node(graph^, game.Vec2i{0, 0})
    testing.expect(
        t,
        n == &graph.nodes[0],
        "get_node (0,0) returns first node",
    )

    n = game.get_node(graph^, game.Vec2i{1, 0})
    testing.expect(
        t,
        n == &graph.nodes[1],
        "get_node (1,0) returns node at index 1",
    )

    n = game.get_node(graph^, game.Vec2i{0, 1})
    testing.expect(
        t,
        n == &graph.nodes[40],
        "get_node (0,1) returns node at index 40",
    )

    n = game.get_node(graph^, game.Vec2i{3, 2})
    testing.expect(
        t,
        n == &graph.nodes[83],
        "get_node (3,2) returns node at index 83 (2*40 + 3)",
    )
}

@(test)
find_path_open_terrain :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    waypoints := game.find_path({0, 0}, {100, 100}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) > 0, "path should exist on open terrain")

    start_centre := game.grid_to_world_centre(grid, {0, 0})
    end_centre := game.grid_to_world_centre(grid, {6, 6})
    testing.expect(
        t,
        waypoints[0] == start_centre,
        "first waypoint should be start cell centre",
    )
    testing.expect(
        t,
        waypoints[len(waypoints) - 1] == end_centre,
        "last waypoint should be end cell centre",
    )
}

@(test)
find_path_no_path :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    // Block all neighbors of the start cell so the enemy can't move
    start_cell := game.Vec2i{0, 0}
    for d in game.DIRECTIONS_INT {
        n := game.get_node(graph^, start_cell + d)
        if n != nil {
            n.impassible = true
        }
    }

    waypoints := game.find_path({0, 0}, {100, 100}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) == 0, "path should not exist when start is blocked")
}

@(test)
find_path_trivial :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    waypoints := game.find_path({0, 0}, {0, 0}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) == 1, "trivial path should return single waypoint")

    start_centre := game.grid_to_world_centre(grid, {0, 0})
    testing.expect(
        t,
        waypoints[0] == start_centre,
        "waypoint should be start cell centre",
    )
}

@(test)
find_path_detour :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    // Block cells along the direct vertical path
    for y in 4 ..= 6 {
        n := game.get_node(graph^, {0, i32(y)})
        if n != nil {
            n.impassible = true
        }
    }

    waypoints := game.find_path({8, 8}, {8, 168}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) > 1, "path should route around obstacles")

    // No waypoint should map to a blocked cell
    for wp in waypoints {
        gp := game.grid_get_grid_pos(grid, wp)
        if gp.x == 0 && gp.y >= 4 && gp.y <= 6 {
            testing.expect(t, false, "waypoint landed on blocked cell")
        }
    }
}

@(test)
find_path_does_not_mutate_graph :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    // Check state before
    testing.expect(
        t,
        graph.nodes[0].gCost == math.F32_MAX,
        "node gCost should be F32_MAX before pathfinding",
    )
    testing.expect(
        t,
        graph.nodes[0].parent == nil,
        "node parent should be nil before pathfinding",
    )

    waypoints := game.find_path({0, 0}, {100, 100}, graph^, game.octile)
    defer delete(waypoints)

    // Check state after — should be unchanged
    testing.expect(
        t,
        graph.nodes[0].gCost == math.F32_MAX,
        "node gCost should still be F32_MAX after pathfinding",
    )
    testing.expect(
        t,
        graph.nodes[0].parent == nil,
        "node parent should still be nil after pathfinding",
    )
}

@(test)
find_path_start_out_of_bounds :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    waypoints := game.find_path({-100, -100}, {0, 0}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(
        t,
        len(waypoints) == 0,
        "should return empty when start is out of bounds",
    )
}

@(test)
find_path_shortest_path_length :: proc(t: ^testing.T) {
    grid := game.make_grid({160, 160}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    // From (0,0) to (8,8) on open terrain — optimal is 8 diagonal steps
    waypoints := game.find_path({8, 8}, {136, 136}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(
        t,
        len(waypoints) == 9,
        "shortest path from (0,0) to (8,8) should be 9 waypoints",
    )

    start_centre := game.grid_to_world_centre(grid, {0, 0})
    end_centre := game.grid_to_world_centre(grid, {8, 8})
    testing.expect(
        t,
        waypoints[0] == start_centre,
        "first waypoint should be start",
    )
    testing.expect(
        t,
        waypoints[len(waypoints) - 1] == end_centre,
        "last waypoint should be end",
    )
}

@(test)
get_node_out_of_bounds :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    n := game.get_node(graph^, {-1, 0})
    testing.expect(t, n == nil, "get_node with negative x should return nil")

    n = game.get_node(graph^, {0, -1})
    testing.expect(t, n == nil, "get_node with negative y should return nil")

    n = game.get_node(graph^, {40, 0})
    testing.expect(t, n == nil, "get_node with x >= grid_size.x should return nil")

    n = game.get_node(graph^, {0, 23})
    testing.expect(t, n == nil, "get_node with y >= grid_size.y should return nil")
}
