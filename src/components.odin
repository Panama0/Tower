package main

import "vendor:sdl3"

C_Sprite :: struct {
    name:       SpriteName,
    draw_pivot: Pivot,
    flip_x:     bool,
    flip_y:     bool,
}

C_Transform :: struct {
    pos:          Vec2,
    rotation_deg: f64,
    pivot:        Pivot,
}

C_Animation :: struct {
    anim_index:             int,
    loop:                   bool,
    frame_duration_ms:      u64,
    next_frame_end_time_ms: u64,
}

// might use for spawner/turret, otherwise they both get a component
C_Tower :: struct {
    interval_ms:    u64,
    next_done_time: u64,
}

C_Spawner :: struct {
    interval_ms:    u64,
    next_done_time: u64,
}

C_Projectile :: struct {
    target: Vec2,
    speed:  f32,
    damage: f32,
}

//TODO: blank structs do not work!!
C_Enemy :: struct {
    test: int,
}
