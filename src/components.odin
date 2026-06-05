package main

import "vendor:sdl3"

import "ecs"

FlipMode :: enum {
    nil,
    flip_x,
    rotate,
}

Timer :: struct {
    interval_ms:    u64,
    next_done_time: u64,
}

C_Sprite :: struct {
    name:         SpriteName,
    draw_pivot:   Pivot,
    rotation_deg: f64,
    flip_mode:    FlipMode, // how or if to flip the sprite when drawing based on velocity
    flip_state:   sdl3.FlipMode,
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
    pos:      Vec2,
    vel:      Vec2,
    // pivot:        Pivot,
    last_dir: Vec2, // needed as vel is reset/changed after application
}

// might use for spawner/turret, otherwise they both get a component
C_Tower :: struct {
    timer: Timer,
}

C_Spawner :: struct {
    timer: Timer,
}

C_Projectile :: struct {
    damage: f32,
}

C_Enemy :: struct {
    nothing: int,
}

C_Health :: struct {
    max_health:     int,
    current_health: int,
    damage_resist:  int,
}

C_Attack :: struct {
    damage:         int,
    knockback:      f32, // can be applied to pulse
    cooldown_timer: Timer,
}

C_MovementController :: struct {
    target_dir: Vec2,
    speed:      f32,
}

C_Pulse :: struct {
    vel:   Vec2,
    decay: f32,
}

C_Input :: struct {
    input_dir: Vec2,
}

C_AABBCollider :: struct {
    rect:     sdl3.FRect, // offset from the pos
    hit_proc: proc(self: ecs.Entity, other: ecs.Entity),
    physical: bool, // does the collider hit other objects
    static:   bool,
}


C_PathfindingTags :: struct {
    bounds: sdl3.FRect, // bounds are needed to generate the pf map weights
    tags:   bit_set[PFTags],
}
