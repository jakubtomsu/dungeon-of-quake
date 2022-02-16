package dqmake



import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"
import "doq/gui"
import "doq/tiles"



vec2 :: rl.Vector2
ivec2 :: [2]i32



windowSizeX : i32
windowSizeY : i32

deltatime : f32

ADD_MOUSE_BUTTON :: rl.MouseButton.LEFT
SUB_MOUSE_BUTTON :: rl.MouseButton.RIGHT

cameraPos : vec2

TILE_WIDTH :: 22

brushKind : enum {
	DRAW,
	BOX_FILL,
	BOX_EDGE,
}

isEditing : bool
isErasing : bool
startEditingMousePos : vec2
TILEMAP_SIZE :: 123
pauseMenuIsOpen : bool
tilemap : [TILEMAP_SIZE][TILEMAP_SIZE]tiles.kind_t // TODO
tilemapBounds : [2]i32 = {32, 32}

loadpath : string



main :: proc() {
	loadpath = filepath.clean(string(rl.GetWorkingDirectory()))

	rl.SetWindowState({
		.WINDOW_TOPMOST,
		.WINDOW_RESIZABLE,
		.VSYNC_HINT,
	})
	rl.InitWindow(1920/2, 1080/2, "dqmake")
	rl.SetTargetFPS(144)
	rl.SetExitKey(rl.KeyboardKey.NULL)

	gui.menuContext.normalFont = loadFont("germania_one.ttf")

	for !rl.WindowShouldClose() {
		windowSizeX = rl.GetScreenWidth()
		windowSizeY = rl.GetScreenHeight()

		tilemapBounds.x = clamp(tilemapBounds.x, 0, TILEMAP_SIZE-1)
		tilemapBounds.y = clamp(tilemapBounds.y, 0, TILEMAP_SIZE-1)

		_update :: proc() {

			if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
				pauseMenuIsOpen = !pauseMenuIsOpen
				return
			}

			if pauseMenuIsOpen do return
			gui.menuContext.startOffs = 0

			if rl.IsMouseButtonDown(rl.MouseButton.MIDDLE) {
				cameraPos.x += rl.GetMouseDelta().x
				cameraPos.y += rl.GetMouseDelta().y
				return
			}

			brushKind = .DRAW
			if rl.IsKeyDown(rl.KeyboardKey.E)	do brushKind = .BOX_EDGE
			if rl.IsKeyDown(rl.KeyboardKey.B)	do brushKind = .BOX_FILL
			
			prevIsEditing := isEditing
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
			if finishedEditing do fmt.println("FINISHED EDITING")
			
			mousetile := calcMouseTilePos(rl.GetMousePosition())

			if (isEditing || finishedEditing){
				tile := isErasing ? tiles.kind_t.NONE : tiles.kind_t.FULL
				switch brushKind {
					case .DRAW:
						if isTilePosValid(mousetile) do tilemap[mousetile.x][mousetile.y] = tile
					case .BOX_FILL:
						if finishedEditing {
							starttile := calcMouseTilePos(startEditingMousePos)
							lowerleft  := ivec2{glsl.min(starttile.x, mousetile.x), glsl.min(starttile.y, mousetile.y)}
							upperright := ivec2{glsl.max(starttile.x, mousetile.x), glsl.max(starttile.y, mousetile.y)}
							for x := lowerleft.x; x <= upperright.x; x += 1 {
								for y := lowerleft.y; y <= upperright.y; y += 1 {
									if isTilePosValid({x, y}) do tilemap[x][y] = tile
								}
							}
						}
					case .BOX_EDGE:
						if finishedEditing {
							starttile := calcMouseTilePos(startEditingMousePos)
							lowerleft  := ivec2{glsl.min(starttile.x, mousetile.x), glsl.min(starttile.y, mousetile.y)}
							upperright := ivec2{glsl.max(starttile.x, mousetile.x), glsl.max(starttile.y, mousetile.y)}
							for x := lowerleft.x; x <= upperright.x; x += 1 {
								if isTilePosValid({x, lowerleft.y}) do tilemap[x][lowerleft.y] = tile
							}
							for x := lowerleft.x; x <= upperright.x; x += 1 {
								if isTilePosValid({x, upperright.y}) do tilemap[x][upperright.y] = tile
							}
							for y := lowerleft.y; y <= upperright.y; y += 1 {
								if isTilePosValid({lowerleft.x, y}) do tilemap[lowerleft.x][y] = tile
							}
							for y := lowerleft.y; y <= upperright.y; y += 1 {
								if isTilePosValid({upperright.x, y}) do tilemap[upperright.x][y] = tile
							}
						}
					}
			}
		} _update()



		rl.BeginDrawing()
		rl.ClearBackground(rl.ColorFromNormalized(gui.BACKGROUND))
		//rl.DrawText(fmt.tprint("window X", windowSizeX), 0, 0, 10, rl.RED)
		_draw :: proc() {
			//gui.drawText({100,100}, 25, rl.RED, fmt.tprint("window X", windowSizeX))
			//rl.DrawRectangleV(cameraPos, {100,100}, rl.RED)
			

			// update GUI context
			gui.menuContext.windowSizeX = windowSizeX
			gui.menuContext.windowSizeY = windowSizeY
			gui.menuContext.deltatime = deltatime

			for x : i32 = 0; x < tilemapBounds.x; x += 1 {
				for y : i32 = 0; y < tilemapBounds.y; y += 1 {
					W :: 12
					drawTile({x,y}, {100,100,100,200}, fmt.tprint(rune(tilemap[x][y])))
				}
			}

			for i : i32 = 0; i < tilemapBounds.x; i += 10 do drawTile({i, -1             }, {100,100,100,40}, fmt.tprint(i))
			for i : i32 = 0; i < tilemapBounds.x; i += 10 do drawTile({i, tilemapBounds.y}, {100,100,100,40}, fmt.tprint(i))
			for i : i32 = 0; i < tilemapBounds.y; i += 10 do drawTile({-1             , i}, {100,100,100,40}, fmt.tprint(i))
			for i : i32 = 0; i < tilemapBounds.y; i += 10 do drawTile({tilemapBounds.x, i}, {100,100,100,40}, fmt.tprint(i))
			
			mousetile := calcMouseTilePos(rl.GetMousePosition())
			cursorcol := rl.GRAY
			if isEditing do cursorcol = isErasing ? {200,100,100,255} : {100,200,200,255}
			if !isTilePosValid(mousetile) do cursorcol.a /= 2

			switch brushKind {
				case .DRAW:
					drawTile(mousetile, cursorcol, "")
				case .BOX_FILL:
					drawTile(mousetile, cursorcol, "")
					if isEditing {
						starttile := calcMouseTilePos(startEditingMousePos)
						lowerleft  := ivec2{glsl.min(starttile.x, mousetile.x), glsl.min(starttile.y, mousetile.y)}
						upperright := ivec2{glsl.max(starttile.x, mousetile.x), glsl.max(starttile.y, mousetile.y)}
						dragcol := cursorcol
						dragcol.a /= 2
						for x := lowerleft.x; x <= upperright.x; x += 1 {
							for y := lowerleft.y; y <= upperright.y; y += 1 {
								drawTile({x, y}, dragcol, "")
							}
						}
					}
				case .BOX_EDGE:
					drawTile(mousetile, cursorcol, "")
					if isEditing {
						starttile := calcMouseTilePos(startEditingMousePos)
						lowerleft  := ivec2{glsl.min(starttile.x, mousetile.x), glsl.min(starttile.y, mousetile.y)}
						upperright := ivec2{glsl.max(starttile.x, mousetile.x), glsl.max(starttile.y, mousetile.y)}
						dragcol := cursorcol
						dragcol.a /= 2
						for x := lowerleft.x; x <= upperright.x; x += 1 do drawTile({x, lowerleft.y }, dragcol, "")
						for x := lowerleft.x; x <= upperright.x; x += 1 do drawTile({x, upperright.y}, dragcol, "")
						for y := lowerleft.y; y <= upperright.y; y += 1 do drawTile({lowerleft.x , y}, dragcol, "")
						for y := lowerleft.y; y <= upperright.y; y += 1 do drawTile({upperright.x, y}, dragcol, "")
					}
			}

			gui.drawText({10, 10}, 25, gui.ACTIVE_COLOR, fmt.tprint("brush:", brushKind))
			gui.drawText({10, 40}, 25, gui.ACTIVE_COLOR, fmt.tprint("isEditing:", isEditing))

			if pauseMenuIsOpen {
				rl.DrawRectangle(0, 0, windowSizeX, windowSizeY, {10,10,10,200})

				elems := []gui.menuElem_t {
					gui.menuI32_t{"bounds X", &tilemapBounds.x},
					gui.menuI32_t{"bounds Y", &tilemapBounds.y},
				}

				gui.updateAndDrawElemBuf(elems)
			}
		} _draw()
		rl.EndDrawing()

		deltatime = rl.GetFrameTime()
	}

	rl.CloseWindow()
}


