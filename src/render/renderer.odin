package render

import "core:container/queue"
import "core:fmt"
import "core:log"
import vmem "core:mem/virtual"
import "core:strings"

import sdl3 "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
import stbrp "vendor:stb/rect_pack"

Vec2 :: [2]f32
Vec2i :: [2]i32

Pivot :: enum {
    centre,
    top_left,
    top_right,
    bottom_left,
    bottom_right,
}

pivot_vectors: [Pivot]Vec2 = {
    .centre       = {0.5, 0.5},
    .top_left     = {0.0, 0.0},
    .top_right    = {1.0, 0.0},
    .bottom_left  = {0.0, 1.0},
    .bottom_right = {1.0, 1.0},
}

AssetID :: distinct u16

Sprite :: struct {
    width, height: i32,
    uv:            Vec2,
    file_name:     string,
}

Atlas :: struct {
    w, h:    int,
    texture: ^sdl3.Texture,
    dirty:   bool,
}

Camera :: struct {
    target:                  Vec2, // focus of camera
    view_width, view_height: f32,
}

// renderer data
Renderer :: struct {
    sdl_renderer: ^sdl3.Renderer,
    logical_size: Vec2i,
    cam:          Camera,
    atlas:        Atlas,
    // make these handle maps later?
    sprites:      map[AssetID]Sprite,
    fonts:        map[AssetID]^ttf.Font,
    // ids
    nextID:       AssetID,
    freeIDs:      queue.Queue(AssetID),
    // memory
    arena:        vmem.Arena,
}

//TODO: Error handling
@(private = "file")
next_id :: proc(renderer: ^Renderer) -> (id: AssetID) {
    if queue.len(renderer.freeIDs) > 0 {
        id = queue.pop_front(&renderer.freeIDs)
    } else {
        id = renderer.nextID
        renderer.nextID += 1
    }

    return
}

// must be called before use
renderer_init :: proc(
    renderer: ^Renderer,
    window: ^sdl3.Window,
    logical_size: Vec2i,
) {
    renderer.sdl_renderer = sdl3.CreateRenderer(window, "")
    if renderer.sdl_renderer == nil do log.panicf("Could not create renderer with error: %v", sdl3.GetError())

    renderer.logical_size = logical_size

    sdl3.SetRenderLogicalPresentation(
        renderer.sdl_renderer,
        logical_size.x,
        logical_size.y,
        .INTEGER_SCALE,
    )

    // for opacity
    sdl3.SetRenderDrawBlendMode(renderer.sdl_renderer, {.BLEND})

    // fonts
    if !ttf.Init() {
        log.fatalf("ttf init failed with error: %v", sdl3.GetError())
    }

    // init memory
    allocator := vmem.arena_allocator(&renderer.arena)
    renderer.sprites = make(map[AssetID]Sprite, allocator)
    renderer.fonts = make(map[AssetID]^ttf.Font, allocator)
    queue.init(&renderer.freeIDs, allocator = allocator)
}

renderer_shutdown :: proc(renderer: ^Renderer) {
    for id, font in renderer.fonts {
        ttf.CloseFont(font)
    }

    sdl3.DestroyTexture(renderer.atlas.texture)

    sdl3.DestroyRenderer(renderer.sdl_renderer)

    vmem.arena_destroy(&renderer.arena)
}

renderer_new_frame :: proc(renderer: ^Renderer) {
    // clear screen
    sdl3.SetRenderDrawColor(renderer.sdl_renderer, 245, 235, 220, 255)
    sdl3.RenderClear(renderer.sdl_renderer)
    // regenerate the atlas if dirty
    if renderer.atlas.dirty {
        generate_atlas(renderer)
    }
}

renderer_end_frame :: proc(renderer: ^Renderer) {
    sdl3.RenderPresent(renderer.sdl_renderer)
}

add_sprite :: proc(renderer: ^Renderer, file_name: string) -> AssetID {
    id := next_id(renderer)

    renderer.sprites[id] = {
        file_name = file_name,
    }

    // mark atlas dirty
    renderer.atlas.dirty = true

    return id
}

remove_sprite :: proc(renderer: ^Renderer, spriteID: AssetID) {
    delete_key(&renderer.sprites, spriteID)
    queue.push(&renderer.freeIDs, spriteID)
    // mark atlas dirty
    renderer.atlas.dirty = true
}

