package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"

import sdl3 "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
import stbrp "vendor:stb/rect_pack"

Sprite :: struct {
    width, height: i32,
    uv:            sdl3.FRect,
}

Atlas :: struct {
    w, h:    int,
    texture: ^sdl3.Texture,
}

load_sprites_and_atlas :: proc(renderer: ^sdl3.Renderer) {
    img_dir := "res/sprites/"
    //FIX: need default asset when not found


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

    sdl3.SetTextureScaleMode(tex, .NEAREST)

    state.atlas = {
        w       = SIZE,
        h       = SIZE,
        texture = tex,
    }

    sdl3.SavePNG(atlas_surface, "res/atlas.png")
}

load_fonts :: proc() {
    FONT_DIR :: "res/fonts/"

    for style in FontStyle {
        data := &font_data[style]
        path := fmt.tprint(FONT_DIR, data.family, ".ttf", sep = "")

        font := ttf.OpenFont(
            strings.clone_to_cstring(path, context.temp_allocator),
            data.size_pt,
        )

        ttf.SetFontHinting(font, .NORMAL)

        if font == nil {
            log.debugf(
                "Failed to load font %v with error: %v",
                path,
                sdl3.GetError(),
            )
        }

        state.fonts[style] = font
    }
}

// draw text at native res
draw_text :: proc(
    renderer: ^sdl3.Renderer,
    style: FontStyle,
    text: string,
    x, y: f32,
    colour: sdl3.Color = {0, 0, 0, 255},
) {
    // save the old logical presentation settings
    logical_w, logical_h: i32
    mode: sdl3.RendererLogicalPresentation
    sdl3.GetRenderLogicalPresentation(renderer, &logical_w, &logical_h, &mode)

    // save the coords in world space
    win_x, win_y: f32
    sdl3.RenderCoordinatesToWindow(renderer, x, y, &win_x, &win_y)

    // clear out logical presentation and defer restoration
    sdl3.SetRenderLogicalPresentation(renderer, 0, 0, .DISABLED)
    defer sdl3.SetRenderLogicalPresentation(
        renderer,
        logical_w,
        logical_h,
        mode,
    )

    font := state.fonts[style]

    surface := ttf.RenderText_Blended(
        font,
        strings.clone_to_cstring(text, context.temp_allocator),
        0,
        colour,
    )

    if surface == nil {
        log.debugf(
            "Failed to render text '%v' with error: %v",
            text,
            sdl3.GetError(),
        )
        return
    }
    defer sdl3.DestroySurface(surface)

    texture := sdl3.CreateTextureFromSurface(renderer, surface)

    if texture == nil {
        log.debugf("Failed to create texture with error: %v", sdl3.GetError())
        return
    }
    defer sdl3.DestroyTexture(texture)

    dst := sdl3.FRect {
        x = win_x,
        y = win_y,
        w = f32(surface.w),
        h = f32(surface.h),
    }

    sdl3.RenderTexture(renderer, texture, nil, &dst)
}

// draw a rect and reset the colour after
draw_rect :: proc(
    renderer: ^sdl3.Renderer,
    rect: ^sdl3.FRect,
    r: sdl3.Uint8,
    g: sdl3.Uint8,
    b: sdl3.Uint8,
    a: sdl3.Uint8 = 255,
) {
    old_r, old_g, old_b, old_a: sdl3.Uint8
    sdl3.GetRenderDrawColor(renderer, &old_r, &old_g, &old_b, &old_a)
    sdl3.SetRenderDrawColor(renderer, r, g, b, a)
    sdl3.RenderFillRect(renderer, rect)
    sdl3.SetRenderDrawColor(renderer, r, g, b, a)
}

// draw a circle and reset colour after
// no idea how this works
draw_circle :: proc(
    renderer: ^sdl3.Renderer,
    radius: f32,
    cx, cy: f32,
    r: sdl3.Uint8,
    g: sdl3.Uint8,
    b: sdl3.Uint8,
    a: sdl3.Uint8 = 255,
) {
    old_r, old_g, old_b, old_a: sdl3.Uint8
    sdl3.GetRenderDrawColor(renderer, &old_r, &old_g, &old_b, &old_a)
    sdl3.SetRenderDrawColor(renderer, r, g, b, a)

    for dy: f32 = -radius; dy <= radius; dy += 1 {
        dx := math.sqrt(radius * radius - dy * dy)
        sdl3.RenderLine(renderer, cx - dx, cy + dy, cx + dx, cy + dy)
    }

    sdl3.SetRenderDrawColor(renderer, r, g, b, a)
}
