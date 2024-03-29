package editor

// `dqmake` is a simple DQM map editor

import "../game/gui"
import "../game/tiles"
import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

Vec2 :: rl.Vector2
IVec2 :: [2]i32
println :: fmt.println

windowSizeX: i32
windowSizeY: i32

delta: f32

ADD_MOUSE_BUTTON :: rl.MouseButton.LEFT
SUB_MOUSE_BUTTON :: rl.MouseButton.RIGHT

cameraPos: Vec2


Brush_Kind: enum {
    DRAW,
    BOX_FILL,
    BOX_EDGE,
}

isEditing: bool
isErasing: bool
startEditingMousePos: Vec2

FILE_MENU_MAX_ELEMS_COUNT :: 128
fileMenuElems: [FILE_MENU_MAX_ELEMS_COUNT]gui.Ui_Elem
fileMenuElemsCount: i32
fileMenuButtonBool: bool

Menu_Kind: enum {
    NONE,
    PAUSE,
    FILE,
    TILE,
}

tileMenuElems: [len(tiles.Tile)]gui.Ui_Elem
tileMenuButtonBool: bool

tileSelected: tiles.Tile = .FULL



TILE_WIDTH :: 22 // px
mapData: tiles.mapData_t

g_state.load_dir: string



main :: proc() {
    g_state.load_dir = filepath.clean(string(rl.GetWorkingDirectory()))

    rl.SetWindowState(
        {.WINDOW_RESIZABLE, .VSYNC_HINT}, //.WINDOW_TOPMOST,
    )
    rl.InitWindow(1920 / 1.5, 1080 / 1.5, "dqmake")
    rl.SetTargetFPS(60)
    rl.SetExitKey(rl.KeyboardKey.NULL)

    tiles.resetMap(&mapData)

    mapData.bounds = {24, 24}
    mapData.fullpath = fmt.aprint(
        args =  {
            g_state.load_dir,
            filepath.SEPARATOR_STRING,
            "maps",
            filepath.SEPARATOR_STRING,
            "new_dqmake_map.dqm",
        },
        sep = "",
    )

    gui.menuContext.normalFont = loadFont("germania_one.ttf")

    // init tile menu
    for kind, i in tiles.Tile {
        tileMenuElems[i] = gui.Ui_Button{fmt.aprint(rune(kind), "        ", kind), &tileMenuButtonBool}
    }

    for !rl.WindowShouldClose() {
        windowSizeX = rl.GetScreenWidth()
        windowSizeY = rl.GetScreenHeight()

        mapData.bounds.x = clamp(mapData.bounds.x, 0, tiles.MAP_MAX_SIZE - 1)
        mapData.bounds.y = clamp(mapData.bounds.y, 0, tiles.MAP_MAX_SIZE - 1)
        mapData.skyColor.r = clamp(mapData.skyColor.r, 0.0, 1.0)
        mapData.skyColor.g = clamp(mapData.skyColor.g, 0.0, 1.0)
        mapData.skyColor.b = clamp(mapData.skyColor.b, 0.0, 1.0)

        prevMenuKind := Menu_Kind

        _update :: proc() {
            if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
                if Menu_Kind != .NONE do Menu_Kind = .NONE
                else do Menu_Kind = .PAUSE
            }

            if rl.IsKeyPressed(rl.KeyboardKey.TAB) {
                if Menu_Kind == .TILE do Menu_Kind = .NONE
                else do Menu_Kind = .TILE
            }

            if Menu_Kind != .NONE do return
            gui.menuContext.startOffs = 0

            if rl.IsMouseButtonDown(rl.MouseButton.MIDDLE) {
                cameraPos.x += rl.GetMouseDelta().x
                cameraPos.y += rl.GetMouseDelta().y
                return
            }

            Brush_Kind = .DRAW
            if rl.IsKeyDown(rl.KeyboardKey.E) do Brush_Kind = .BOX_EDGE
            if rl.IsKeyDown(rl.KeyboardKey.B) do Brush_Kind = .BOX_FILL

            mousetile := calcMouseTilePos(rl.GetMousePosition())

            prevIsEditing := isEditing
            if !rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
                if rl.IsMouseButtonPressed(ADD_MOUSE_BUTTON) {
                    isEditing = true
                    isErasing = false
                    startEditingMousePos = rl.GetMousePosition()
                } else if rl.IsMouseButtonPressed(SUB_MOUSE_BUTTON) {
                    isEditing = true
                    isErasing = true
                    startEditingMousePos = rl.GetMousePosition()
                }
                if !rl.IsMouseButtonDown(ADD_MOUSE_BUTTON) && !rl.IsMouseButtonDown(SUB_MOUSE_BUTTON) {
                    isEditing = false
                }
                finishedEditing := prevIsEditing && !isEditing
                if finishedEditing do println("FINISHED EDITING")


                if (isEditing || finishedEditing) {
                    tile := isErasing ? tiles.Tile.NONE : tileSelected
                    switch Brush_Kind {
                    case .DRAW:
                        if isTilePosValid(mousetile) do mapData.tilemap[mousetile.x][mousetile.y] = tile
                    case .BOX_FILL:
                        if finishedEditing {
                            starttile := calcMouseTilePos(startEditingMousePos)
                            lowerleft := IVec2 {
                                glsl.min(starttile.x, mousetile.x),
                                glsl.min(starttile.y, mousetile.y),
                            }
                            upperright := IVec2 {
                                glsl.max(starttile.x, mousetile.x),
                                glsl.max(starttile.y, mousetile.y),
                            }
                            for x := lowerleft.x; x <= upperright.x; x += 1 {
                                for y := lowerleft.y; y <= upperright.y; y += 1 {
                                    if isTilePosValid({x, y}) do mapData.tilemap[x][y] = tile
                                }
                            }
                        }
                    case .BOX_EDGE:
                        if finishedEditing {
                            starttile := calcMouseTilePos(startEditingMousePos)
                            lowerleft := IVec2 {
                                glsl.min(starttile.x, mousetile.x),
                                glsl.min(starttile.y, mousetile.y),
                            }
                            upperright := IVec2 {
                                glsl.max(starttile.x, mousetile.x),
                                glsl.max(starttile.y, mousetile.y),
                            }
                            for x := lowerleft.x; x <= upperright.x; x += 1 {
                                if isTilePosValid({x, lowerleft.y}) do mapData.tilemap[x][lowerleft.y] = tile
                            }
                            for x := lowerleft.x; x <= upperright.x; x += 1 {
                                if isTilePosValid({x, upperright.y}) do mapData.tilemap[x][upperright.y] = tile
                            }
                            for y := lowerleft.y; y <= upperright.y; y += 1 {
                                if isTilePosValid({lowerleft.x, y}) do mapData.tilemap[lowerleft.x][y] = tile
                            }
                            for y := lowerleft.y; y <= upperright.y; y += 1 {
                                if isTilePosValid({upperright.x, y}) do mapData.tilemap[upperright.x][y] = tile
                            }
                        }
                    }
                }
            } else {     // tile picking
                isEditing = false
                isErasing = false

                if rl.IsMouseButtonDown(ADD_MOUSE_BUTTON) {
                    tileSelected = mapData.tilemap[mousetile.x][mousetile.y]
                }
            }
        };_update()



        rl.BeginDrawing()
        rl.ClearBackground(rl.ColorFromNormalized(gui.BACKGROUND))
        //rl.DrawText(fmt.tprint("window X", windowSizeX), 0, 0, 10, rl.RED)
        _draw :: proc() {
            //gui.drawText({100,100}, 25, rl.RED, fmt.tprint("window X", windowSizeX))
            //rl.DrawRectangleV(cameraPos, {100,100}, rl.RED)

            // update GUI context
            gui.menuContext.windowSizeX = windowSizeX
            gui.menuContext.windowSizeY = windowSizeY
            gui.menuContext.delta = delta

            for x: i32 = 0; x < mapData.bounds.x; x += 1 {
                for y: i32 = 0; y < mapData.bounds.y; y += 1 {
                    W :: 12
                    col := rl.Color{100, 100, 100, 100}

                    #partial switch mapData.tilemap[x][y] {
                    case .NONE:
                        col.a = 0
                    case .FULL:
                        col = {120, 120, 120, 255}
                    case .START_LOWER, .START_UPPER:
                        col = {100, 200, 200, 200}
                    case .FINISH_LOWER, .FINISH_UPPER:
                        col = {150, 100, 250, 200}
                    case .PICKUP_HEALTH_LOWER, .PICKUP_HEALTH_UPPER:
                        col = {100, 200, 100, 200}
                    case .ENEMY_GRUNT_LOWER, .ENEMY_GRUNT_UPPER, .ENEMY_KNIGHT_LOWER, .ENEMY_KNIGHT_UPPER:
                        col = {200, 100, 100, 200}
                    case .GUN_SHOTGUN_LOWER, .GUN_SHOTGUN_UPPER, .GUN_MACHINEGUN_LOWER, .GUN_MACHINEGUN_UPPER, .GUN_LASERRIFLE_LOWER, .GUN_LASERRIFLE_UPPER:
                        col = {150, 150, 50, 200}
                    }

                    drawTile({x, y}, col, fmt.tprint(rune(mapData.tilemap[x][y])))
                }
            }

            for i: i32 = 0; i < mapData.bounds.x; i += 10 do drawTile({i, -1}, {0, 0, 0, 0}, fmt.tprint(i))
            for i: i32 = 0; i < mapData.bounds.x; i += 10 do drawTile({i, mapData.bounds.y}, {0, 0, 0, 0}, fmt.tprint(i))
            for i: i32 = 0; i < mapData.bounds.y; i += 10 do drawTile({-1, i}, {0, 0, 0, 0}, fmt.tprint(i))
            for i: i32 = 0; i < mapData.bounds.y; i += 10 do drawTile({mapData.bounds.x, i}, {0, 0, 0, 0}, fmt.tprint(i))

            mousetile := calcMouseTilePos(rl.GetMousePosition())
            cursorcol := rl.GRAY
            if isEditing do cursorcol = isErasing ? {200, 100, 100, 200} : {100, 200, 200, 200}

            if Menu_Kind == .NONE {
                switch Brush_Kind {
                case .DRAW:
                    drawTileLines(mousetile, cursorcol)
                case .BOX_FILL:
                    drawTileLines(mousetile, cursorcol)
                    if isEditing {
                        starttile := calcMouseTilePos(startEditingMousePos)
                        lowerleft := IVec2 {
                            glsl.min(starttile.x, mousetile.x),
                            glsl.min(starttile.y, mousetile.y),
                        }
                        upperright := IVec2 {
                            glsl.max(starttile.x, mousetile.x),
                            glsl.max(starttile.y, mousetile.y),
                        }
                        dragcol := cursorcol
                        dragcol.a /= 2
                        for x := lowerleft.x; x <= upperright.x; x += 1 {
                            for y := lowerleft.y; y <= upperright.y; y += 1 {
                                drawTile({x, y}, dragcol, "")
                            }
                        }
                    }
                case .BOX_EDGE:
                    drawTileLines(mousetile, cursorcol)
                    if isEditing {
                        starttile := calcMouseTilePos(startEditingMousePos)
                        lowerleft := IVec2 {
                            glsl.min(starttile.x, mousetile.x),
                            glsl.min(starttile.y, mousetile.y),
                        }
                        upperright := IVec2 {
                            glsl.max(starttile.x, mousetile.x),
                            glsl.max(starttile.y, mousetile.y),
                        }
                        dragcol := cursorcol
                        dragcol.a /= 2
                        for x := lowerleft.x; x <= upperright.x; x += 1 do drawTile({x, lowerleft.y}, dragcol, "")
                        for x := lowerleft.x; x <= upperright.x; x += 1 do drawTile({x, upperright.y}, dragcol, "")
                        for y := lowerleft.y; y <= upperright.y; y += 1 do drawTile({lowerleft.x, y}, dragcol, "")
                        for y := lowerleft.y; y <= upperright.y; y += 1 do drawTile({upperright.x, y}, dragcol, "")
                    }
                }
            }

            gui.drawText({10, 10}, 25, gui.ACTIVE_COLOR, fmt.tprint("brush :   ", Brush_Kind))
            gui.drawText(
                {10, 40},
                25,
                gui.ACTIVE_COLOR,
                fmt.tprint("tile :       ", rune(tileSelected), tileSelected),
            )

            // gui.drawText({10, 70}, 25, gui.ACTIVE_COLOR, fmt.tprint("Menu_Kind", Menu_Kind))

            gui.drawText({10, f32(windowSizeY) - 50}, 25, gui.INACTIVE_VAL_COLOR, mapData.fullpath)

            if Menu_Kind != .NONE do rl.DrawRectangle(0, 0, windowSizeX, windowSizeY, {10, 10, 10, 200})

            rl.DrawRectangleV(
                {0, f32(windowSizeY) - 20},
                {f32(windowSizeX), 20},
                rl.ColorFromNormalized(
                    {mapData.skyColor.r, mapData.skyColor.g, mapData.skyColor.b, 1.0}, //mapData.fogStrength,
                ),
            )

            switch Menu_Kind {
            case .NONE:
            case .FILE:
                if fileMenuElemsCount > 0 {
                    gui.ui_update_and_draw_elems(fileMenuElems[:fileMenuElemsCount])

                    if fileMenuButtonBool {
                        fileMenuButtonBool = false
                        ok: bool
                        tiles.loadFromFile(
                            fileMenuElems[gui.menuContext.selected].(gui.Ui_File_Button).fullpath,
                            &mapData,
                        )
                        Menu_Kind = .NONE
                    }
                } else do Menu_Kind = .NONE

            case .PAUSE:
                shouldSave := false
                shouldOpen := false

                elems := []gui.Ui_Elem {
                    gui.Ui_Button{fmt.tprint(args = {"save map"}, sep = ""), &shouldSave},
                    gui.Ui_Button{"open file", &shouldOpen},
                    gui.Ui_Menu_Title{"map attributes"},
                    gui.Ui_Int{"bounds X", &mapData.bounds.x},
                    gui.Ui_Int{"bounds Y", &mapData.bounds.y},
                    gui.Ui_F32{"sky color RED", &mapData.skyColor.r, 0.05},
                    gui.Ui_F32{"sky color GREEN", &mapData.skyColor.g, 0.05},
                    gui.Ui_F32{"sky color BLUE", &mapData.skyColor.b, 0.05},
                    gui.Ui_F32{"fog strength", &mapData.fogStrength, 0.1},
                }
                gui.ui_update_and_draw_elems(elems)

                if shouldSave {
                    tiles.saveToFile(&mapData)
                    Menu_Kind = .NONE
                } else if shouldOpen {
                    fileMenuFetchFiles()
                    Menu_Kind = .FILE
                }

            case .TILE:
                gui.ui_update_and_draw_elems(tileMenuElems[:])
                if tileMenuButtonBool {
                    tileMenuButtonBool = false
                    tileSelected = tiles.Tile(
                        tileMenuElems[gui.menuContext.selected].(gui.Ui_Button).name[0],
                    ) // ughh
                    Menu_Kind = .NONE
                }
            }
        };_draw()
        rl.EndDrawing()

        if Menu_Kind != prevMenuKind do gui.menuContext.selected = 0
        if Menu_Kind != prevMenuKind do gui.menuContext.startOffs = 0

        delta = rl.GetFrameTime()
    }

    rl.CloseWindow()
}