// called automatically when needed
@(private = "file")
generate_atlas :: proc(renderer: ^Renderer) {
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

    renderer.atlas = {
        w = SIZE,
        h = SIZE,
    }

    surfaces: map[AssetID]^sdl3.Surface
    defer {
        for id, surface in surfaces {
            sdl3.DestroySurface(surface)
        }
        delete(surfaces)
    }

    // load in sprites

    allocator := vmem.arena_allocator(&renderer.arena)
    for spriteID, &sprite in renderer.sprites {
        path := fmt.aprint(
            img_dir,
            sprite.file_name,
            ".png",
            sep = "",
            allocator = allocator,
        )

        surface := sdl3.LoadPNG(
            strings.clone_to_cstring(path, context.temp_allocator),
        )
        if surface == nil {
            log.errorf("Could not find sprite at %v", path)
            continue
        }

        sprite.width = surface.w
        sprite.height = surface.h

        surfaces[spriteID] = surface
    }

    // get rects from rect pack
    stbrp_context: stbrp.Context
    nodes: [SIZE]stbrp.Node
    stbrp.init_target(&stbrp_context, SIZE, SIZE, &nodes[0], SIZE)

    rects: [dynamic]stbrp.Rect
    defer delete(rects)

    for id, sprite in renderer.sprites {
        append(
            &rects,
            stbrp.Rect {
                id = i32(id),
                w = stbrp.Coord(sprite.width + 2),
                h = stbrp.Coord(sprite.height + 2),
            },
        )
    }

    ok := stbrp.pack_rects(&stbrp_context, &rects[0], i32(len(rects)))
    if ok == 0 {
        log.fatal("STBRP Failed to pack atlas rects")
        return
    }

    // add the rects to the atlas and save the uv
    for rect in rects {
        id := AssetID(rect.id)
        spr := &renderer.sprites[id]

        rect := sdl3.Rect{i32(rect.x), i32(rect.y), i32(rect.w), i32(rect.h)}

        sdl3.BlitSurface(surfaces[id], nil, atlas_surface, &rect)

        // save the texture coords
        spr.uv = {f32(rect.x), f32(rect.y)}
    }

    tex := sdl3.CreateTextureFromSurface(renderer.sdl_renderer, atlas_surface)
    if tex == nil {
        log.fatal("Failed to create atlas texture: %v", sdl3.GetError())
        return
    }

    sdl3.SetTextureScaleMode(tex, .NEAREST)

    renderer.atlas = {
        w       = SIZE,
        h       = SIZE,
        texture = tex,
    }

    log.debug("Generated atlas")
    renderer.atlas.dirty = false
}


load_font :: proc(
    renderer: ^Renderer,
    file_name: string,
    size: f32,
) -> (
    id: AssetID,
    ok: bool,
) {
    FONT_DIR :: "res/fonts/"
    id = next_id(renderer)

    path := fmt.tprint(FONT_DIR, file_name, ".ttf", sep = "")

    allocator := vmem.arena_allocator(&renderer.arena)

    font := ttf.OpenFont(strings.clone_to_cstring(path, allocator), size)

    if font == nil {
        log.debugf(
            "Failed to load font %v with error: %v",
            path,
            sdl3.GetError(),
        )
        return 0, false
    }

    ttf.SetFontHinting(font, .NORMAL)

    renderer.fonts[id] = font

    return id, true
}

handle_resize :: proc(renderer: ^Renderer, new_size: Vec2i, old_size: Vec2i) {
    // scale text
    rect: sdl3.FRect
    sdl3.GetRenderLogicalPresentationRect(renderer.sdl_renderer, &rect)

    scale := rect.w / f32(old_size.x)

    for id, font in renderer.fonts {
        old_font_size := ttf.GetFontSize(font)
        ttf.SetFontSize(font, old_font_size * scale)
    }
}

// utils

//TODO: error checking?
sprite_dimensions :: proc(
    renderer: ^Renderer,
    spriteID: AssetID,
    frame_count: i32,
) -> Vec2i {
    spr := renderer.sprites[spriteID]
    width := spr.width / frame_count
    return {width, spr.height}
}

screen_to_world :: proc(renderer: Renderer, screen_pos: Vec2i) -> Vec2 {
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

world_to_screen_vec :: proc(renderer: Renderer, pos: Vec2) -> Vec2 {
    cam := renderer.cam
    return(
        pos -
        {
                cam.target.x - cam.view_width / 2,
                cam.target.y - cam.view_height / 2,
            } \
    )
}

world_to_screen_xy :: proc(
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

world_to_screen :: proc {
    world_to_screen_vec,
    world_to_screen_xy,
}
