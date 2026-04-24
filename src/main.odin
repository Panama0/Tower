#+ feature dynamic-literals
package main

import "core:log"
import "core:math/linalg"

import "ecs"

import "vendor:sdl3"

Vec2 :: [2]f32
Vec2i :: [2]i32

SpriteName :: enum {
    nil,
    player,
    tile1,
    tile2,
    tile3,
    tile4,
    animtest,
    knight_idle,
    knight_walk,
}

sprite_data: [SpriteName]Sprite_Data = #partial {
    .animtest = {frame_count = 3},
    .knight_idle = {frame_count = 7},
    .knight_walk = {frame_count = 8},
}

// maybe not needed - just make an int?
Sprite_Data :: struct {
    frame_count: int,
    // offset:      Vec2,
    // pivot:       utils.Pivot,
}

MAX_ENTITIES :: 1024
GRID_SIZE :: 32

State :: struct {
    gs:               GameState,
    dt:               f32,
    running:          bool,
    input:            InputState,
    occurred_actions: [Action]bool,
    atlas:            Atlas,
    sprites:          [SpriteName]Sprite,
}

GameState :: struct {
    ticks:            u64,
    cam_pos:          Vec2,
    world:            ^ecs.World,
    entity_free_list: [dynamic]ecs.Entity,
    player:           ecs.Entity,
}

state: State


Action :: enum {
    left,
    right,
    up,
    down,
    exit,
    place_tower,
    rotate,
}

action_bindings: map[Bind]Action = {
    {.W, .down} = .up,
    {.A, .down} = .left,
    {.S, .down} = .down,
    {.D, .down} = .right,
    {.ESCAPE, .pressed} = .exit,
    {.M_LEFT, .pressed} = .place_tower,
    {.R, .pressed} = .rotate,
}

action_occurred :: proc(action: Action) -> bool {
    return state.occurred_actions[action]
}

spawn_player :: proc() -> ecs.Entity {
    w := state.gs.world
    e := ecs.add_entity(w)
    state.gs.player = e

    transform := ecs.add_component(w, e, C_Transform)
    transform.pos = {120, 120}

    spr := ecs.add_component(w, e, C_Sprite)
    spr.name = .knight_idle

    anim := ecs.add_component(w, e, C_Animation)
    anim.frame_duration_ms = 150
    anim.loop = true

    return e
}

spawn_tower :: proc(pos: Vec2) -> ecs.Entity {
    w := state.gs.world
    e := ecs.add_entity(w)

    transform := ecs.add_component(w, e, C_Transform)
    transform.pos = pos

    spr := ecs.add_component(w, e, C_Sprite)
    spr.name = .tile1

    timer := ecs.add_component(w, e, C_Tower)
    timer.interval_ms = 300

    return e
}


spawn_spawner :: proc(pos: Vec2) -> ecs.Entity {
    w := state.gs.world
    e := ecs.add_entity(w)

    transform := ecs.add_component(w, e, C_Transform)
    transform.pos = pos

    spr := ecs.add_component(w, e, C_Sprite)
    spr.name = .tile4

    timer := ecs.add_component(w, e, C_Spawner)
    timer.interval_ms = 500

    return e
}

spawn_enemy :: proc(pos: Vec2) -> ecs.Entity {
    w := state.gs.world
    e := ecs.add_entity(w)

    ecs.add_component(w, e, C_Enemy)

    transform := ecs.add_component(w, e, C_Transform)
    transform.pos = pos

    spr := ecs.add_component(w, e, C_Sprite)
    spr.name = .animtest

    anim := ecs.add_component(w, e, C_Animation)
    anim.frame_duration_ms = 150
    anim.loop = true

    return e
}

