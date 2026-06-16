package main

import "core:fmt"
import "core:log"
import "core:math"

import "ecs"
import r "render"

WaveState :: enum {
    cooldown,
    active,
}

Waves :: struct {
    current_wave:      int,
    difficulty_mul:    f64, // difficulty modifier
    // waves
    state:             WaveState,
    timer:             Timer,
    cooldown_interval: f64,
    wave_interval:     f64,
    // spawning
    enemies_in_wave:   int,
}

wave_init :: proc(waves: ^Waves) {
    waves.difficulty_mul = 1
    waves.cooldown_interval = 1
    waves.wave_interval = 20

    waves.state = .cooldown
    timer_set(&waves.timer, waves.cooldown_interval)
}

wave_dispatch :: proc(waves: ^Waves) {
    switch waves.state {
    case .cooldown:
        // if the cooldown is done start wave
        if timer_done(waves.timer) {
            wave_start(waves)
            timer_set(&waves.timer, waves.wave_interval)
            waves.state = .active
        }

    case .active:
        // if the wave is finished, start the cooldown
        if timer_done(waves.timer) {
            timer_set(&waves.timer, waves.cooldown_interval)
            waves.state = .cooldown
        }
    }

}

wave_start :: proc(waves: ^Waves) {
    w := state.gs.world
    SPAWN_RATE :: 2
    EXPONENT :: 1.1

    spawners := ecs.get_entities_with(w, C_Spawner)
    if len(spawners) == 0 do return

    waves.current_wave += 1

    // exponential increase
    waves.enemies_in_wave = int(
        math.pow(f64(waves.current_wave * 3), EXPONENT) * waves.difficulty_mul,
    )

    // distribute to spawner entities and set timers
    rem := waves.enemies_in_wave % len(spawners)
    per_spawner := waves.enemies_in_wave / len(spawners)

    for e in spawners {
        spawner := ecs.get_component(w, e, C_Spawner)

        spawner.enemies_left += per_spawner
        timer_set(&spawner.timer, SPAWN_RATE)
    }

    // apply the remainder
    s := ecs.get_component(w, spawners[0], C_Spawner)
    s.enemies_left += rem
}

spawner :: proc() {
    w := state.gs.world
    spawners := ecs.get_entities_with(w, C_Spawner)

    for e in spawners {
        spawner := ecs.get_component(w, e, C_Spawner)
        spawner_pos := ecs.get_component(w, e, C_Transform).pos

        if timer_done_reset(&spawner.timer) {
            if spawner.enemies_left > 0 {
                spawn_enemy(spawner_pos)
                spawner.enemies_left -= 1
            }

        }
    }
}

draw_spawner_remaining :: proc(renderer: r.Renderer) {
    w := state.gs.world
    spawners := ecs.get_entities_with(w, C_Spawner)

    for e in spawners {
        spawner := ecs.get_component(w, e, C_Spawner)
        spawner_pos := ecs.get_component(w, e, C_Transform).pos

        r.draw_text(
            renderer,
            fontIDs[.debug],
            fmt.tprint(spawner.enemies_left),
            **spawner_pos,
        )
    }
}
