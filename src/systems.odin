package main

import "base:runtime"
import "core:bytes"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"

import "ecs"
import r "render"

import "vendor:sdl3"


animation :: proc() {
    w := state.gs.world

    animators := make([dynamic]ecs.Entity, context.temp_allocator)
    query := ecs.query_mask(w, C_AnimationController, C_Sprite)
    ecs.get_entities_query(w, query, &animators)

    for e in animators {

        anim := ecs.get_component(w, e, C_AnimationController)
        spr := ecs.get_component(w, e, C_Sprite)
        mc := ecs.get_component(w, e, C_MovementController)

        animation_data := sprite_data[spr.name]
        animation := anim.animations

        if mc != nil {
            if mc.target_dir != {0, 0} {
                anim.current = .walk
            } else {
                anim.current = .default
            }
        }

        // set sprite
        current := anim.animations[anim.current]
        if spr.name != current {
            spr.name = current
            anim.anim_index = 0
            anim.next_frame_end_time_ms = sdl3.GetTicks()
        }

        is_playing := true
        if !animation_data.repeat {
            is_playing = anim.anim_index + 1 <= animation_data.frame_count
        }

        if is_playing {

            if anim.next_frame_end_time_ms == 0 {
                anim.next_frame_end_time_ms =
                    sdl3.GetTicks() + animation_data.frame_interval_ms
            }

            if sdl3.GetTicks() >= anim.next_frame_end_time_ms {
                anim.anim_index += 1
                anim.next_frame_end_time_ms = 0
                if anim.anim_index >= animation_data.frame_count {
                    if animation_data.repeat {
                        anim.anim_index = 0
                    } else {
                        anim.anim_index = animation_data.frame_count - 1 // clamp to last frame
                    }
                }
            }
        }
    }
}

towers :: proc() {
    w := state.gs.world
    towers := ecs.get_entities_with(w, C_Tower)
    enemies := ecs.get_entities_with(w, C_Enemy)

    // dont update if there is nothing to shoot
    // This could be done in a better way
    enemy_count := len(enemies)
    if enemy_count < 1 do return

    for e in towers {
        tower := ecs.get_component(w, e, C_Tower)
        tower_pos := ecs.get_component(w, e, C_Transform).pos
        // target random enemy
        target := rand.int_max(enemy_count)
        target_pos := ecs.get_component(w, enemies[target], C_Transform).pos

        if timer_done_reset(&tower.timer) {
            bullet := spawn_bullet(tower_pos)
            bullet_c := ecs.get_component(w, bullet, C_MovementController)

            bullet_c.target_dir = linalg.normalize(target_pos - tower_pos)
            bullet_c.speed = 200
        }
    }
}

enemy :: proc() {
    w := state.gs.world
    query := ecs.query_mask(w, C_Enemy, C_Transform, C_MovementController)
    enemies := make([dynamic]ecs.Entity, context.temp_allocator)
    ecs.get_entities_query(w, query, &enemies)
    player_pos := ecs.get_component(w, state.gs.player, C_Transform).pos

    for e in enemies {
        transform := ecs.get_component(w, e, C_Transform)
        mc := ecs.get_component(w, e, C_MovementController)
        mc.target_dir = linalg.normalize(player_pos - transform.pos)
    }
}

movement_control :: proc() {
    w := state.gs.world
    query := ecs.query_mask(w, C_Transform, C_MovementController)
    movement_controlled := make([dynamic]ecs.Entity, context.temp_allocator)
    ecs.get_entities_query(w, query, &movement_controlled)

    for e in movement_controlled {
        transform := ecs.get_component(w, e, C_Transform)
        mc := ecs.get_component(w, e, C_MovementController)

        // add the desired movement direction to velocity
        transform.vel += mc.target_dir * mc.speed * f32(state.dt)
    }

    // update transforms
    transforms := ecs.get_entities_with(w, C_Transform)

    for e in transforms {
        transform := ecs.get_component(w, e, C_Transform)

        transform.pos += transform.vel

        // reset and stuff, may change later
        transform.last_dir = linalg.normalize0(transform.vel)
        transform.vel = 0
    }
}