calcMouseTilePos :: proc(mousepos: Vec2) -> IVec2 {
    mousepos := mousepos - cameraPos
    res := mousepos / TILE_WIDTH
    return {i32(math.floor(res.x)), i32(math.floor(res.y))}
}



drawTile :: proc(pos: IVec2, col: rl.Color, text: string) {
    wpos := cameraPos + {f32(pos.x) * TILE_WIDTH, f32(pos.y) * TILE_WIDTH} + {1, 1}
    rl.DrawRectangleV(wpos, {TILE_WIDTH - 2, TILE_WIDTH - 2}, col)

    TEXTSIZE :: 10
    ctext := strings.clone_to_cstring(text, context.temp_allocator)
    rl.DrawText(
        ctext,
        i32(wpos.x) + TILE_WIDTH / 2 - TEXTSIZE / 2,
        i32(wpos.y) + TILE_WIDTH / 2 - TEXTSIZE / 2,
        TEXTSIZE,
        {200, 200, 200, 200},
    )
}

drawTileLines :: proc(pos: IVec2, col: rl.Color) {
    wpos := cameraPos + {f32(pos.x) * TILE_WIDTH, f32(pos.y) * TILE_WIDTH} + {1, 1}
    rl.DrawRectangleLines(i32(wpos.x), i32(wpos.y), TILE_WIDTH - 2, TILE_WIDTH - 2, col)
}

