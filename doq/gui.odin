package doq


//
// GUI
// menus and on-screen UI
//



import "core:strings"
import rl "vendor:raylib"



ui_drawText :: proc(pos : vec2, size : f32, color : rl.Color, text : string) {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	rl.DrawTextEx(normalFont, cstr, pos, size, 0.0, color)
}