// takes in the input from the action system and applies to components that listen
input :: proc() {
    w := state.gs.world
    entities := ecs.get_entities_with(w, C_Input)

    // take in input
    input_dir: Vec2
    idle := true
    if action_occurred(.left) {
        input_dir.x -= 1.0
    }

    if action_occurred(.right) {
        input_dir.x += 1.0
    }

    if action_occurred(.down) {
        input_dir.y += 1.0
    }

    if action_occurred(.up) {
        input_dir.y -= 1.0
    }

    if input_dir != {} {
        input_dir = linalg.normalize(input_dir)
        idle = false
    }

    for e in entities {
        input := ecs.get_component(w, e, C_Input)
        input.input_dir = input_dir
    }

    // update accordingly
    query := ecs.query_mask(w, C_Transform, C_Input, C_MovementController)
    input_movers := make([dynamic]ecs.Entity, context.temp_allocator)
    ecs.get_entities_query(w, query, &input_movers)

    for e in input_movers {
        mc := ecs.get_component(w, e, C_MovementController)
        input := ecs.get_component(w, e, C_Input)
        mc.target_dir = input.input_dir
    }
}

// Flip and rotate sprites based on flip mode and velocity
sprite_flip_rotate :: proc() {
    w := state.gs.world

    entities := ecs.get_entities_with(w, C_Sprite)

    for e in entities {
        spr := ecs.get_component(w, e, C_Sprite)
        transform := ecs.get_component(w, e, C_Transform)

        switch spr.flip_mode {
        case .nil:
            continue
        case .flip_x:
            if transform.last_dir.x < 0 do spr.flip_state = .HORIZONTAL
            if transform.last_dir.x > 0 do spr.flip_state = .NONE

        case .rotate:
            if transform.last_dir == {} do continue
            angle := math.atan2(transform.last_dir.y, transform.last_dir.x)
            degrees := math.to_degrees(angle)
            spr.rotation_deg = f64(degrees)
        }
    }

}

// cull out of bounds entities
cullOOB :: proc(bounds: sdl3.FRect) {
    w := state.gs.world

    entities := ecs.get_entities_with(w, C_Transform)

    for e in entities {
        transform := ecs.get_component(w, e, C_Transform)
        if !sdl3.PointInRectFloat({transform.pos.x, transform.pos.y}, bounds) {
            // skip the player I guess
            if e == state.gs.player do continue

            append(&state.gs.entity_free_list, e)
        }
    }
}

pulse :: proc() {
    w := state.gs.world
    query := ecs.query_mask(w, C_Pulse, C_Transform)
    pulsing := make([dynamic]ecs.Entity, context.temp_allocator)
    ecs.get_entities_query(w, query, &pulsing)

    for e in pulsing {
        pulse := ecs.get_component(w, e, C_Pulse)
        transform := ecs.get_component(w, e, C_Transform)

        transform.vel += pulse.vel * f32(state.dt)

        decay_factor := math.max(0, 1 - pulse.decay * f32(state.dt))
        pulse.vel *= decay_factor

        // remove if small enough
        if linalg.length(pulse.vel) < 0.1 {
            pulse.vel = 0
            ecs.remove_component(w, e, C_Pulse)
        }
    }
}

@(private = "file")
col_correction :: proc(
    intersection: sdl3.FRect,
    pos: ^Vec2,
    other_pos: Vec2,
    mult: f32,
) {
    if intersection.w >= intersection.h {
        if pos.y <= other_pos.y {
            pos.y -= intersection.h * mult
        } else {
            pos.y += intersection.h * mult
        }
    } else {
        if pos.x <= other_pos.x {
            pos.x -= intersection.w * mult
        } else {
            pos.x += intersection.w * mult
        }
    }
}

