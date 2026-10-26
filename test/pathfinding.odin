package tests

import game "../src/"
import ecs "../src/ecs"
import "core:slice"
import "core:testing"

import "core:math"

// Graph generation reads this world; tests only mutate their own graphs.
pathfinding_test_world: ecs.World

@(init)
init_pathfinding_test_world :: proc "contextless" () {
    game.state.gs.world = &pathfinding_test_world
}


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
octile_heuristic :: proc(t: ^testing.T) {
    dist := game.octile(game.Vec2i{0, 0}, game.Vec2i{0, 1})
    testing.expect(t, dist == 1, "octile adjacent vertical")

    dist = game.octile(game.Vec2i{0, 0}, game.Vec2i{1, 1})
    testing.expect(t, dist == math.SQRT_TWO, "octile diagonal is sqrt2")

    dist = game.octile(game.Vec2i{0, 0}, game.Vec2i{2, 0})
    testing.expect(t, dist == 2, "octile two steps horizontal")

    dist = game.octile(game.Vec2i{0, 0}, game.Vec2i{2, 1})
    dx := f32(2)
    dy := f32(1)
    expected := (dx + dy) + (math.SQRT_TWO - 2) * math.min(dx, dy)
    testing.expect(
        t,
        dist == expected,
        "octile (2,1) matches octile formula",
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
    if len(waypoints) == 0 do return

    first_cell := game.grid_get_grid_pos(grid, waypoints[0])
    end_centre := game.grid_to_world_centre(grid, {6, 6})
    testing.expect(
        t,
        first_cell != game.Vec2i{0, 0} &&
        math.abs(first_cell.x) <= 1 && math.abs(first_cell.y) <= 1,
        "first waypoint should be adjacent to, but exclude, the start cell",
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
    for d in game.direction_vectors_int {
        n := game.get_node(graph^, start_cell + d)
        if n != nil {
            n.blocking_entities = 1
        }
    }

    waypoints := game.find_path({0, 0}, {100, 100}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) == 0, "path should not exist when start is surrounded")
}

@(test)
find_path_trivial :: proc(t: ^testing.T) {
    grid := game.make_grid({640, 360}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    waypoints := game.find_path({0, 0}, {0, 0}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) == 0, "trivial path has no steps after excluding start")
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
            n.blocking_entities = 1
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

    game.get_node(graph^, {1, 0}).weight = 2
    game.get_node(graph^, {2, 0}).blocking_entities = 1
    before := slice.clone(graph.nodes)
    defer delete(before)

    waypoints := game.find_path({0, 0}, {100, 100}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) > 0, "search should find a path")
    for node, i in graph.nodes {
        testing.expect(t, node == before[i], "search should leave every node unchanged")
    }
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
        len(waypoints) == 8,
        "shortest path from (0,0) to (8,8) should be 8 waypoints excluding start",
    )
    if len(waypoints) != 8 do return

    end_centre := game.grid_to_world_centre(grid, {8, 8})
    for wp, i in waypoints {
        cell := game.Vec2i{i32(i + 1), i32(i + 1)}
        testing.expect(t, wp == game.grid_to_world_centre(grid, cell), "each step should be diagonal")
    }
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

