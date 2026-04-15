package main

import "core:fmt"
import "core:log"
import "core:strings"

import sdl3 "vendor:sdl3"
import stbrp "vendor:stb/rect_pack"

Sprite :: struct {
    width, height: i32,
    uv:            sdl3.FRect,
}

Atlas :: struct {
    w, h:    int,
    // FIX: this needs to be deleted
    texture: ^sdl3.Texture,
}

load_sprites_and_atlas :: proc(renderer: ^sdl3.Renderer) {
    img_dir := "res/sprites/"


    SIZE :: 1024
    // hopefully this is the right pixelformat
    atlas_surface := sdl3.CreateSurface(SIZE, SIZE, .ABGR8888)
    if atlas_surface == nil {
        log.fatalf("Texture atlas failed to initialise: %v", sdl3.GetError())
    }
    defer {
        sdl3.DestroySurface(atlas_surface)
        atlas_surface = {}
    }

    state.atlas = {
        w = SIZE,
        h = SIZE,
    }

    surfaces: [SpriteName]^sdl3.Surface
    defer {
        for surface, name in surfaces {
            sdl3.DestroySurface(surface)
            surfaces = {}
        }
    }

    // load in sprites
    for name in SpriteName {
        if name == .nil do continue

        path := fmt.tprint(img_dir, name, ".png", sep = "")

        surface := sdl3.LoadPNG(
            strings.clone_to_cstring(path, context.temp_allocator),
        )
        if surface == nil {
            log.errorf("Could not find sprite at %v", path)
            continue
        }

        surfaces[name] = surface

        state.sprites[name] = {
            width  = surface.w,
            height = surface.h,
        }
    }

    // get rects from rect pack
    stbrp_context: stbrp.Context
    nodes: [SIZE]stbrp.Node
    stbrp.init_target(&stbrp_context, SIZE, SIZE, &nodes[0], SIZE)

    rects: [dynamic]stbrp.Rect
    defer delete(rects)

    for img, id in state.sprites {
        if img.width == 0 {
            continue
        }
        append(
            &rects,
            stbrp.Rect {
                id = i32(id),
                w = stbrp.Coord(img.width + 2),
                h = stbrp.Coord(img.height + 2),
            },
        )
    }

    ok := stbrp.pack_rects(&stbrp_context, &rects[0], i32(len(rects)))
    if ok == 0 {
        log.fatal("STBRP Failed to pack atlas rects")
    }

    // add the rects to the atlas and save the uv
    for rect in rects {
        spr_name := SpriteName(rect.id)
        spr := &state.sprites[spr_name]

        rect := sdl3.Rect{i32(rect.x), i32(rect.y), i32(rect.w), i32(rect.h)}

        sdl3.BlitSurface(surfaces[spr_name], nil, atlas_surface, &rect)

        // remove padding
        spr.uv = {f32(rect.x), f32(rect.y), f32(spr.width), f32(spr.height)}
    }

    tex := sdl3.CreateTextureFromSurface(renderer, atlas_surface)
    if tex == nil {
        log.fatal("Failed to create atlas texture: %v", sdl3.GetError())
    }

    state.atlas = {
        w       = SIZE,
        h       = SIZE,
        texture = tex,
    }

    sdl3.SavePNG(atlas_surface, "res/atlas.png")
}

draw_ent :: proc(e: Entity, renderer: ^sdl3.Renderer) {
    spr := state.sprites[e.sprite]
    dest := sdl3.FRect{e.pos.x, e.pos.y, f32(spr.width), f32(spr.height)}

    sdl3.RenderTexture(renderer, state.atlas.texture, &spr.uv, &dest)
}