handle_collision :: proc(e, other: ecs.Entity) {
    w := state.gs.world
    // projectile -> enemy
    if ecs.has_component(w, e, C_Projectile) &&
       ecs.has_component(w, other, C_Enemy) {
        // kill enemy and bullet
        append(&state.gs.entity_free_list, other)
        append(&state.gs.entity_free_list, e)
    }

    // enemy -> player (attack)
    if ecs.has_component(w, e, C_Enemy) && other == state.gs.player {
        attack := ecs.get_component(w, e, C_Attack)

        if timer_done_reset(&attack.cooldown_timer) {
            player_health := ecs.get_component(w, other, C_Health)
            player_health.current_health -= attack.damage

            dir := linalg.normalize0(
                ecs.get_component(w, other, C_Transform).pos -
                ecs.get_component(w, e, C_Transform).pos,
            )

            pulse := ecs.add_component(w, other, C_Pulse)
            pulse.vel = dir * attack.knockback
            pulse.decay = 10
        }
    }

}

collision :: proc() {
    w := state.gs.world

    colliders := ecs.get_entities_with(w, C_AABBCollider)

    Collision :: struct {
        e:     ecs.Entity,
        other: ecs.Entity,
    }
    collisions := make([dynamic]Collision, context.temp_allocator)

    for i in 0 ..< len(colliders) {
        e := colliders[i]

        transform := ecs.get_component(w, e, C_Transform)
        collider := ecs.get_component(w, e, C_AABBCollider)
        e_wp := aabb_to_world(collider.rect, transform.pos)

        for j in i + 1 ..< len(colliders) {
            other := colliders[j]

            other_collider := ecs.get_component(w, other, C_AABBCollider)
            other_transform := ecs.get_component(w, other, C_Transform)
            o_wp := aabb_to_world(other_collider.rect, other_transform.pos)

            // detect hit
            if !rects_intersect(e_wp, o_wp) do continue

            // hit behaviour
            handle_collision(e, other)
            handle_collision(other, e)


            // resolutions

            // dont need to resolve if either is not physical
            if !collider.physical || !other_collider.physical do continue

            append(&collisions, Collision{e, other})
        }
    }

    // resolve after
    for i in 0 ..= 3 {
        for col in collisions {
            e_transform := ecs.get_component(w, col.e, C_Transform)
            other_transform := ecs.get_component(w, col.other, C_Transform)

            e_collider := ecs.get_component(w, col.e, C_AABBCollider)
            other_collider := ecs.get_component(w, col.other, C_AABBCollider)

            e_wp := aabb_to_world(e_collider.rect, e_transform.pos)
            o_wp := aabb_to_world(other_collider.rect, other_transform.pos)

            intersection: sdl3.FRect
            hit := sdl3.GetRectIntersectionFloat(e_wp, o_wp, &intersection)
            if !hit do continue

            if e_collider.static && other_collider.static do continue


            if !e_collider.static && !other_collider.static {
                // both dynamic — each takes half
                col_correction(
                    intersection,
                    &e_transform.pos,
                    other_transform.pos,
                    0.5,
                )
                col_correction(
                    intersection,
                    &other_transform.pos,
                    e_transform.pos,
                    0.5,
                )
            } else if !e_collider.static {
                // only e moves (other is static)
                col_correction(
                    intersection,
                    &e_transform.pos,
                    other_transform.pos,
                    1,
                )
            } else {
                // only other moves (e is static)
                col_correction(
                    intersection,
                    &other_transform.pos,
                    e_transform.pos,
                    1,
                )
            }
        }

    }
}

path_following :: proc() {
    w := state.gs.world
    followers := ecs.get_entities_with(w, C_PathFollower)

    CLOSENESS_NEEDED :: 1
    for e in followers {
        transform := ecs.get_component(w, e, C_Transform)
        waypoints := ecs.get_component(w, e, C_PathFollower)
        mc := ecs.get_component(w, e, C_MovementController)


        if waypoints.current_waypoint >= len(waypoints.waypoints) do continue
        current_target := waypoints.waypoints[waypoints.current_waypoint]

        // check off waypoints
        if linalg.distance(transform.pos, current_target) <= CLOSENESS_NEEDED {
            waypoints.current_waypoint += 1
        }

        // ignore those that are finished
        if waypoints.current_waypoint >= len(waypoints.waypoints) do continue
        current_target = waypoints.waypoints[waypoints.current_waypoint]

        // move
        mc.target_dir = linalg.normalize(current_target - transform.pos)
    }
}

