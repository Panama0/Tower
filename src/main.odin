#+ feature dynamic-literals
package main

import "core:fmt"
import "core:log"
import "core:mem"

import "ecs"
import r "render"

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
    bullet_test,
    fence,
}

sprite_ids: [SpriteName]r.AssetID

sprite_data: [SpriteName]Sprite_Data = #partial {
    .animtest = {frame_count = 3, frame_interval_ms = 150, repeat = true},
    .knight_idle = {frame_count = 7, frame_interval_ms = 100, repeat = true},
    .knight_walk = {frame_count = 8, frame_interval_ms = 100, repeat = true},
}

Sprite_Data :: struct {
    file_name:         string,
    frame_count:       int,
    frame_interval_ms: u64,
    repeat:            bool,
    // offset:      Vec2,
    // pivot:       utils.Pivot,
}

load_assets :: proc(renderer: ^r.Renderer) {
    // sprites
    for sprite, name in sprite_data {
        if name == .nil do continue

        // infer file name if not specified
        file_name := sprite.file_name
        if file_name == "" {
            file_name = fmt.tprint(name)
        }

        spriteID := r.add_sprite(renderer, file_name)

        sprite_ids[name] = spriteID
    }

    // fonts
    for data, name in font_data {
        fontID, ok := r.load_font(renderer, data.family, data.size_pt)
        if !ok {
            log.debug("Could not load font: %v", name)
            continue
        }
        fontIDs[name] = fontID
    }

}

// internal name
FontStyle :: enum {
    normal,
    debug,
    // examples
    // bold
    // menu header
}

font_data: [FontStyle]FontData = {
    .normal = {"Minecraft", 16},
    .debug  = {"NotoSans", 6},
}

fontIDs: [FontStyle]r.AssetID

FontData :: struct {
    family:  string,
    size_pt: f32,
    // if we want bold/ita in the future
    //style: string
}

// things you can place
Item :: enum {
    none,
    tower,
    wall,
}

ItemData :: struct {
    sprite:       SpriteName,
    cost:         int,
    place_radius: f32,
    //TODO:
    // draggable: bool // for fences, walls
}

item_data: [Item]ItemData = {
    .none = {sprite = .nil, cost = 0, place_radius = 0},
    .wall = {sprite = .fence, cost = 20, place_radius = 0},
    .tower = {sprite = .tile2, cost = 100, place_radius = 100},
}

MAX_ENTITIES :: 1024
GRID_SIZE :: 16

State :: struct {
    gs:               GameState,
    dt:               f64,
    running:          bool,
    input:            InputState,
    occurred_actions: [Action]bool,
    // window stuff
    fullscreen:       bool,
    old_win_size:     Vec2i,
}

GameState :: struct {
    running_seconds:  f64,
    cam_pos:          Vec2,
    world:            ^ecs.World,
    entity_free_list: [dynamic]ecs.Entity,
    player:           ecs.Entity,
    items:            [Item]int,
    selected_item:    Item,
    place_grid:       Grid,
    game_camera:      r.Camera,
    ui_camera:        r.Camera,
    waves:            Waves,
}

state: State


Action :: enum {
    left,
    right,
    up,
    down,
    exit,
    place_item,
    show_range, // show the place radius of current item
    rotate,
    change_size, // debug
    toggle_fullscreen,
}

action_bindings: map[Bind]Action = {
    {.W, .down} = .up,
    {.A, .down} = .left,
    {.S, .down} = .down,
    {.D, .down} = .right,
    {.ESCAPE, .pressed} = .exit,
    {.M_LEFT, .released} = .place_item,
    {.M_RIGHT, .down} = .show_range,
    {.R, .pressed} = .rotate,
    {.M, .pressed} = .change_size,
    {.F, .pressed} = .toggle_fullscreen,
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
    spr.flip_mode = .flip_x

    anim_controller := ecs.add_component(w, e, C_AnimationController)
    anim_controller.animations = #partial {
        .default = .knight_idle,
        .walk    = .knight_walk,
    }

    movement := ecs.add_component(w, e, C_MovementController)
    movement.speed = 130

    ecs.add_component(w, e, C_Input)


    collider := ecs.add_component(w, e, C_AABBCollider)
    collider.rect = {-10, -10, 16, 32}
    collider.physical = true

    health := ecs.add_component(w, e, C_Health)
    health.max_health = 100
    health.current_health = 25

    return e
}

spawn_tower :: proc(pos: Vec2) -> ecs.Entity {
    w := state.gs.world
    e := ecs.add_entity(w)

    transform := ecs.add_component(w, e, C_Transform)
    transform.pos = pos

    spr := ecs.add_component(w, e, C_Sprite)
    spr.name = item_data[.tower].sprite

    timer := ecs.add_component(w, e, C_Tower)
    timer.timer.interval = 1

    tags := ecs.add_component(w, e, C_PathfindingTags)
    tags.tags += {.impassible}
    tags.bounds = default_collider(32, 32)

    return e
}

