#+ feature dynamic-literals
package main

import "core:log"
import "core:math/linalg"

import sdl3 "vendor:sdl3"

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
    // game_time_elapsed: f64,
    cam_pos:          Vec2,
    entity_top_count: int,
    latest_entity_id: int,
    entities:         [MAX_ENTITIES]Entity,
    entity_free_list: [dynamic]int,
    player_handle:    EntityHandle,
    scratch:          struct {
        all_entities: []EntityHandle,
    },
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

EntityKind :: enum {
    nil,
    player,
    tower,
    spawner,
    enemy,
    bullet,
}

entity_setup :: proc(e: ^Entity, kind: EntityKind) {
    // entity defaults
    e.draw_proc = nil //FIX: fix
    e.sprite = .tile1

    // e.draw_pivot = .bottom_center

    switch kind {
    case .nil:
    case .player:
        setup_player(e)
    case .tower:
        setup_tower(e)
    case .spawner:
        setup_spawner(e)
    case .enemy:
        setup_enemy(e)
    case .bullet:
        setup_bullet(e)
    }
}

setup_player :: proc(e: ^Entity) {
    e.kind = .player
    e.pos = {120, 120}

    e.update_proc = proc(e: ^Entity) {
        last: Action
        idle := true

        // input
        input: Vec2
        if action_occurred(.left) {
            input.x -= 1.0
            last = .left
        }

        if action_occurred(.right) {
            input.x += 1.0
            last = .right
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

        e.pos += input * 100.0 * state.dt

        // animations
        if !idle {
            entity_set_animation(e, .knight_walk, 150)
            #partial switch last {
            case .left:
                e.flip_x = true
            case .right:
                e.flip_x = false
            }
        } else {
            entity_set_animation(e, .knight_idle, 150)
        }
    }

    e.draw_proc = proc(e: Entity, renderer: ^sdl3.Renderer) {
        draw_ent(e, renderer)
    }
}

setup_tower :: proc(e: ^Entity) {
    e.kind = .tower
    e.sprite = .tile1

    e.shoot_interval_ms = 300

    e.update_proc = proc(e: ^Entity) {
        current_time := sdl3.GetTicks()
        if current_time >= e.next_shot_time {
            bullet := entity_create(.bullet)
            bullet.pos = e.pos

            //TODO: make this an enemy!
            target := player().pos

            bullet.direction = linalg.normalize(target - e.pos)
            bullet.speed = 200

            e.next_shot_time = current_time + e.shoot_interval_ms
        }
    }

    e.draw_proc = proc(e: Entity, renderer: ^sdl3.Renderer) {
        draw_ent(e, renderer)
    }
}

setup_spawner :: proc(e: ^Entity) {
    e.kind = .spawner
    e.sprite = .tile4

    e.spawn_interval_ms = 500

    e.update_proc = proc(e: ^Entity) {
        current_time := sdl3.GetTicks()
        if current_time >= e.next_spawn_time {
            // spawn an enemy
            enemy := entity_create(.enemy)
            enemy.pos = e.pos

            // set next spawn time
            e.next_spawn_time = current_time + e.spawn_interval_ms
        }
    }

    e.draw_proc = proc(e: Entity, renderer: ^sdl3.Renderer) {
        draw_ent(e, renderer)
    }
}

setup_enemy :: proc(e: ^Entity) {
    e.kind = .spawner
    e.sprite = .animtest
    entity_set_animation(e, .animtest, 150)

    e.update_proc = proc(e: ^Entity) {
        // move towards the player
        player_pos := player().pos

        move_dir := linalg.normalize(player_pos - e.pos)

        e.pos += move_dir * 75 * state.dt
    }

    e.draw_proc = proc(e: Entity, renderer: ^sdl3.Renderer) {
        draw_ent(e, renderer)
    }
}

setup_bullet :: proc(e: ^Entity) {
    e.kind = .bullet

    e.update_proc = proc(e: ^Entity) {
        e.pos += e.direction * e.speed * state.dt
    }

    e.draw_proc = proc(e: Entity, renderer: ^sdl3.Renderer) {
        sdl3.SetRenderDrawColor(renderer, 0, 255, 0, 1)
        sdl3.RenderPoint(renderer, e.pos.x, e.pos.y)
    }
}

rebuild_scratch_helpers :: proc() {
    // construct the list of all entities on the temp allocator
    // that way it's easier to loop over later on
    all_ents := make(
        [dynamic]EntityHandle,
        0,
        len(state.gs.entities),
        allocator = context.temp_allocator,
    )
    for &e in state.gs.entities {
        if !entity_is_valid(&e) do continue
        append(&all_ents, e.handle)
    }
    state.gs.scratch.all_entities = all_ents[:]
}

draw_ent :: proc(e: Entity, renderer: ^sdl3.Renderer) {
    spr := state.sprites[e.sprite]
    src := spr.uv
    dest := sdl3.FRect{e.pos.x, e.pos.y, f32(spr.width), f32(spr.height)}

    // animations
    frame_count := sprite_data[e.sprite].frame_count
    if frame_count > 1 {
        frame_offset := int(spr.width) / frame_count
        src.w = f32(frame_offset)
        src.x += f32(frame_offset * e.anim_index)
        dest.w = f32(frame_offset)
    }

    // offest destination by pivot
    pivot_offset := pivot_to_vec(e.draw_pivot)
    pivot_point := sdl3.FPoint{src.w * pivot_offset.x, src.h * pivot_offset.y}

    dest.x -= dest.w * pivot_offset.x
    dest.y -= dest.h * pivot_offset.y

    // flip
    mode: sdl3.FlipMode
    if e.flip_x do mode |= .HORIZONTAL
    if e.flip_y do mode |= .VERTICAL

    sdl3.RenderTextureRotated(
        renderer,
        state.atlas.texture,
        &src,
        &dest,
        e.rotation_deg,
        &pivot_point,
        mode,
    )
}

player :: proc() -> ^Entity {
    return entity_from_handle(state.gs.player_handle)
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
    player := entity_create(.player)
    state.gs.player_handle = player.handle

    // temp
    spawner := entity_create(.spawner)
    spawner.pos = {450, 150}


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
        rebuild_scratch_helpers()

        if action_occurred(.exit) {
            state.running = false
        }

        if action_occurred(.place_tower) {
            e := entity_create(.tower)

            world_x, world_y: f32
            // not sure if this is right
            sdl3.RenderCoordinatesFromWindow(
                renderer,
                state.input.mouse_x,
                state.input.mouse_y,
                &world_x,
                &world_y,
            )

            e.pos = grid_get_nearest_centre(GRID_SIZE, {world_x, world_y})
        }

        if action_occurred(.rotate) {
            player.rotation_deg += 10
        }

        // update ent
        for handle in get_all_ents() {
            e := entity_from_handle(handle)

            entity_update_animation(e)

            if e.update_proc != nil {
                e.update_proc(e)
            }
        }


        // draw

        sdl3.SetRenderDrawColor(renderer, 245, 235, 220, 255)
        sdl3.RenderClear(renderer)

        // draw ents
        for handle in get_all_ents() {
            e := entity_from_handle(handle)
            e.draw_proc(e^, renderer)
        }

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