calcMouseTilePos :: proc(mousepos : vec2) -> ivec2 {
	mousepos := mousepos - cameraPos
	res := mousepos / TILE_WIDTH
	return {i32(math.floor(res.x)), i32(math.floor(res.y))}
}

drawTile :: proc(pos : ivec2, col : rl.Color, text : string) {
	wpos := cameraPos+{f32(pos.x)*TILE_WIDTH, f32(pos.y)*TILE_WIDTH} + {1,1}
	rl.DrawRectangleV(wpos, {TILE_WIDTH-2, TILE_WIDTH-2}, col)
	
	TEXTSIZE :: 10
	ctext := strings.clone_to_cstring(text, context.temp_allocator)
	rl.DrawText(ctext, i32(wpos.x)+TILE_WIDTH/2-TEXTSIZE/2, i32(wpos.y)+TILE_WIDTH/2-TEXTSIZE/2, TEXTSIZE, {200,200,200,200})
}

isTilePosValid :: proc(pos : ivec2) -> bool {
	return pos.x>=0 && pos.y>=0 && pos.x<TILEMAP_SIZE && pos.y < TILEMAP_SIZE && pos.x<tilemapBounds.x && pos.y<tilemapBounds.y
}





// util functions, copied from DoQ


appendToAssetPath :: proc(subdir : string, path : string) -> string {
	return fmt.tprint(
		args={loadpath, filepath.SEPARATOR_STRING, subdir, filepath.SEPARATOR_STRING, path},
		sep="",
	)
}

// ctx temp alloc
appendToAssetPathCstr :: proc(subdir : string, path : string) -> cstring {
	return strings.clone_to_cstring(appendToAssetPath(subdir, path), context.temp_allocator)
}

loadFont :: proc(path : string) -> rl.Font {
	fullpath := appendToAssetPathCstr("fonts", path)
	return rl.LoadFontEx(fullpath, 32, nil, 0)
	//return rl.LoadFont(fullpath)
}

