package dqmake



import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../doq/gui"



vec2 :: rl.Vector2
ivec2 :: [2]i32



windowSizeX : i32
windowSizeY : i32



cameraPos : vec2

TILE_WIDTH :: 22

editor_data : struct {
	brushKind : enum {
		DRAW,
		BOX_FILL,
		BOX_BORDER,
		LINE,
	},
	
	isEditing : bool,
	startEditingMousePos : ivec2,
	
	tiles : [128][128]u8 // TODO
}


calcMouseTilePos :: proc() -> ivec2 {
	mousepos := rl.GetMousePosition() - cameraPos
	res := mousepos / TILE_WIDTH
	return {i32(math.floor(res.x)), i32(math.floor(res.y))}
}

drawTile :: proc(pos : ivec2, col : rl.Color) {
	wpos := cameraPos+{f32(pos.x)*TILE_WIDTH, f32(pos.y)*TILE_WIDTH} + {1,1}
	rl.DrawRectangleV(wpos, {TILE_WIDTH-2, TILE_WIDTH-2}, col)
	
	TEXTSIZE :: 10
	rl.DrawText("#", i32(wpos.x)+TILE_WIDTH/2-TEXTSIZE/2, i32(wpos.y)+TILE_WIDTH/2-TEXTSIZE/2, TEXTSIZE, {200,200,200,200})
}

main :: proc() {
	rl.SetWindowState({
		.WINDOW_TOPMOST,
		.WINDOW_RESIZABLE,
		.VSYNC_HINT,
	})
	rl.InitWindow(1920/2, 1080/2, "dqmake")
	rl.SetTargetFPS(144)
	rl.SetExitKey(rl.KeyboardKey.NULL)

	//gui.menuContext.normalFont = 

	for !rl.WindowShouldClose() {
		windowSizeX = rl.GetScreenWidth()
		windowSizeY = rl.GetScreenHeight()

		_update :: proc() {
			if rl.IsMouseButtonDown(rl.MouseButton.RIGHT) {
				cameraPos.x += rl.GetMouseDelta().x
				cameraPos.y += rl.GetMouseDelta().y
			}
			
			finishedEditing := rl.IsMouseButtonReleased(rl.MouseButton.LEFT)
			if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
				editor_data.isEditing = true
				editor_data.startEditingMousePos = rl.GetMousePosition()
			}
			if !rl.IsMouseButtonDown(rl.MouseButton.LEFT)	do editor_data.isEditing = false
			
			mousetile := calcMouseTilePos()
			
			switch editor_data.brushKind {
				case .DRAW:
					if editor_data.isEditing do editor_data.tiles[mousetile.x][mousetile.y] = 1
				case .BOX_FILL:
					if finishedEditing {
						for x := mousetile.x; x < 100; x += 1 {
							for y := mousetile.y; y < 100; y += 1 {
								W :: 12
								drawTile({x,y}, rl.GRAY)
							}
						}
					}
				case .BOX_BORDER:
				case .LINE:
			}
		} _update()

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		//rl.DrawText(fmt.tprint("window X", windowSizeX), 0, 0, 10, rl.RED)
		_draw :: proc() {
			gui.drawText({100,100}, 10, rl.RED, fmt.tprint("window X", windowSizeX))
			//rl.DrawRectangleV(cameraPos, {100,100}, rl.RED)
			
			for x : i32 = 0; x < 100; x += 1 {
				for y : i32 = 0; y < 100; y += 1 {
					W :: 12
					drawTile({x,y}, rl.GRAY)
				}
			}
			
			mousetile := calcMouseTilePos()
			drawTile(mousetile, rl.RED)
		
		} _draw()
		rl.EndDrawing()
	}

	rl.CloseWindow()
}