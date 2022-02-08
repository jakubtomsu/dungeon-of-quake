package doq


//
// GUI
// menus and on-screen UI
//



import "core:strings"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:fmt"
import rl "vendor:raylib"



gui_data : struct {
	loadScreenLogo	: rl.Texture,
	loadScreenTimer	: f32,

	normalFont	: rl.Font,
	titleFont	: rl.Font,

	pauseMenuIsOpen	: bool,
	selected	: i32, // this can be shared, since we always have only one menu on screen
}

// val is not rendered
// used for buttons
gui_menuBool_t :: struct {
	name	: string,
	val	: ^bool,
}

gui_menuFloat_t :: struct {
	name	: string,
	val	: ^f32,
}

gui_menuElem_t :: union {
	gui_menuBool_t,
	gui_menuFloat_t,
}



gui_drawText :: proc(pos : vec2, size : f32, color : rl.Color, text : string) {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	rl.DrawTextEx(gui_data.normalFont, cstr, pos, size, 0.0, color)
}

gui_drawTitleText :: proc(pos : vec2, size : f32, color : rl.Color, text : string) {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	rl.DrawTextEx(gui_data.titleFont, cstr, pos, size, 0.0, color)
}

gui_updateAndDrawElemBuf :: proc(elems : []gui_menuElem_t) {
	if rl.IsKeyPressed(rl.KeyboardKey.DOWN)	do gui_data.selected += 1
	if rl.IsKeyPressed(rl.KeyboardKey.UP)	do gui_data.selected -= 1
	gui_data.selected %%= i32(len(elems))

	selElem := elems[gui_data.selected]
	switch in selElem {
		case gui_menuBool_t:
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) {
				selElem.(gui_menuBool_t).val^ = !selElem.(gui_menuBool_t).val^
			}
		case gui_menuFloat_t:
			if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
				selElem.(gui_menuFloat_t).val^ += 0.1
			} else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
				selElem.(gui_menuFloat_t).val^ -= 0.1
			}
	}

	SIZE :: 60
	for i := 0; i < len(elems); i += 1 {
		col := i32(i)==gui_data.selected ? rl.WHITE:rl.GRAY
		switch in elems[i] {
			case gui_menuBool_t:
				gui_drawText({100, f32(i)*SIZE}, SIZE, col, elems[i].(gui_menuBool_t).name)
			case gui_menuFloat_t:
				gui_drawText({100, f32(i)*SIZE}, SIZE, col, elems[i].(gui_menuFloat_t).name)
				gui_drawText({400, f32(i)*SIZE}, SIZE, col, fmt.tprint(elems[i].(gui_menuFloat_t).val^))
		}
	}
}



menu_updateAndDrawPauseMenu :: proc() {
	//testb := false
	//testf : f32 = 0.0
	//elems : []gui_menuElem_t = {
	//	gui_menuBool_t{"resume", &testb},
	//	gui_menuFloat_t{"audio volume", &testf},
	//}

	//gui_updateAndDrawElemBuf(elems[:])
}



menu_updateAndDrawLoadScreenUpdatePath :: proc() {
	rl.BeginDrawing()
		unfade := math.sqrt(glsl.smoothstep(0.0, 1.0, gui_data.loadScreenTimer * 0.4))
		rl.ClearBackground(rl.ColorFromNormalized(linalg.lerp(vec4{0,0,0,0}, vec4{1,1,1,1}*0.1, unfade)))
		gui_drawText({10, 10}, 20, rl.YELLOW, "load screen")
		OFFS :: 200
		STARTSCALE :: 12.0
		scale := glsl.min(
			WINDOW_X / f32(gui_data.loadScreenLogo.width),
			WINDOW_Y / f32(gui_data.loadScreenLogo.height),
		) * (STARTSCALE + math.sqrt(unfade)) / (1.0 + STARTSCALE)
		rl.DrawTextureEx(
			gui_data.loadScreenLogo,
			{WINDOW_X/2 - f32(gui_data.loadScreenLogo.width)*scale/4, WINDOW_Y/2 - f32(gui_data.loadScreenLogo.height)*scale/4},
			0.0, // rot
			scale * 0.5, // scale
			rl.ColorFromNormalized(linalg.lerp(vec4{0,0,0,0}, vec4{1,1,1,1}, unfade)),
		)

		gui_drawText(
			{WINDOW_X/2-100,WINDOW_Y-130},
			25,
			rl.ColorFromNormalized(linalg.lerp(vec4{0,0,0,0}, vec4{1,1,1,1}, clamp(unfade-0.4 + math.sin(timepassed*4.0)*0.1, 0.0, 1.0))),
			"press any key to continue",
		)
	rl.EndDrawing()

	gui_data.loadScreenTimer += deltatime

	if i32(rl.GetKeyPressed()) != 0 ||
		rl.IsMouseButtonPressed(rl.MouseButton.LEFT) ||
		rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) ||
		rl.IsMouseButtonPressed(rl.MouseButton.MIDDLE) {
		app_updatePathKind = .MAIN_MENU
	}
}



menu_updateAndDrawMainMenuUpdatePath :: proc() {
	shouldResume := false
	rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		gui_drawText({10, 10}, 20, rl.PINK, "main menu")
		
		testf : f32 = 0.0
		elems : []gui_menuElem_t = {
			gui_menuBool_t{"resume", &shouldResume},
			gui_menuFloat_t{"audio volume", &testf},
			gui_menuFloat_t{"test", &testf},
			gui_menuFloat_t{"test2", &testf},
		}

		gui_updateAndDrawElemBuf(elems[:])
	rl.EndDrawing()
	
	//if i32(rl.GetKeyPressed()) != 0 {
	//}

	if shouldResume do app_updatePathKind = .GAME
}

