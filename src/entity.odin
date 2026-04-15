package main

import "core:fmt"

import "vendor:sdl3"


EntityHandle :: struct {
    index: int,

    // I prefer assigning a unique ID to each entity, instead of going the generational
    // handle route. Makes trying to debug things a bit easier if we know for a fact
    // an entity cannot have the same ID as another one.
    id:    int,
}

Entity :: struct {
    handle:         EntityHandle,
    kind:           EntityKind,

    // todo, move this into static entity data
    update_proc:    proc(_: ^Entity),
    draw_proc:      proc(_: Entity, renderer: ^sdl3.Renderer),

    // big sloppy entity state dump.
    // add whatever you need in here.
    pos:            Vec2,
    rotation:       f32,
    sprite:         SpriteName,
    anim_index:     int,
    loop:           bool,
    frame_duration: f32,
}

zero_entity: Entity


entity_create :: proc(kind: EntityKind) -> ^Entity {
    index := -1
    if len(state.gs.entity_free_list) > 0 {
        index = pop(&state.gs.entity_free_list)
    }

    if index == -1 {
        assert(
            state.gs.entity_top_count + 1 < MAX_ENTITIES,
            "ran out of entities, increase size",
        )
        state.gs.entity_top_count += 1
        index = state.gs.entity_top_count
    }

    ent := &state.gs.entities[index]
    ent.handle.index = index
    ent.handle.id = state.gs.latest_entity_id + 1
    state.gs.latest_entity_id = ent.handle.id

    entity_setup(ent, kind)
    fmt.assertf(
        ent.kind != nil,
        "entity %v needs to define a kind during setup",
        kind,
    )

    return ent
}

entity_destroy :: proc(e: ^Entity) {
    append(&state.gs.entity_free_list, e.handle.index)
    e^ = {}
}

entity_from_handle :: proc(
    handle: EntityHandle,
) -> (
    entity: ^Entity,
    ok: bool,
) #optional_ok {
    if handle.index <= 0 || handle.index > state.gs.entity_top_count {
        return &zero_entity, false
    }

    ent := &state.gs.entities[handle.index]
    if ent.handle.id != handle.id {
        return &zero_entity, false
    }

    return ent, true
}

get_all_ents :: proc() -> []EntityHandle {
    return state.gs.scratch.all_entities
}

entity_is_valid :: proc(entity: ^Entity) -> bool {
    return entity != nil && entity^.handle.id != 0
}
