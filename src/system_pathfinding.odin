package main

import pq "core:container/priority_queue"
import "core:math"
import "core:slice"

import "ecs"

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
    parent:     ^Node,
    pos:        Vec2i,
    gCost:      f32,
    hCost:      f32,
    weight:     f32, // move cost
    impassible: bool,
}

PathfindingGraph :: struct {
    nodes:     []Node,
    node_grid: Grid,
}

// debug draw the graph
pathfinding_draw_graph :: proc(
    renderer: ^sdl3.Renderer,
    graph: PathfindingGraph,
) {

    for node in graph.nodes {
        node_pos_world := grid_to_world_tl(graph.node_grid, node.pos)

        sq_size := graph.node_grid.sq_size
        cell_rect := sdl3.FRect {
            node_pos_world.x,
            node_pos_world.y,
            sq_size,
            sq_size,
        }

        // determine colour
        a: sdl3.Uint8 = 100
        for weight, tag in tag_weights {
            if node.weight == weight {
                switch tag {
                case .nil:
                case .impassible:
                    draw_rect(renderer, &cell_rect, 255, 0, 0, a)
                case .road:
                    draw_rect(renderer, &cell_rect, 0, 255, 0, a)
                case .goo:
                    draw_rect(renderer, &cell_rect, 0, 0, 255, a)
                }
            }
        }

    }
}

pathfinding_generate_graph :: proc(
    grid: Grid,
    allocator := context.allocator,
    loc := #caller_location,
) -> ^PathfindingGraph {
    graph := new(PathfindingGraph)
    graph.node_grid = grid

    graph.nodes = make([]Node, grid.grid_size.x * grid.grid_size.y)

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

// add a tagged entity to the graph
pathfinding_add_entity :: proc(graph: ^PathfindingGraph, e: ecs.Entity) {

    w := state.gs.world
    transform := ecs.get_component(w, e, C_Transform)
    tags := ecs.get_component(w, e, C_PathfindingTags)

    world_rect := aabb_to_world(tags.bounds, transform.pos)

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
                node.weight += tag_weights[tag]
                if tag == .impassible do node.impassible = true
            }
        }
    }

}

// remove a tagged entity from the graph
pathfinding_remove_entity :: proc(graph: ^PathfindingGraph, e: ecs.Entity) {

}

pathfinding_delete_graph :: proc(graph: ^PathfindingGraph) {
    delete(graph.nodes)
    free(graph)
}

// for prioqueue
node_less :: proc(lhs, rhs: ^Node) -> bool {
    return (lhs.gCost + lhs.hCost) < (rhs.gCost + rhs.hCost)
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
    local_graph := PathfindingGraph{slice.clone(graph.nodes), graph.node_grid}
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

            slice.reverse(waypoints[:])
            return waypoints
        }

        // add to closed set
        closed_set[current_node.pos] = {}

        // check all directions around current node
        for d in DIRECTIONS_INT {
            next_pos := current_node.pos + d
            next_node := get_node(local_graph, next_pos)

            // ignore anything that is in the closed list
            if next_pos in closed_set do continue

            // if the node is not oob
            if next_node != nil && !next_node.impassible {
                // account for diagonal movement costing more
                base_move_cost: f32 = 1.0
                dx := math.abs(current_node.pos.x - next_node.pos.x)
                dy := math.abs(current_node.pos.y - next_node.pos.y)
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
