package render

import "core:log"
import "core:math"
import "core:strings"

import "vendor:sdl3"
import ttf "vendor:sdl3/ttf"


// draw text at native res
render_draw_text :: proc(
    renderer: Renderer,
    fontID: AssetID,
    text: string,
    x, y: f32,
    colour: sdl3.Color = {0, 0, 0, 255},
) {
    font := renderer.fonts[fontID]
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
    spriteID: AssetID,
    pos: Vec2,
    pivot: Pivot = .centre,
    rotation_deg := 0.0,
    flip := sdl3.FlipMode{},
    frame_count := 0,
    current_frame := 0,
) {
    spr := renderer.sprites[spriteID]

    src := sdl3.FRect{spr.uv.x, spr.uv.y, f32(spr.width), f32(spr.height)}
    dest := sdl3.FRect{**pos, f32(spr.width), f32(spr.height)}

    if frame_count > 1 {
        frame_offset := int(spr.width) / frame_count
        src.w = f32(frame_offset)
        src.x += f32(frame_offset * current_frame)
        dest.w = f32(frame_offset)
    }

    pivot_offset := pivot_vectors[pivot]
    pivot_point := sdl3.FPoint{src.w * pivot_offset.x, src.h * pivot_offset.y}

    dest.x -= dest.w * pivot_offset.x
    dest.y -= dest.h * pivot_offset.y

    dest.x, dest.y = render_world_to_screen(renderer, dest.x, dest.y)

    sdl3.RenderTextureRotated(
        renderer.sdl_renderer,
        renderer.atlas.texture,
        &src,
        &dest,
        rotation_deg,
        &pivot_point,
        flip,
    )
}

render_handle_resize :: proc(
    renderer: ^Renderer,
    new_size: Vec2i,
    old_size: Vec2i,
) {
    // scale text
    rect: sdl3.FRect
    sdl3.GetRenderLogicalPresentationRect(renderer.sdl_renderer, &rect)

    scale := rect.w / f32(old_size.x)

    for id, font in renderer.fonts {
        old_font_size := ttf.GetFontSize(font)
        ttf.SetFontSize(font, old_font_size * scale)
    }
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