@(test)
find_path_diagonal_corner_blocking :: proc(t: ^testing.T) {
    grid := game.make_grid({32, 32}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    // Either cardinal neighbor alone must prevent a direct diagonal step.
    corners := [2]game.Vec2i{{1, 0}, {0, 1}}
    for blocked in corners {
        node := game.get_node(graph^, blocked)
        node.blocking_entities = 1

        waypoints := game.find_path({8, 8}, {24, 24}, graph^, game.octile)
        testing.expect(t, len(waypoints) == 2, "one blocked corner requires two cardinal steps")
        if len(waypoints) == 2 {
            first := game.grid_get_grid_pos(grid, waypoints[0])
            testing.expect(t, first == game.Vec2i{1, 1} - blocked, "first step uses the unblocked neighbor")
            testing.expect(t, waypoints[1] == game.Vec2{24, 24}, "detour should reach destination")
        }
        delete(waypoints)
        node.blocking_entities = 0
    }

    game.get_node(graph^, {1, 0}).blocking_entities = 1
    game.get_node(graph^, {0, 1}).blocking_entities = 1
    waypoints := game.find_path({8, 8}, {24, 24}, graph^, game.octile)
    defer delete(waypoints)
    testing.expect(t, len(waypoints) == 0, "cannot squeeze diagonally between blocked neighbors")
}

@(test)
find_path_weighted_terrain :: proc(t: ^testing.T) {
    grid := game.make_grid({80, 80}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    // The direct route is two steps; avoiding the expensive cell takes six.
    game.get_node(graph^, {2, 2}).weight = 10
    game.get_node(graph^, {2, 1}).blocking_entities = 1
    game.get_node(graph^, {2, 3}).blocking_entities = 1
    waypoints := game.find_path({24, 40}, {56, 40}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) == 6, "should choose the longer, cheaper route")
    if len(waypoints) != 6 do return

    cost: f32
    previous := game.Vec2i{1, 2}
    for wp in waypoints {
        cell := game.grid_get_grid_pos(grid, wp)
        node := game.get_node(graph^, cell)
        delta := cell - previous
        testing.expect(t, node.blocking_entities == 0, "route should avoid blocked cells")
        testing.expect(t, cell != game.Vec2i{2, 2}, "route should avoid the expensive cell")
        testing.expect(t, math.abs(delta.x) + math.abs(delta.y) == 1, "detour should use cardinal steps")
        cost += 1 + node.weight
        previous = cell
    }
    testing.expect(t, cost == 6, "detour should cost six instead of twelve")
    testing.expect(t, previous == game.Vec2i{3, 2}, "route should reach destination")
}

@(test)
find_path_end_out_of_bounds :: proc(t: ^testing.T) {
    grid := game.make_grid({32, 32}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    destinations := [4]game.Vec2{{-16, 8}, {8, -16}, {32, 8}, {8, 32}}
    for end in destinations {
        waypoints := game.find_path({8, 8}, end, graph^, game.octile)
        testing.expect(t, len(waypoints) == 0, "out-of-bounds destination should return no path")
        delete(waypoints)
    }
}

@(test)
find_path_blocked_destination :: proc(t: ^testing.T) {
    grid := game.make_grid({48, 48}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    game.get_node(graph^, {2, 2}).blocking_entities = 1
    waypoints := game.find_path({8, 8}, {40, 40}, graph^, game.octile)
    defer delete(waypoints)
    testing.expect(t, len(waypoints) == 0, "blocked destination should return no path")
}

@(test)
find_path_escape_blocked_start :: proc(t: ^testing.T) {
    grid := game.make_grid({48, 16}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    game.get_node(graph^, {0, 0}).blocking_entities = 1
    waypoints := game.find_path({8, 8}, {40, 8}, graph^, game.octile)
    defer delete(waypoints)

    testing.expect(t, len(waypoints) == 2, "should allow escape from a blocked start")
    if len(waypoints) != 2 do return
    testing.expect(t, waypoints[0] == game.Vec2{24, 8}, "first step should leave the blocked cell")
    testing.expect(t, waypoints[1] == game.Vec2{40, 8}, "escape path should reach destination")
}

@(test)
find_path_repeated_searches :: proc(t: ^testing.T) {
    grid := game.make_grid({80, 80}, 16)
    graph := game.pathfinding_generate_graph(grid)
    defer game.pathfinding_delete_graph(graph)

    game.get_node(graph^, {2, 2}).blocking_entities = 1
    first := game.find_path({8, 8}, {72, 72}, graph^, game.octile)
    defer delete(first)
    testing.expect(t, len(first) > 0, "initial search should find a path")

    reverse := game.find_path({72, 72}, {8, 8}, graph^, game.octile)
    defer delete(reverse)
    testing.expect(t, len(reverse) > 0, "reverse search should find a path")
    if len(reverse) > 0 {
        testing.expect(t, reverse[len(reverse) - 1] == game.Vec2{8, 8}, "reverse search should reach its destination")
    }

    repeated := game.find_path({8, 8}, {72, 72}, graph^, game.octile)
    defer delete(repeated)
    testing.expect(t, len(repeated) == len(first), "repeated search should have the same length")
    if len(repeated) != len(first) do return
    for wp, i in repeated {
        testing.expect(t, wp == first[i], "intervening search should not change the repeated path")
    }
}
