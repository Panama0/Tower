package main

import pq "core:container/priority_queue"
import "core:math"
import "core:math/linalg"
import "core:slice"

import "ecs"
import r "render"

import "vendor:sdl3"

PFTags :: enum {
    nil,
    impassible,
    road,
    goo,
}

tag_weights: [PFTags]f32 = {
    .nil        = 0,
    .impassible = -1,
    .road       = 0.5,
    .goo        = 2,
}

Node :: struct {
    parent:            ^Node,
    pos:               Vec2i,
    gCost:             f32,
    hCost:             f32,
    weight:            f32, // move cost
    blocking_entities: int, // how many entities are blocking the node
}

PathfindingGraph :: struct {
    nodes:          []Node,
    node_grid:      Grid,
    subject_bounds: sdl3.FRect, // need to store so that we can generate the graph and add entities
}

// debug draw the graph
pathfinding_draw_graph :: proc(renderer: r.Renderer, graph: PathfindingGraph) {
    impassable_color: [4]f32 = {255, 0, 0, 150} // red
    passable_color: [4]f32 = {0, 255, 0, 150} // green

    max: f32 = 2
    min: f32 = 0

    for node in graph.nodes {
        node_pos_world := grid_to_world_tl(graph.node_grid, node.pos)

        sq_size := graph.node_grid.sq_size
        cell_rect := sdl3.FRect {
            node_pos_world.x,
            node_pos_world.y,
            sq_size,
            sq_size,
        }

        // draw the nodes
        r.render_draw_rect(renderer, &cell_rect, 0, 0, 0, 255, false)

        // unweighted nodes can be ignored
        if node.weight != 0 {
            actual_weight := node.weight
            // weights under 0 are impassible, so have to set to max
            if node.weight < 0 {
                actual_weight = max
            } else {
                // clamp the value
                actual_weight = math.clamp(node.weight, min, max)
            }

            scalar := actual_weight / max

            t: [4]f32 = {scalar, scalar, scalar, 0}
            lerped := linalg.lerp(passable_color, impassable_color, t)

            // truncate to uint
            sdl_colour := cast([4]sdl3.Uint8)lerped

            r.render_draw_rect(
                renderer,
                &cell_rect,
                sdl_colour.r,
                sdl_colour.g,
                sdl_colour.b,
                sdl_colour.a,
            )
        }
    }
}

pathfinding_generate_graph :: proc(
    grid: Grid,
    bounds: sdl3.FRect = {},
    allocator := context.allocator,
    loc := #caller_location,
) -> ^PathfindingGraph {
    graph := new(PathfindingGraph)
    graph.node_grid = grid

    graph.nodes = make([]Node, grid.grid_size.x * grid.grid_size.y)
    graph.subject_bounds = bounds

    w := state.gs.world
    entities := ecs.get_entities_with(w, C_PathfindingTags)

    for &node, i in graph.nodes {
        // set g cost and pos
        node.pos = grid_index_to_grid(grid, i)
        node.gCost = math.F32_MAX
    }

    for e in entities {
        pathfinding_add_entity(graph, e)
    }


    return graph
}

// iterate over all cells an entity touches, callback for each node+tag
pathfinding_for_each_cell :: proc(
    graph: ^PathfindingGraph,
    e: ecs.Entity,
    cb: proc(node: ^Node, tag: PFTags),
) {
    w := state.gs.world
    transform := ecs.get_component(w, e, C_Transform)
    tags := ecs.get_component(w, e, C_PathfindingTags)

    world_rect := aabb_to_world(tags.bounds, transform.pos)

    // increase the size of the obstacle such that the entity doesn't get stuck
    if graph.subject_bounds.w != 0 || graph.subject_bounds.h != 0 {
        cell_size := graph.node_grid.sq_size
        bounds := graph.subject_bounds
        w := 0 if bounds.w <= cell_size else bounds.w
        h := 0 if bounds.h <= cell_size else bounds.h

        world_rect = {
            world_rect.x - w / 2,
            world_rect.y - h / 2,
            world_rect.w + w,
            world_rect.h + h,
        }
    }

    // epsilon needed to handle cell borders
    EPSILON :: 0.001

    // get the coords of the cells that define the rect
    gp := grid_get_grid_pos(graph.node_grid, {world_rect.x, world_rect.y})
    gp_max := grid_get_grid_pos(
        graph.node_grid,
        {
            world_rect.x + world_rect.w - EPSILON,
            world_rect.y + world_rect.h - EPSILON,
        },
    )

    // loop through the cells in the rect
    for y in gp.y ..= gp_max.y {
        for x in gp.x ..= gp_max.x {
            cell_gp := Vec2i{x, y}
            if !grid_in_bounds(graph.node_grid, cell_gp) do continue

            index := grid_to_index(graph.node_grid, cell_gp)
            node := &graph.nodes[index]

            for tag in tags.tags {
                cb(node, tag)
            }
        }
    }
}

// add a tagged entity to the graph
pathfinding_add_entity :: proc(graph: ^PathfindingGraph, e: ecs.Entity) {
    pathfinding_for_each_cell(graph, e, proc(node: ^Node, tag: PFTags) {
        node.weight += tag_weights[tag]
        if tag == .impassible do node.blocking_entities += 1
    })
}

