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
}

sprite_data: [SpriteName]Sprite_Data = #partial {
    .animtest = {frame_count = 3},
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
    ticks:             u64,
    game_time_elapsed: f64,
    cam_pos:           Vec2,
    entity_top_count:  int,
    latest_entity_id:  int,
    entities:          [MAX_ENTITIES]Entity,
    entity_free_list:  [dynamic]int,
    player_handle:     EntityHandle,
    scratch:           struct {
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
}

action_bindings: map[Bind]Action = {
    {.W, .down} = .up,
    {.A, .down} = .left,
    {.S, .down} = .down,
    {.D, .down} = .right,
    {.ESCAPE, .pressed} = .exit,
    {.M_LEFT, .pressed} = .place_tower,
}

action_occurred :: proc(action: Action) -> bool {
    return state.occurred_actions[action]
}

EntityKind :: enum {
    nil,
    player,
    tower,
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
    }
}

setup_player :: proc(e: ^Entity) {
    e.kind = .player
    e.pos = {120, 120}
    e.sprite = .player

    e.update_proc = proc(e: ^Entity) {
        input: Vec2
        if action_occurred(.left) do input.x -= 1.0
        if action_occurred(.right) do input.x += 1.0
        if action_occurred(.down) do input.y += 1.0
        if action_occurred(.up) do input.y -= 1.0
        if input != {} {
            input = linalg.normalize(input)
        }

        e.pos += input * 100.0 * state.dt
    }

    e.draw_proc = proc(e: Entity, renderer: ^sdl3.Renderer) {
        draw_ent(e, renderer)
    }
}

setup_tower :: proc(e: ^Entity) {
    e.kind = .tower
    e.sprite = .tile1


    e.draw_proc = proc(e: Entity, renderer: ^sdl3.Renderer) {
        draw_ent(e, renderer)
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

    sdl3.RenderTexture(renderer, state.atlas.texture, &src, &dest)
}

main :: proc() {
    context.logger = log.create_console_logger()

    WINDOW_WIDTH :: 1280
    WINDOW_HEIGHT :: 720

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

    player := entity_create(.player)
    state.gs.player_handle = player.handle
    entity_set_animation(player, .animtest, 1000)


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

            e.pos = grid_get_nearest(GRID_SIZE, {world_x, world_y})
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