spawn_wall :: proc(pos: Vec2) -> ecs.Entity {
    w := state.gs.world
    e := ecs.add_entity(w)

    transform := ecs.add_component(w, e, C_Transform)
    transform.pos = pos

    spr := ecs.add_component(w, e, C_Sprite)
    spr.name = item_data[.wall].sprite

    coll := ecs.add_component(w, e, C_AABBCollider)
    coll.physical = true
    coll.static = true
    //TODO: fix this
    // spr_w := f32(renderer.sprites[spr.name].width)
    coll.rect = default_collider(16, 16)

    tags := ecs.add_component(w, e, C_PathfindingTags)
    tags.tags += {.impassible}
    tags.bounds = default_collider(16, 16)

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
    timer.timer.interval = 1.0

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

    anim_controller := ecs.add_component(w, e, C_AnimationController)
    anim_controller.animations = #partial {
        .default = .animtest,
        .walk    = .animtest,
    }
    anim_controller.loop = true
    anim_controller.frame_duration_ms = 150

    mc := ecs.add_component(w, e, C_MovementController)
    mc.speed = 20

    collider := ecs.add_component(w, e, C_AABBCollider)
    collider.rect = default_collider(16, 32)
    collider.physical = true

    attack := ecs.add_component(w, e, C_Attack)
    attack.damage = 10
    attack.knockback = 350
    attack.cooldown_timer.interval = 1.0

    follower := ecs.add_component(w, e, C_PathFollower)
    follower.target = state.gs.player

    return e
}

spawn_bullet :: proc(pos: Vec2) -> ecs.Entity {
    w := state.gs.world
    e := ecs.add_entity(w)

    transform := ecs.add_component(w, e, C_Transform)
    transform.pos = pos

    spr := ecs.add_component(w, e, C_Sprite)
    spr.name = .bullet_test
    spr.flip_mode = .rotate

    ecs.add_component(w, e, C_Projectile)
    ecs.add_component(w, e, C_MovementController)

    collider := ecs.add_component(w, e, C_AABBCollider)
    //TODO: make a default collider funciton that takes in sprite w/h
    collider.rect = {-10, -10, 15, 15}

    return e
}

free_dead_ents :: proc() {
    for e in state.gs.entity_free_list {
        ecs.kill_entity(state.gs.world, e)
    }
    clear(&state.gs.entity_free_list)
}

register_components :: proc(w: ^ecs.World) {
    ecs.register_component(w, C_Sprite)
    ecs.register_component(w, C_Transform)
    ecs.register_component(w, C_AnimationController)
    ecs.register_component(w, C_Tower)
    ecs.register_component(w, C_Spawner)
    ecs.register_component(w, C_Projectile)
    ecs.register_component(w, C_Enemy)
    ecs.register_component(w, C_MovementController)
    ecs.register_component(w, C_Pulse)
    ecs.register_component(w, C_Health)
    ecs.register_component(w, C_Attack)
    ecs.register_component(w, C_Input)
    ecs.register_component(w, C_AABBCollider)
    ecs.register_component(w, C_PathfindingTags)
    ecs.register_component(w, C_PathFollower, clean_path_follower)
}

//TODO: This does not work on wayland
resize_window :: proc(window: ^sdl3.Window, new_size: Vec2i) {
    // emits a window resized event
    ok := sdl3.SetWindowSize(window, new_size.x, new_size.y)

    log.debug("resizing to ", new_size)
}