// remove a tagged entity from the graph
pathfinding_remove_entity :: proc(graph: ^PathfindingGraph, e: ecs.Entity) {
    pathfinding_for_each_cell(graph, e, proc(node: ^Node, tag: PFTags) {
        node.weight -= tag_weights[tag]
        if tag == .impassible do node.blocking_entities -= 1
    })
}

pathfinding_delete_graph :: proc(graph: ^PathfindingGraph) {
    delete(graph.nodes)
    free(graph)
}


// heuristics
manhattan :: proc(source: Vec2i, dest: Vec2i) -> f32 {
    return f32(math.abs(source.x - dest.x) + math.abs(source.y - dest.y))
}

octile :: proc(source: Vec2i, dest: Vec2i) -> f32 {
    // length of each node
    D :: 1
    // diagonal distance between each node
    D2 :: math.SQRT_TWO

    dx := f32(math.abs(source.x - dest.x))
    dy := f32(math.abs(source.y - dest.y))

    return D * (dx + dy) + (D2 - 2 * D) * math.min(dx, dy)
}

// for prioqueue
@(private = "file")
node_less :: proc(lhs, rhs: ^Node) -> bool {
    return (lhs.gCost + lhs.hCost) < (rhs.gCost + rhs.hCost)
}

get_node :: proc(graph: PathfindingGraph, pos: Vec2i) -> (node: ^Node) {
    if !grid_in_bounds(graph.node_grid, pos) do return nil

    index := grid_to_index(graph.node_grid, pos)
    return &graph.nodes[index]
}

// A* pathfinding
find_path :: proc(
    start: Vec2,
    end: Vec2,
    graph: PathfindingGraph,
    heuristic: proc(source: Vec2i, dest: Vec2i) -> f32,
) -> [dynamic]Vec2 {
    // make a clone so that we can modify
    local_graph := PathfindingGraph {
        nodes          = slice.clone(graph.nodes),
        node_grid      = graph.node_grid,
        subject_bounds = graph.subject_bounds,
    }
    defer delete(local_graph.nodes)

    waypoints: [dynamic]Vec2

    open_list: pq.Priority_Queue(^Node)
    pq.init(&open_list, node_less, pq.default_swap_proc(^Node))
    defer pq.destroy(&open_list)

    closed_set: map[Vec2i]struct{}
    defer delete(closed_set)

    // get the grid positions of the input
    s := grid_get_grid_pos(local_graph.node_grid, start)
    e := grid_get_grid_pos(local_graph.node_grid, end)

    if !grid_in_bounds(local_graph.node_grid, s) do return {}

    // push the first node on
    start_node := get_node(local_graph, s)
    start_node.gCost = 0
    pq.push(&open_list, start_node)

    // find path
    for pq.len(open_list) > 0 {
        current_node := pq.pop(&open_list)

        // we found the path
        if current_node.pos == e {

            // walk back through and find the final path
            for current_node != nil {
                current_pos := grid_to_world_centre(
                    local_graph.node_grid,
                    current_node.pos,
                )
                append(&waypoints, current_pos)
                current_node = current_node.parent
            }

            // ignore root node
            pop(&waypoints)

            slice.reverse(waypoints[:])
            return waypoints
        }

        // add to closed set
        closed_set[current_node.pos] = {}

        // check all directions around current node
        for d in direction_vectors_int {
            next_pos := current_node.pos + d
            next_node := get_node(local_graph, next_pos)

            // ignore anything that is in the closed list
            if next_pos in closed_set do continue

            // if the node is not oob
            if next_node != nil && next_node.blocking_entities == 0 {

                dx := math.abs(current_node.pos.x - next_node.pos.x)
                dy := math.abs(current_node.pos.y - next_node.pos.y)

                // If diagonal, check the two adjacent cardinal cells
                if d.x != 0 && d.y != 0 {
                    card1 := current_node.pos + Vec2i{d.x, 0}
                    card2 := current_node.pos + Vec2i{0, d.y}
                    n1 := get_node(local_graph, card1)
                    n2 := get_node(local_graph, card2)
                    if n1 == nil ||
                       n1.blocking_entities > 0 ||
                       n2 == nil ||
                       n2.blocking_entities > 0 {
                        continue // skip this diagonal — would clip the corner
                    }
                }

                // account for diagonal movement costing more
                base_move_cost: f32 = 1.0
                if dx == 1 && dy == 1 do base_move_cost *= math.SQRT_TWO

                new_g := current_node.gCost + base_move_cost + next_node.weight

                // if this is the best path to this node so far, save it
                if new_g < next_node.gCost {
                    next_node.gCost = new_g
                    next_node.hCost = heuristic(next_node.pos, e)
                    next_node.parent = current_node

                    pq.push(&open_list, next_node)
                }
            }
        }
    }


    return waypoints
}

// system
pathfinding :: proc(graph: ^PathfindingGraph) {
    w := state.gs.world
    finders := ecs.get_entities_with(w, C_PathFollower)

    for e in finders {
        transform := ecs.get_component(w, e, C_Transform)
        follower := ecs.get_component(w, e, C_PathFollower)

        if !ecs.is_alive(w, follower.target) do continue

        // gen paths
        target_pos := ecs.get_component(w, follower.target, C_Transform).pos
        // update waypoints
        waypoints := find_path(transform.pos, target_pos, graph^, octile)
        delete(follower.waypoints)
        follower.waypoints = waypoints[:]
        follower.current_waypoint = 0
    }
}