spawn_bullet :: proc(pos: Vec2) -> ecs.Entity {
    w := state.gs.world
    e := ecs.add_entity(w)

    transform := ecs.add_component(w, e, C_Transform)
    transform.pos = pos

    spr := ecs.add_component(w, e, C_Sprite)
    spr.name = .player

    anim := ecs.add_component(w, e, C_Animation)
    anim.frame_duration_ms = 150
    anim.loop = true

    bullet := ecs.add_component(w, e, C_Projectile)

    return e
}

main :: proc() {
    context.logger = log.create_console_logger()

    WINDOW_WIDTH :: 640
    WINDOW_HEIGHT :: 360

    ok := sdl3.Init({.VIDEO})
    if !ok do log.fatalf("Could not initialise SDL: %v", sdl3.GetError())

    window: ^sdl3.Window
    renderer: ^sdl3.Renderer
    sdl3.CreateWindowAndRenderer(
        "hi",
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        {},
        &window,
        &renderer,
    )

    // we can do stretching/letterbox via
    sdl3.SetRenderLogicalPresentation(
        renderer,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        .INTEGER_SCALE,
    )

    // init "renderer"
    load_sprites_and_atlas(renderer)

    // init game stuff
    state.gs.world = ecs.make_world()
    state.gs.player = spawn_player()

    // temp
    spawn_spawner({450, 150})


    last_tick: u64 = sdl3.GetTicks()
    current_tick: u64

    state.running = true
    for state.running {
        last_tick = current_tick
        current_tick = sdl3.GetTicks()

        state.dt = f32(current_tick - last_tick) / 1000

        handle_sdl_events()


        // register actions
        for bind, action in action_bindings {
            check: proc(code: Button) -> bool

            switch bind.activator {
            case .down:
                check = key_down
            case .pressed:
                check = key_pressed
            case .released:
                check = key_released
            case .repeat:
                check = key_repeat
            }

            if check(bind.button) do state.occurred_actions[action] = true
        }

        // updates

        if action_occurred(.exit) {
            state.running = false
        }

        if action_occurred(.place_tower) {
            world_x, world_y: f32
            // not sure if this is right
            sdl3.RenderCoordinatesFromWindow(
                renderer,
                state.input.mouse_x,
                state.input.mouse_y,
                &world_x,
                &world_y,
            )

            spawn_tower(grid_get_nearest_centre(GRID_SIZE, {world_x, world_y}))
        }

        if action_occurred(.rotate) {
            // player.rotation_deg += 10
            transform := ecs.get_component(
                state.gs.world,
                state.gs.player,
                C_Transform,
            )
            transform.rotation_deg += 10
        }

        // update ent
        w := state.gs.world

        // movement for player
        //TODO: This could be better for sure
        input: Vec2
        idle := true
        if action_occurred(.left) {
            input.x -= 1.0
        }

        if action_occurred(.right) {
            input.x += 1.0
        }

        if action_occurred(.down) {
            input.y += 1.0
        }

        if action_occurred(.up) {
            input.y -= 1.0
        }

        if input != {} {
            input = linalg.normalize(input)
            idle = false
        }
        transform := ecs.get_component(w, state.gs.player, C_Transform)
        transform.pos += input * 100.0 * state.dt

        // animations
        animated := ecs.get_entities_with(w, C_Animation)
        for e in animated {
            animation(e)
        }

        // enemies
        enemy()

        // tower
        towers()

        // spawner
        spawner()

        // projectile
        projectile()


        // draw
        sdl3.SetRenderDrawColor(renderer, 245, 235, 220, 255)
        sdl3.RenderClear(renderer)

        draw_sprites(renderer)

        grid_draw(renderer, GRID_SIZE, {WINDOW_WIDTH, WINDOW_HEIGHT})

        sdl3.RenderPresent(renderer)

        state.gs.ticks += 1

        reset_input_state(&state.input)
        state.occurred_actions = {}
        free_all(context.temp_allocator)
    }

    sdl3.DestroyRenderer(renderer)
    sdl3.DestroyWindow(window)
    sdl3.Quit()
}
