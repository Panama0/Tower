package tests

import ecs "../src/ecs"

import "core:testing"


@(test)
world_creation :: proc(t: ^testing.T) {
    w := ecs.make_world()
    testing.expect(t, w != nil, "world is not nil")
    testing.expect(t, w.next_id == 0, "next_id starts at 0")
    testing.expect(
        t,
        w.next_component_id == 0,
        "next_component_id starts at 0",
    )

    ecs.world_destroy(w)
}

@(test)
add_entity :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e1 := ecs.add_entity(w)
    testing.expect(t, e1 == 0, "first entity id is 0")

    e2 := ecs.add_entity(w)
    testing.expect(t, e2 == 1, "second entity id is 1")
}

@(test)
add_component :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e := ecs.add_entity(w)

    Position :: struct {
        x: f32,
        y: f32,
    }
    pos := ecs.add_component(w, e, Position)
    testing.expect(t, pos != nil, "component returned is not nil")
    pos.x = 10
    pos.y = 20

    retrieved := ecs.get_component(w, e, Position)
    testing.expect(t, retrieved.x == 10, "x value set correctly")
    testing.expect(t, retrieved.y == 20, "y value set correctly")
}

@(test)
has_component :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e := ecs.add_entity(w)

    Velocity :: struct {
        dx: f32,
        dy: f32,
    }

    has_vel := ecs.has_component(w, e, Velocity)
    testing.expect(t, !has_vel, "entity does not have Velocity before adding")

    ecs.add_component(w, e, Velocity)

    has_vel = ecs.has_component(w, e, Velocity)
    testing.expect(t, has_vel, "entity has Velocity after adding")
}

@(test)
remove_component :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e := ecs.add_entity(w)

    Position :: struct {
        x: f32,
        y: f32,
    }
    ecs.add_component(w, e, Position)

    has_pos := ecs.has_component(w, e, Position)
    testing.expect(t, has_pos, "entity has Position before removing")

    ecs.remove_component(w, e, Position)

    has_pos = ecs.has_component(w, e, Position)
    testing.expect(t, !has_pos, "entity no longer has Position after removing")
}

@(test)
get_component_returns_nil :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e := ecs.add_entity(w)

    Position :: struct {
        x: f32,
        y: f32,
    }

    retrieved := ecs.get_component(w, e, Position)
    testing.expect(
        t,
        retrieved == nil,
        "get_component returns nil for unregistered component",
    )
}

@(test)
multiple_components :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e := ecs.add_entity(w)

    Position :: struct {
        x: f32,
        y: f32,
    }
    Velocity :: struct {
        dx: f32,
        dy: f32,
    }

    pos := ecs.add_component(w, e, Position)
    pos.x = 5
    pos.y = 10

    vel := ecs.add_component(w, e, Velocity)
    vel.dx = 1
    vel.dy = 2

    testing.expect(t, ecs.has_component(w, e, Position), "has Position")
    testing.expect(t, ecs.has_component(w, e, Velocity), "has Velocity")

    retrieved_pos := ecs.get_component(w, e, Position)
    retrieved_vel := ecs.get_component(w, e, Velocity)

    testing.expect(t, retrieved_pos.x == 5, "Position x")
    testing.expect(t, retrieved_pos.y == 10, "Position y")
    testing.expect(t, retrieved_vel.dx == 1, "Velocity dx")
    testing.expect(t, retrieved_vel.dy == 2, "Velocity dy")
}

@(test)
component_id_registration :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e := ecs.add_entity(w)

    Position :: struct {
        x: f32,
        y: f32,
    }
    ecs.add_component(w, e, Position)

    id := ecs.id_of(w, Position)
    testing.expect(t, id == 1, "first component id is 1")
}

@(test)
get_entities_with :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e1 := ecs.add_entity(w)
    e2 := ecs.add_entity(w)
    e3 := ecs.add_entity(w)

    Position :: struct {
        x: f32,
        y: f32,
    }

    ecs.add_component(w, e1, Position)
    ecs.add_component(w, e2, Position)

    entities := ecs.get_entities_with(w, Position)
    testing.expect(t, len(entities) == 2, "two entities have Position")

    testing.expect(t, e1 == entities[0] || e1 == entities[1], "e1 in list")
    testing.expect(t, e2 == entities[0] || e2 == entities[1], "e2 in list")
}

@(test)
get_entities :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e1 := ecs.add_entity(w)
    e2 := ecs.add_entity(w)
    e3 := ecs.add_entity(w)

    Position :: struct {
        x: f32,
        y: f32,
    }
    ecs.add_component(w, e1, Position)
    ecs.add_component(w, e2, Position)
    ecs.add_component(w, e3, Position)


    entities: [dynamic]ecs.Entity
    defer delete(entities)
    ecs.get_entities(w, &entities)
    testing.expect(t, len(entities) == 3, "three entities alive")
}

@(test)
register_component :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    Position :: struct {
        x: f32,
        y: f32,
    }

    registered := ecs.is_registered(w, Position)
    testing.expect(t, !registered, "Position not registered before register_component")

    ecs.register_component(w, Position)

    registered = ecs.is_registered(w, Position)
    testing.expect(t, registered, "Position registered after register_component")
}

@(test)
register_component_idempotent :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    Position :: struct {
        x: f32,
        y: f32,
    }

    ecs.register_component(w, Position)
    id1 := ecs.id_of(w, Position)

    ecs.register_component(w, Position)
    id2 := ecs.id_of(w, Position)

    testing.expect(t, id1 == id2, "register_component is idempotent")
}

@(test)
alive_count :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e1 := ecs.add_entity(w)
    e2 := ecs.add_entity(w)

    testing.expect(t, w.alive_count == 2, "alive_count is 2")
    _ = e1
    _ = e2
}

@(test)
kill_entity :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)
    Position :: struct {
        x: f32,
        y: f32,
    }

    e := ecs.add_entity(w)
    ecs.add_component(w, e, Position)
    testing.expect(t, w.alive_count == 1, "alive_count is 1 before kill")

    ecs.kill_entity(w, e)
    testing.expect(t, w.alive_count == 0, "alive_count is 0 after kill")
    testing.expect(t, w.entity_components[e] == {}, "entity flags cleared")
}

@(test)
kill_entity_reuse_id :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)
    Position :: struct {
        x: f32,
        y: f32,
    }
    e1 := ecs.add_entity(w)
    ecs.add_component(w, e1, Position)
    e2 := ecs.add_entity(w)
    ecs.add_component(w, e2, Position)

    ecs.kill_entity(w, e1)

    e3 := ecs.add_entity(w)
    ecs.add_component(w, e3, Position)
    testing.expect(t, e3 == e1, "new entity reuses killed id")
    testing.expect(t, w.alive_count == 2, "alive_count is 2")
}

@(test)
get_entities_query :: proc(t: ^testing.T) {
    w := ecs.make_world()
    defer ecs.world_destroy(w)

    e1 := ecs.add_entity(w)
    e2 := ecs.add_entity(w)
    _ = ecs.add_entity(w)

    Position :: struct {
        x: f32,
        y: f32,
    }
    Velocity :: struct {
        dx: f32,
        dy: f32,
    }

    ecs.add_component(w, e1, Position)
    ecs.add_component(w, e1, Velocity)
    ecs.add_component(w, e2, Position)

    mask := ecs.query_mask(w, Position, Velocity)

    entities: [dynamic]ecs.Entity
    defer delete(entities)
    ecs.get_entities_query(w, mask, &entities)
    testing.expect(t, len(entities) == 1, "only e1 matches query")
    testing.expect(t, entities[0] == e1, "e1 has both Position and Velocity")
}
