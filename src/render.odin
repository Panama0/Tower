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

Camera :: struct {
    target:                  Vec2, // focus of camera
    view_width, view_height: f32,
}

Renderer :: struct {
    sdl_renderer: ^sdl3.Renderer,
    cam:          Camera,
}

make_renderer :: proc(window: ^sdl3.Window, w, h: i32) -> Renderer {
    renderer := sdl3.CreateRenderer(window, "")
    if renderer == nil do log.panicf("Could not create renderer with errror: %v", sdl3.GetError())

    // we can do stretching/letterbox via
    sdl3.SetRenderLogicalPresentation(renderer, w, h, .INTEGER_SCALE)

    // for opacity
    sdl3.SetRenderDrawBlendMode(renderer, {.BLEND})

    // fonts

    if !ttf.Init() {
        log.fatalf("ttf init failed with error: %v", sdl3.GetError())
    }

    // init "renderer"
    load_sprites_and_atlas(renderer)
    load_fonts()

    return {sdl_renderer = renderer}
}

render_shutdown :: proc(renderer: Renderer) {
    for font in state.fonts {
        ttf.CloseFont(font)
    }

    sdl3.DestroyRenderer(renderer.sdl_renderer)
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

        if font == nil {
            log.debugf(
                "Failed to load font %v with error: %v",
                path,
                sdl3.GetError(),
            )
            return
        }

        ttf.SetFontHinting(font, .NORMAL)

        state.fonts[style] = font
    }
}

render_screen_to_world :: proc(renderer: Renderer, screen_pos: Vec2i) -> Vec2 {
    world_x, world_y: f32
    sdl3.RenderCoordinatesFromWindow(
        renderer.sdl_renderer,
        f32(screen_pos.x),
        f32(screen_pos.y),
        &world_x,
        &world_y,
    )
    cam := renderer.cam
    return {
        world_x + cam.target.x - cam.view_width / 2,
        world_y + cam.target.y - cam.view_height / 2,
    }
}

render_world_to_screen_vec :: proc(renderer: Renderer, pos: Vec2) -> Vec2 {
    cam := renderer.cam
    return(
        pos -
        {
                cam.target.x - cam.view_width / 2,
                cam.target.y - cam.view_height / 2,
            } \
    )
}

render_world_to_screen_xy :: proc(
    renderer: Renderer,
    x, y: f32,
) -> (
    new_x, new_y: f32,
) {
    cam := renderer.cam
    new_x = x - cam.target.x + cam.view_width / 2
    new_y = y - cam.target.y + cam.view_height / 2
    return
}

render_world_to_screen :: proc {
    render_world_to_screen_vec,
    render_world_to_screen_xy,
}

// draw text at native res
render_draw_text :: proc(
    renderer: Renderer,
    style: FontStyle,
    text: string,
    x, y: f32,
    colour: sdl3.Color = {0, 0, 0, 255},
) {
    // save the old logical presentation settings
    logical_w, logical_h: i32
    mode: sdl3.RendererLogicalPresentation
    sdl3.GetRenderLogicalPresentation(
        renderer.sdl_renderer,
        &logical_w,
        &logical_h,
        &mode,
    )

    // apply camera transform
    cam_x, cam_y := render_world_to_screen(renderer, x, y)

    // save the coords that we would have drawn at in the window
    win_x, win_y: f32
    sdl3.RenderCoordinatesToWindow(
        renderer.sdl_renderer,
        cam_x,
        cam_y,
        &win_x,
        &win_y,
    )

    // clear out logical presentation and defer restoration
    sdl3.SetRenderLogicalPresentation(renderer.sdl_renderer, 0, 0, .DISABLED)
    defer sdl3.SetRenderLogicalPresentation(
        renderer.sdl_renderer,
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

    texture := sdl3.CreateTextureFromSurface(renderer.sdl_renderer, surface)

    if texture == nil {
        log.debugf("Failed to create texture with error: %v", sdl3.GetError())
        return
    }
    defer sdl3.DestroyTexture(texture)

    // remember that we are drawing it at the window x and y because we are now at native res
    dst := sdl3.FRect {
        x = win_x,
        y = win_y,
        w = f32(surface.w),
        h = f32(surface.h),
    }


    sdl3.RenderTexture(renderer.sdl_renderer, texture, nil, &dst)
}


render_draw_rect :: proc(
    renderer: Renderer,
    rect: ^sdl3.FRect,
    r: sdl3.Uint8,
    g: sdl3.Uint8,
    b: sdl3.Uint8,
    a: sdl3.Uint8 = 255,
    fill := true,
) {
    new_x, new_y := render_world_to_screen(renderer, rect.x, rect.y)
    new_rect := sdl3.FRect{new_x, new_y, rect.w, rect.h}

    old_r, old_g, old_b, old_a: sdl3.Uint8
    sdl3.GetRenderDrawColor(
        renderer.sdl_renderer,
        &old_r,
        &old_g,
        &old_b,
        &old_a,
    )
    sdl3.SetRenderDrawColor(renderer.sdl_renderer, r, g, b, a)

    if fill do sdl3.RenderFillRect(renderer.sdl_renderer, &new_rect)
    else do sdl3.RenderRect(renderer.sdl_renderer, &new_rect)

    sdl3.SetRenderDrawColor(renderer.sdl_renderer, old_r, old_g, old_b, old_a)
}

render_draw_sprite :: proc(
    renderer: Renderer,
    spr: Sprite,
    pos: Vec2,
    pivot: Pivot = .centre,
    rotation_deg := 0.0,
    flip := sdl3.FlipMode{},
    frame_count := 0,
    current_frame := 0,
) {
    src := spr.uv
    dest := sdl3.FRect{**pos, f32(spr.width), f32(spr.height)}

    if frame_count > 1 {
        frame_offset := int(spr.width) / frame_count
        src.w = f32(frame_offset)
        src.x += f32(frame_offset * current_frame)
        dest.w = f32(frame_offset)
    }

    pivot_offset := pivot_to_vec(pivot)
    pivot_point := sdl3.FPoint{src.w * pivot_offset.x, src.h * pivot_offset.y}

    dest.x -= dest.w * pivot_offset.x
    dest.y -= dest.h * pivot_offset.y

    dest.x, dest.y = render_world_to_screen(renderer, dest.x, dest.y)

    sdl3.RenderTextureRotated(
        renderer.sdl_renderer,
        state.atlas.texture,
        &src,
        &dest,
        rotation_deg,
        &pivot_point,
        flip,
    )
}

// draw a circle and reset colour after
// no idea how this works
render_draw_circle :: proc(
    renderer: Renderer,
    radius: f32,
    cx, cy: f32,
    r: sdl3.Uint8,
    g: sdl3.Uint8,
    b: sdl3.Uint8,
    a: sdl3.Uint8 = 255,
) {
    new_x, new_y := render_world_to_screen(renderer, cx, cy)

    old_r, old_g, old_b, old_a: sdl3.Uint8
    sdl3.GetRenderDrawColor(
        renderer.sdl_renderer,
        &old_r,
        &old_g,
        &old_b,
        &old_a,
    )
    sdl3.SetRenderDrawColor(renderer.sdl_renderer, r, g, b, a)

    for dy: f32 = -radius; dy <= radius; dy += 1 {
        dx := math.sqrt(radius * radius - dy * dy)
        sdl3.RenderLine(
            renderer.sdl_renderer,
            new_x - dx,
            new_y + dy,
            new_x + dx,
            new_y + dy,
        )
    }

    sdl3.SetRenderDrawColor(renderer.sdl_renderer, old_r, old_g, old_b, old_a)
}