isTilePosValid :: proc(pos: IVec2) -> bool {
    return(
        pos.x >= 0 &&
        pos.y >= 0 &&
        pos.x < tiles.MAP_MAX_SIZE &&
        pos.y < tiles.MAP_MAX_SIZE &&
        pos.x < mapData.bounds.x &&
        pos.y < mapData.bounds.y \
    )
}



// copied from DoQ
fileMenuFetchFiles :: proc() {
    path := fmt.tprint(args = {g_state.load_dir, filepath.SEPARATOR_STRING, "maps"}, sep = "")
    println("path:", path)

    fileMenuElemsCount = 0

    mapSelectFilesFetchDirAndAppend(path)

    // WARNING: recursive! we also load subfolders!
    mapSelectFilesFetchDirAndAppend :: proc(dir: string) {
        dirhandle, oerr := os.open(dir)
        if oerr != os.ERROR_NONE do return
        filebuf, rerr := os.read_dir(dirhandle, FILE_MENU_MAX_ELEMS_COUNT, context.allocator)
        if rerr != os.ERROR_NONE do return
        defer delete(filebuf)

        for i := 0; i < len(filebuf); i += 1 do println(i, filebuf[i].fullpath, filebuf[i].name) // debug

        // get all maps
        for i := 0; i < len(filebuf); i += 1 {
            fileinfo := filebuf[i]
            if fileinfo.is_dir do continue // skip for now
            if fileinfo.name[0] == '_' do continue // hidden
            dotindex := strings.index_byte(fileinfo.name, '.')
            if dotindex == 0 do continue
            if fileinfo.name[dotindex:] != ".dqm" do continue // check suffix
            fileMenuElems[fileMenuElemsCount] = gui.Ui_File_Button {
                fileinfo.name[:dotindex],
                fileinfo.fullpath,
                &fileMenuButtonBool,
            }
            fileMenuElemsCount += 1
        }

        // get subfolders
        for i := 0; i < len(filebuf); i += 1 {
            fileinfo := filebuf[i]
            if !fileinfo.is_dir do continue
            if fileinfo.name[0] == '_' do continue // hidden
            fileMenuElems[fileMenuElemsCount] = gui.Ui_Menu_Title{fileinfo.name}
            fileMenuElemsCount += 1
            mapSelectFilesFetchDirAndAppend(fileinfo.fullpath)
        }
    }
}
