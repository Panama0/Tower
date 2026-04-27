package main

import "vendor:sdl3"

FlipMode :: enum {
    nil,
    flip_x,
    rotate,
}

C_Sprite :: struct {
    name:       SpriteName,
    draw_pivot: Pivot,
    flip_mode:  FlipMode, // how or if to flip the sprite when drawing based on velocity
    flip_state: sdl3.FlipMode,
}

AnimationState :: enum {
    default,
    walk,
}

C_AnimationController :: struct {
    animations:             [AnimationState]SpriteName,
    current:                AnimationState,
    anim_index:             int,
    loop:                   bool,
    frame_duration_ms:      u64,
    next_frame_end_time_ms: u64,
}

C_Transform :: struct {
    pos:          Vec2,
    vel:          Vec2,
    rotation_deg: f64,
    pivot:        Pivot,
    last_dir:     Vec2, // needed as vel is reset/changed after application
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
    damage: f32,
}

//TODO: blank structs do not work!!
C_Enemy :: struct {
    test: int,
}

C_MovementController :: struct {
    target_dir: Vec2,
    speed:      f32,
}

C_Input :: struct {
    input_dir: Vec2,
}
