package dqmake



import "core:fmt"
import rl "vendor:raylib"
import "../doq/gui"


windowSizeX : i32
windowSizeY : i32


main :: proc() {
	rl.SetWindowState({
		.WINDOW_TOPMOST,
		.WINDOW_RESIZABLE,
		.VSYNC_HINT,
	})
	rl.InitWindow(1920/2, 1080/2, "dqmake")
	rl.SetTargetFPS(144)

	//gui.menuContext.normalFont = 

	for !rl.WindowShouldClose() {
		windowSizeX = rl.GetScreenWidth()
		windowSizeY = rl.GetScreenHeight()

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		//rl.DrawFPS(0,0)
		//rl.DrawText(fmt.tprint("window X", windowSizeX), 0, 0, 10, rl.RED)
		gui.drawText({0,0}, 10, rl.RED, fmt.tprint("window X", windowSizeX))
		rl.EndDrawing()
	}

	rl.CloseWindow()
}