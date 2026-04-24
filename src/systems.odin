package main

import "core:math/linalg"
import "core:math/rand"
import "ecs"
import "vendor:sdl3"


animation :: proc(e: ecs.Entity) {
    w := state.gs.world
    anim := ecs.get_component(w, e, C_Animation)
    spr := ecs.get_component(w, e, C_Sprite)

    if anim.frame_duration_ms == 0 do return

    frame_count := sprite_data[spr.name].frame_count

    is_playing := true
    if !anim.loop {
        is_playing = anim.anim_index + 1 <= frame_count
    }

    if is_playing {

        if anim.next_frame_end_time_ms == 0 {
            anim.next_frame_end_time_ms =
                sdl3.GetTicks() + anim.frame_duration_ms
        }

        if sdl3.GetTicks() >= anim.next_frame_end_time_ms {
            anim.anim_index += 1
            anim.next_frame_end_time_ms = 0

            if anim.anim_index >= frame_count {
                if anim.loop {
                    anim.anim_index = 0
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
            bullet_c := ecs.get_component(w, bullet, C_Projectile)

            bullet_c.target = linalg.normalize(target_pos - tower_pos)
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

projectile :: proc() {
    w := state.gs.world
    projectiles := ecs.get_entities_with(w, C_Projectile)

    for e in projectiles {
        projectile := ecs.get_component(w, e, C_Projectile)
        projectile_transform := ecs.get_component(w, e, C_Transform)

        projectile_transform.pos +=
            projectile.target * projectile.speed * state.dt
    }

}

enemy :: proc() {
    w := state.gs.world
    enemies := ecs.get_entities_with(w, C_Enemy)
    player_pos := ecs.get_component(w, state.gs.player, C_Transform).pos

    for e in enemies {
        transform := ecs.get_component(w, e, C_Transform)
        dir := linalg.normalize(player_pos - transform.pos)
        transform.pos += dir * 100 * state.dt
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
        if ecs.has_component(w, e, C_Animation) {
            anim := ecs.get_component(w, e, C_Animation)

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


        // flip
        mode: sdl3.FlipMode
        if spr_component.flip_x do mode |= .HORIZONTAL
        if spr_component.flip_y do mode |= .VERTICAL

        sdl3.RenderTextureRotated(
            renderer,
            state.atlas.texture,
            &src,
            &dest,
            transform.rotation_deg,
            &pivot_point,
            mode,
        )

    }
}
