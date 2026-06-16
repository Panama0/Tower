package ecs

import "core:container/queue"

Entity :: u64
// has to be an int i guess
ComponentID :: int

MAX_ENTITIES :: 1024
MAX_COMPONENTS :: 64


ComponentFlags :: bit_set[0 ..< MAX_COMPONENTS]

ComponentArray :: struct($T: typeid) {
    data: [MAX_ENTITIES]T,
}

CleanFunc :: proc(e: Entity)

World :: struct {
    alive_count:           Entity,
    next_id:               Entity,
    free_ids:              queue.Queue(Entity),
    next_component_id:     ComponentID,
    components:            map[typeid]rawptr,
    component_ids:         map[typeid]ComponentID,
    component_clean_funcs: map[typeid]CleanFunc,

    // keep track of what components each entity has
    entity_components:     map[Entity]ComponentFlags,
    component_entities:    map[typeid][dynamic]Entity,
}

default_clean_func: CleanFunc = {}

// get all alive, O(n)
get_entities :: proc(w: ^World, out: ^[dynamic]Entity) {
    for e, flags in w.entity_components {
        if flags != {} {
            append(out, e)
        }
    }
}

query_mask :: proc(w: ^World, types: ..typeid) -> ComponentFlags {
    mask: ComponentFlags
    for t in types {
        id, ok := w.component_ids[t]
        if ok do mask += {id}
    }
    return mask
}

get_entities_query :: proc(
    w: ^World,
    mask: ComponentFlags,
    out: ^[dynamic]Entity,
) {
    for e, flags in w.entity_components {
        if mask <= flags {
            append(out, e)
        }
    }
}

get_entities_with :: proc(w: ^World, $T: typeid) -> []Entity {
    if T in w.component_entities {
        return w.component_entities[T][:]
    } else {
        return {}
    }
}

add_entity :: proc(w: ^World) -> Entity {
    w.alive_count += 1
    if queue.len(w.free_ids) > 0 {
        return queue.pop_front(&w.free_ids)
    }
    e := w.next_id
    w.next_id += 1

    assert(w.next_id <= max(Entity), "MAX ENTITIES REACHED")
    return e
}

// O(n) with regards to components
kill_entity :: proc(w: ^World, e: Entity) {
    assert(w.alive_count > 0, "No entities alive")
    flags := w.entity_components[e]
    // if dead, ignore
    if flags == {} do return

    // call clean funcs for each component
    for type, id in w.component_ids {
        if id in flags {
            if clean_func, ok := w.component_clean_funcs[type];
               ok && clean_func != nil {
                clean_func(e)
            }
        }
    }

    // remove from all component entity lists
    for component in w.component_entities {
        for ent, i in w.component_entities[component] {
            if ent == e {
                unordered_remove(&w.component_entities[component], i)
                break
            }
        }

    }

    // clear the entity's component flags
    w.entity_components[e] = {}
    w.alive_count -= 1
    queue.push_back(&w.free_ids, e)
}

is_alive :: proc(w: ^World, e: Entity) -> bool {
    flags := w.entity_components[e]
    return flags != {}
}

make_world :: proc() -> ^World {
    w := new(World)
    // w.components = make(map[typeid]rawptr)
    //TODO: have to make the rest?
    return w
}

world_destroy :: proc(w: ^World) {
    for _, data in w.components {
        free(data)
    }
    delete(w.components)
    delete(w.component_ids)
    delete(w.entity_components)
    for _, entities in w.component_entities {
        delete(entities)
    }
    delete(w.component_entities)
    queue.destroy(&w.free_ids)
    delete(w.component_clean_funcs)
    free(w)
}

// needed so that we can use the bitset with typeid
id_of :: proc(w: ^World, $T: typeid) -> ComponentID {
    return w.component_ids[T]
}

has_component :: proc(w: ^World, e: Entity, $T: typeid) -> bool {
    return id_of(w, T) in w.entity_components[e]
}

register_component :: proc(
    w: ^World,
    $T: typeid,
    clean_func := default_clean_func,
) {
    if T in w.components {
        return
    }
    assert(w.next_component_id < MAX_COMPONENTS, "MAX COMPONENTS REACHED")
    arr := new(ComponentArray(T))
    w.components[T] = arr

    w.next_component_id += 1
    w.component_ids[T] = w.next_component_id

    w.component_clean_funcs[T] = clean_func
}

is_registered :: proc(w: ^World, $T: typeid) -> bool {
    return T in w.components
}

add_component :: proc(w: ^World, e: Entity, $T: typeid) -> ^T {
    // register if not done already
    register_component(w, T)

    store := w.components[T]
    arr := transmute(^ComponentArray(T))store
    assert(store != nil, "Component type not registered")
    arr.data[e] = T{} // zero initialize the slot


    if !has_component(w, e, T) {
        if !(T in w.component_entities) {
            w.component_entities[T] = make([dynamic]Entity)
        }
        entities := &w.component_entities[T]
        append(entities, e)
    }

    w.entity_components[e] += {id_of(w, T)}

    return &arr.data[e]
}

get_component :: proc(w: ^World, e: Entity, $T: typeid) -> ^T {
    if !is_registered(w, T) {
        return nil
    }
    arr := transmute(^ComponentArray(T))w.components[T]
    if arr == nil do return nil
    val := &arr.data[e]
    return val
}

// this is O(n) with regards to entities
remove_component :: proc(w: ^World, e: Entity, $T: typeid) {
    arr := transmute(^ComponentArray(T))w.components[T]
    if !has_component(w, e, T) do return

    clean_func := w.component_clean_funcs[T]
    if clean_func != nil {
        clean_func(e)
    }

    arr.data[e] = {}
    w.entity_components[e] -= {id_of(w, T)}

    // clear from component lists
    for ent, i in w.component_entities[T] {
        if e == ent {
            unordered_remove(&w.component_entities[T], i)
            break
        }
    }
}