main :: proc() {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            log.debugf(
                "Peak Allocation: %.3fMB",
                f64(track.peak_memory_allocated) / 1_048_576,
            )

            if len(track.allocation_map) > 0 {
                for _, entry in track.allocation_map {
                    log.debugf(
                        "%v leaked %v bytes\n",
                        entry.location,
                        entry.size,
                    )
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }


    LOGICAL_WIDTH :: 640
    LOGICAL_HEIGHT :: 360
    MAX_FPS :: 60

    // window
    ok := sdl3.Init({.VIDEO})
    if !ok do log.fatalf("Could not initialise SDL: %v", sdl3.GetError())

    window := sdl3.CreateWindow("game", 640, 360, {})
    if window == nil do log.panicf("Could not open window with error: %v", sdl3.GetError())
    state.old_win_size = {640, 360}

    renderer: r.Renderer
    r.renderer_init(&renderer, window, {LOGICAL_WIDTH, LOGICAL_HEIGHT})
    load_assets(&renderer)

    state.gs.game_camera = {
        {LOGICAL_WIDTH / 2, LOGICAL_HEIGHT / 2},
        LOGICAL_WIDTH,
        LOGICAL_HEIGHT,
    }

    world_bounds := sdl3.FRect{0, 0, 1280, 720}

    // init game stuff
    state.gs.world = ecs.make_world()
    defer ecs.world_destroy(state.gs.world)

    register_components(state.gs.world)
    state.gs.player = spawn_player()

    ui_init(LOGICAL_WIDTH, LOGICAL_HEIGHT)
    init(&renderer)

    state.gs.place_grid = make_grid({LOGICAL_WIDTH, LOGICAL_HEIGHT}, GRID_SIZE)

    // temp
    spawn_spawner({150, 150})
    spawn_spawner({250, 150})
    spawn_spawner({350, 150})
    enemy := spawn_enemy({450, 150})
    ui_set_hotbar_items(
        {
            .tower,
            .wall,
            .none,
            .none,
            .none,
            .none,
            .none,
            .none,
            .none,
            .none,
        },
    )

    wave_init(&state.gs.waves)

    //TODO: remove this? need to store graphs centrally somewhere based on collider
    w := state.gs.world
    enemy_bounds: sdl3.FRect = {}
    if ecs.has_component(w, enemy, C_AABBCollider) {
        enemy_bounds = ecs.get_component(w, enemy, C_AABBCollider).rect
    }

    pf_grid := make_grid({1280, 720}, 16)
    graph := pathfinding_generate_graph(pf_grid, enemy_bounds)
    defer pathfinding_delete_graph(graph)

    pf_interval: sdl3.Uint64 = 1000
    last_pf := sdl3.GetTicks()

    // ---

    last_tick: u64 = sdl3.GetTicksNS()
    current_tick: u64 = sdl3.GetTicksNS()

    state.running = true
    for state.running {
        last_tick = current_tick
        current_tick = sdl3.GetTicksNS()

        state.dt = f64(current_tick - last_tick) / 1_000_000_000

        handle_sdl_events(window, &renderer)

        // ui must be first as it consumes keys
        ui_consume_input()
        ui_update()

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

        if action_occurred(.place_item) {
            renderer.cam = state.gs.game_camera

            world_pos := r.screen_to_world(
                renderer,
                {i32(state.input.mouse_x), i32(state.input.mouse_y)},
            )
            // check if in range
            origin := &ecs.get_component(state.gs.world, state.gs.player, C_Transform).pos
            range := item_data[state.gs.selected_item].place_radius

            if range == 0 || point_in_circle(world_pos, origin^, range) {

                // in future, need to fix?

                grid_mid := grid_get_nearest_centre(
                    state.gs.place_grid,
                    world_pos,
                )

                grid_tl := grid_get_nearest_tl(state.gs.place_grid, world_pos)

                #partial switch state.gs.selected_item {
                case .tower:
                    e := spawn_tower(grid_tl)
                    pathfinding_add_entity(graph, e)

                case .wall:
                    e := spawn_wall(grid_mid)
                    pathfinding_add_entity(graph, e)
                }

            }

            renderer.cam = state.gs.ui_camera
        }

        show_range := false
        if action_occurred(.show_range) {
            show_range = true
        }

        if action_occurred(.change_size) {
            resize_window(window, {1280, 720})
        }

        if action_occurred(.toggle_fullscreen) {
            state.fullscreen = !state.fullscreen
            sdl3.SetWindowFullscreen(window, state.fullscreen)
        }

        // update ent

        wave_dispatch(&state.gs.waves)

        input()

        //enemy()
        towers()
        spawner()
        pulse()

        if last_pf + pf_interval < sdl3.GetTicks() {
            pathfinding(graph)

            last_pf = sdl3.GetTicks()
        }

        path_following()
        movement_control()

        update_game_camera(world_bounds)

        collision()

        sprite_flip_rotate()
        animation()

        cullOOB(world_bounds)

        // draw game
        r.renderer_new_frame(&renderer)

        renderer.cam = state.gs.game_camera
        draw_sprites(renderer)

        if show_range do draw_range(renderer)


        // debug draws
        // grid_draw(renderer, state.gs.place_grid)
        //pathfinding_draw_graph(renderer, graph^)
        //draw_waypoints(renderer)
        //draw_colliders(renderer)
        // draw_origins(renderer)
        draw_spawner_remaining(renderer)

        r.draw_rect(renderer, &world_bounds, 0, 255, 0, 255, false)

        // draw ui

        renderer.cam = state.gs.ui_camera
        ui_draw_hud(renderer)
        draw_player_health(renderer, 640, 360)

        fps_string := fmt.tprintf("%.2f", 1 / state.dt)
        r.draw_text(renderer, fontIDs[.debug], fps_string, 10, 10)

        // testing
        ui_window("Win1", {10, 10, 200, 200})
        if ui_button("test") {
            log.debug("test")
        }
        if ui_button("test2") {
            log.debug("test2")
        }
        @(static) boo := false
        ui_check_box("Check", &boo)
        @(static) val := 1.0
        ui_slider("slider", &val, -10, 100)
        ui_text(
            "some text that is very long affsfsfsdfsfnd goes on forever this is the mosh power",
            .debug,
            {255, 255, 255, 255},
        )

        r.renderer_end_frame(&renderer)

        // when we implement pause, just dont increment
        state.gs.running_seconds += state.dt

        free_dead_ents()
        reset_input_state(&state.input)
        state.occurred_actions = {}
        free_all(context.temp_allocator)
    }

    // clean all entity memory by killing all
    entities: [dynamic]ecs.Entity
    defer delete(entities)
    ecs.get_entities(state.gs.world, &entities)
    for e in entities {
        append(&state.gs.entity_free_list, e)
    }
    free_dead_ents()

    delete(state.gs.entity_free_list)

    r.renderer_shutdown(&renderer)

    sdl3.DestroyWindow(window)
    sdl3.Quit()
}
