package main

import "base:runtime"
import "core:bytes"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"

import "ecs"
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

        current_time := sdl3.GetTicks()
        if current_time >= tower.next_done_time {
            bullet := spawn_bullet(tower_pos)
            bullet_c := ecs.get_component(w, bullet, C_MovementController)

            bullet_c.target_dir = linalg.normalize(target_pos - tower_pos)
            bullet_c.speed = 200

            tower.next_done_time = current_time + tower.interval_ms
        }
    }
}

spawner :: proc() {
    w := state.gs.world
    spawners := ecs.get_entities_with(w, C_Spawner)

    for e in spawners {
        spawner := ecs.get_component(w, e, C_Spawner)
        spawner_pos := ecs.get_component(w, e, C_Transform).pos

        current_time := sdl3.GetTicks()
        if current_time >= spawner.next_done_time {
            enemy := spawn_enemy(spawner_pos)

            spawner.next_done_time = current_time + spawner.interval_ms
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
        transform.vel += mc.target_dir * mc.speed * state.dt
    }

    // update transforms
    transforms := ecs.get_entities_with(w, C_Transform)

    for e in transforms {
        transform := ecs.get_component(w, e, C_Transform)

        transform.pos += transform.vel

        // reset and stuff, may change later
        transform.last_dir = linalg.normalize(transform.vel)
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

collision :: proc() {
    w := state.gs.world

    colliders := ecs.get_entities_with(w, C_AABBCollider)

    for e in colliders {
        transform := ecs.get_component(w, e, C_Transform)
        collider := ecs.get_component(w, e, C_AABBCollider)
        e_wp := aabb_to_world(collider.rect, transform.pos)

        for other in colliders {
            if e == other do continue

            other_collider := ecs.get_component(w, other, C_AABBCollider)
            other_transform := ecs.get_component(w, other, C_Transform)
            o_wp := aabb_to_world(other_collider.rect, other_transform.pos)

            intersection: sdl3.FRect
            hit := sdl3.GetRectIntersectionFloat(e_wp, o_wp, &intersection)

            if !hit do continue

            // hit behaviour
            if collider.hit_proc != nil {
                collider.hit_proc(e, other)
            }

            //FIX: doesnt work
            if !other_collider.physical do continue

            // resolve collisions
            if intersection.w < intersection.h {
                push := intersection.w * 0.5
                if transform.pos.x < other_transform.pos.x {
                    transform.pos.x -= push
                    other_transform.pos.x += push
                } else {
                    transform.pos.x += push
                    other_transform.pos.x -= push
                }
            } else {
                push := intersection.h * 0.5
                if transform.pos.y < other_transform.pos.y {
                    transform.pos.y -= push
                    other_transform.pos.y += push
                } else {
                    transform.pos.y += push
                    other_transform.pos.y -= push
                }
            }
        }
    }
}

// --- Drawing ---

// for debug if needed
draw_colliders :: proc(renderer: ^sdl3.Renderer) {
    w := state.gs.world

    colliders := ecs.get_entities_with(w, C_AABBCollider)

    for e in colliders {
        transform := ecs.get_component(w, e, C_Transform)
        aabb := ecs.get_component(w, e, C_AABBCollider)

        aabb_world := aabb_to_world(aabb.rect, transform.pos)


        r, g, b, a: sdl3.Uint8
        sdl3.GetRenderDrawColor(renderer, &r, &g, &b, &a)
        sdl3.SetRenderDrawColor(renderer, 0, 150, 150, 100)
        sdl3.RenderFillRect(renderer, &aabb_world)
        sdl3.SetRenderDrawColor(renderer, r, g, b, a)
    }
}

draw_sprites :: proc(renderer: ^sdl3.Renderer) {
    w := state.gs.world

    entities := ecs.get_entities_with(w, C_Sprite)
    for e in entities {
        spr_component := ecs.get_component(w, e, C_Sprite)
        transform := ecs.get_component(w, e, C_Transform)

        spr := state.sprites[spr_component.name]

        src := spr.uv
        dest := sdl3.FRect {
            transform.pos.x,
            transform.pos.y,
            f32(spr.width),
            f32(spr.height),
        }

        // animations
        if ecs.has_component(w, e, C_AnimationController) {
            anim := ecs.get_component(w, e, C_AnimationController)

            frame_count := sprite_data[spr_component.name].frame_count
            if frame_count > 1 {
                frame_offset := int(spr.width) / frame_count
                src.w = f32(frame_offset)
                src.x += f32(frame_offset * anim.anim_index)
                dest.w = f32(frame_offset)
            }
        }

        // offest destination by pivot
        pivot_offset := pivot_to_vec(spr_component.draw_pivot)
        pivot_point := sdl3.FPoint {
            src.w * pivot_offset.x,
            src.h * pivot_offset.y,
        }

        dest.x -= dest.w * pivot_offset.x
        dest.y -= dest.h * pivot_offset.y

        sdl3.RenderTextureRotated(
            renderer,
            state.atlas.texture,
            &src,
            &dest,
            spr_component.rotation_deg,
            &pivot_point,
            spr_component.flip_state,
        )

    }
}