update_game_camera :: proc(bounds: sdl3.FRect) {
    w := state.gs.world
    cam := &state.gs.game_camera

    cam.target = ecs.get_component(w, state.gs.player, C_Transform).pos

    min_x := bounds.x + cam.view_width / 2
    min_y := bounds.y + cam.view_height / 2

    max_x := bounds.x + bounds.w - cam.view_width / 2
    max_y := bounds.y + bounds.h - cam.view_height / 2

    cam.target.x = clamp(cam.target.x, min_x, max_x)
    cam.target.y = clamp(cam.target.y, min_y, max_y)
}

// --- Drawing ---

//TODO: maybe we can remove the width when we create app subsystem
draw_player_health :: proc(renderer: r.Renderer, width, height: int) {
    w := state.gs.world
    hp := ecs.get_component(w, state.gs.player, C_Health)

    if hp.current_health <= 0 do return

    BAR_HEIGHT :: 10

    percent_health := f32(hp.current_health) / f32(hp.max_health)

    rect := sdl3.FRect {
        0,
        f32(height) - BAR_HEIGHT,
        f32(width) * percent_health,
        BAR_HEIGHT,
    }

    r.draw_rect(renderer, &rect, 255, 0, 0)
}

// for debug if needed
draw_colliders :: proc(renderer: r.Renderer) {
    w := state.gs.world

    colliders := ecs.get_entities_with(w, C_AABBCollider)

    for e in colliders {
        transform := ecs.get_component(w, e, C_Transform)
        aabb := ecs.get_component(w, e, C_AABBCollider)

        aabb_world := aabb_to_world(aabb.rect, transform.pos)

        r.draw_rect(renderer, &aabb_world, 0, 150, 150, 100)
    }
}

draw_waypoints :: proc(renderer: r.Renderer) {
    w := state.gs.world
    followers := ecs.get_entities_with(w, C_PathFollower)

    for e in followers {
        transform := ecs.get_component(w, e, C_Transform)
        waypoints := ecs.get_component(w, e, C_PathFollower)

        for waypoint in waypoints.waypoints {
            DOT_SIZE :: 2
            r.draw_rect(
                renderer,
                &{
                    waypoint.x - DOT_SIZE / 2,
                    waypoint.y - DOT_SIZE / 2,
                    DOT_SIZE,
                    DOT_SIZE,
                },
                0,
                255,
                0,
            )
        }
    }
}

draw_origins :: proc(renderer: r.Renderer) {
    w := state.gs.world
    entities := ecs.get_entities_with(w, C_Transform)


    for e in entities {
        transform := ecs.get_component(w, e, C_Transform)

        DOT_SIZE :: 2
        r.draw_rect(
            renderer,
            &{
                transform.pos.x - DOT_SIZE / 2,
                transform.pos.y - DOT_SIZE / 2,
                DOT_SIZE,
                DOT_SIZE,
            },
            0,
            0,
            0,
        )
    }
}

draw_sprites :: proc(renderer: r.Renderer) {
    w := state.gs.world

    entities := ecs.get_entities_with(w, C_Sprite)
    for e in entities {
        spr_component := ecs.get_component(w, e, C_Sprite)
        transform := ecs.get_component(w, e, C_Transform)

        spriteID := sprite_ids[spr_component.name]

        frame_count := 0
        current_frame := 0
        if ecs.has_component(w, e, C_AnimationController) {
            anim := ecs.get_component(w, e, C_AnimationController)
            frame_count = sprite_data[spr_component.name].frame_count
            current_frame = anim.anim_index
        }


        r.draw_sprite(
            renderer,
            spriteID,
            transform.pos,
            spr_component.draw_pivot,
            spr_component.rotation_deg,
            spr_component.flip_state,
            frame_count,
            current_frame,
        )
    }
}

draw_range :: proc(renderer: r.Renderer) {
    range := item_data[state.gs.selected_item].place_radius
    if range == 0 do return

    origin := &ecs.get_component(state.gs.world, state.gs.player, C_Transform).pos

    r.draw_circle(renderer, range, origin.x, origin.y, 0, 0, 0, 100)

}
