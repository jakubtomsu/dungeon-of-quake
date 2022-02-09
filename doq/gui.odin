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
// import "core:os"
import rl "vendor:raylib"



//
// MENU
//

MENU_MAX_MAP_SELECT_FILES :: 256

gui_data : struct {
	loadScreenLogo	: rl.Texture,
	loadScreenTimer	: f32,

	pauseMenuIsOpen	: bool,
	selected	: i32, // this can be shared, since we always have only one menu on screen
	
	normalFont	: rl.Font,
	titleFont	: rl.Font,

	selectSound		: rl.Sound,
	setValSound		: rl.Sound,
	loadScreenMusic	: rl.Music,
	
	mapSelectFileElemsCount : i32,
	mapSelectFileElems	: [MENU_MAX_MAP_SELECT_FILES]gui_menuElem_t,
}


menu_updateAndDrawPauseMenu :: proc() {
	elems : []gui_menuElem_t = {
		gui_menuButton_t{"resume", &gameIsPaused},
		//gui_menuFloat_t{"audio volume", &testf},
	}

	gui_updateAndDrawElemBuf(elems[:])
}

menu_drawPlayerUI :: proc() {
	// crosshair
	if settings.drawCursor {
		W :: 8
		H :: 4
		
		// horizontal
		rl.DrawRectangle(WINDOW_X/2-10-W/2, WINDOW_Y/2-1, W, 2, rl.Fade(rl.WHITE, 0.5))
		rl.DrawRectangle(WINDOW_X/2+10-W/2, WINDOW_Y/2-1, W, 2, rl.Fade(rl.WHITE, 0.5))
		
		// vertical
		rl.DrawRectangle(WINDOW_X/2-1, WINDOW_Y/2-7-H/2, 2, H, rl.Fade(rl.WHITE, 0.5))
		rl.DrawRectangle(WINDOW_X/2-1, WINDOW_Y/2+7-H/2, 2, H, rl.Fade(rl.WHITE, 0.5))
		
		// center dot
		//rl.DrawRectangle(WINDOW_X/2-1, WINDOW_Y/2-1, 2, 2, rl.WHITE)
	}

	gunindex := cast(i32)gun_data.equipped

	// draw ammo
	gui_drawText({WINDOW_X - 150, WINDOW_Y - 50},	30, rl.Color{255,200, 50,255}, fmt.tprint("ammo: ", gun_data.ammoCounts[gunindex]))
	gui_drawText({30, WINDOW_Y - 50},		30, rl.Color{255, 80, 80,255}, fmt.tprint("health: ", player_data.health))

	// draw guns
	for i : i32 = 0; i < GUN_COUNT; i += 1 {
		LINE :: 40
		TEXTHEIGHT :: LINE*0.5
		pos := vec2{WINDOW_X - 120, WINDOW_Y*0.5 + GUN_COUNT*LINE*0.5 - cast(f32)i*LINE}
		if i == cast(i32)gun_data.equipped {
			W :: 8
			rl.DrawRectangle(cast(i32)pos.x-W, cast(i32)pos.y-W, 120, TEXTHEIGHT+W*2, {150,150,150,100})
		}

		gui_drawText(pos, TEXTHEIGHT, gun_data.ammoCounts[i] == 0 ? {255,255,255,100} : rl.WHITE, fmt.tprint(cast(gun_kind_t)i))
	}

}

_debugtext_y : i32 = 2
menu_drawDebugUI :: proc() {
	if settings.drawFPS || settings.debugIsEnabled do rl.DrawFPS(0, 0)

	_debugtext_y = 2

	if settings.debugIsEnabled {
		debugtext :: proc(args : ..any) {
			tstr := fmt.tprint(args=args)
			cstr := strings.clone_to_cstring(tstr, context.temp_allocator)
			rl.DrawText(cstr, 6, _debugtext_y * 12, 10, rl.Fade(rl.WHITE, 0.8))
			_debugtext_y += 1
		}

		debugtext("player")
		debugtext("    pos", player_data.pos)
		debugtext("    vel", player_data.vel)
		debugtext("    speed", i32(linalg.length(player_data.vel)))
		debugtext("    onground", player_data.isOnGround)
		debugtext("system")
		debugtext("    IsAudioDeviceReady", rl.IsAudioDeviceReady())
		debugtext("    loadpath", loadpath)
		debugtext("    gameIsPaused", gameIsPaused)
		debugtext("map")
		debugtext("    bounds", map_data.bounds)
		debugtext("    mapName", map_data.mapName)
		debugtext("    nextMapName", map_data.nextMapName)
		debugtext("    startPlayerDir", map_data.startPlayerDir)
		debugtext("    gunPickupCount", map_data.gunPickupCount,
			"gunPickupSpawnCount", map_data.gunPickupCount)
		debugtext("    healthPickupCount", map_data.healthPickupCount,
			"healthPickupSpawnCount", map_data.healthPickupSpawnCount)
		debugtext("    skyColor", map_data.skyColor)
		debugtext("    fogStrengh", map_data.fogStrength)
		debugtext("gun")
		debugtext("    equipped", gun_data.equipped)
		debugtext("    timer", gun_data.timer)
		debugtext("    ammo counts", gun_data.ammoCounts)
		debugtext("bullets")
		debugtext("    linear effect count", bullet_data.bulletLinesCount)
		debugtext("enemies")
		debugtext("    grunt count", enemy_data.gruntCount)
		debugtext("    knight count", enemy_data.knightCount)
	}
}



menu_updateAndDrawMainMenuUpdatePath :: proc() {
	shouldResume := false
	shouldMapSelect := false
	rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		gui_drawText({10, 10}, 20, rl.PINK, "main menu")
		menu_drawDebugUI()
		
		elems : []gui_menuElem_t = {
			gui_menuButton_t{"start game", &shouldResume},
			gui_menuButton_t{"map select", &shouldMapSelect},
			gui_menuTitle_t{"settings"},
			gui_menuFloat_t{"audio volume", &settings.audioMasterVolume},
			gui_menuBool_t{"draw FPS", &settings.drawFPS},
			gui_menuBool_t{"enable debug mode", &settings.debugIsEnabled},
			gui_menuFloat_t{"test f", &settings.audioMasterVolume},
			gui_menuTitle_t{"test title"},
			gui_menuFloat_t{"test f", &settings.audioMasterVolume},
		}

		gui_updateAndDrawElemBuf(elems[:])
	rl.EndDrawing()


	if shouldResume do app_updatePathKind = .GAME
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



menu_mainMenuFetchMapSelectFiles :: proc() {
	//filebuf, err := os.read_dir
}






//
// GUI
//


// val is not rendered
gui_menuButton_t :: struct {
	name	: string,
	val	: ^bool,
}

gui_menuBool_t :: struct {
	name	: string,
	val		: ^bool,
}

gui_menuFloat_t :: struct {
	name	: string,
	val	: ^f32,
}

gui_menuTitle_t :: struct {
	name	: string,
}

gui_menuElem_t :: union {
	gui_menuButton_t,
	gui_menuBool_t,
	gui_menuFloat_t,
	gui_menuTitle_t,
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
	selectDir := 0
	if rl.IsKeyPressed(rl.KeyboardKey.DOWN)	do selectDir += 1
	if rl.IsKeyPressed(rl.KeyboardKey.UP)	do selectDir -= 1
	
	if selectDir != 0 {
		loopfind: for i := 0; i < len(elems); i += 1 {
			index := (int(gui_data.selected) + i*selectDir + selectDir) %% len(elems)
			#partial switch in elems[index] {
				case gui_menuTitle_t: continue loopfind
			}
			gui_data.selected = i32(index)
			break loopfind
		}
	}

	SIZE :: 30
	offs : f32 = 6
	for i := 0; i < len(elems); i += 1 {
		isSelected := i32(i)==gui_data.selected
		col : rl.Color  = isSelected ? {220,220,220,200}:{200,200,200,160}
		vcol : rl.Color = isSelected ? {255,255,255,255}:{200,200,200,160}
		NOFFS :: WINDOW_X/2 - 200
		VOFFS :: WINDOW_X/2 + 100
		switch in elems[i] {
			case gui_menuButton_t:
				gui_drawText({NOFFS, offs*SIZE}, SIZE, col, elems[i].(gui_menuButton_t).name)
			case gui_menuBool_t:
				gui_drawText({NOFFS, offs*SIZE}, SIZE, col, elems[i].(gui_menuBool_t).name)
				gui_drawText({VOFFS, offs*SIZE}, SIZE, vcol, elems[i].(gui_menuBool_t).val^ ? "yes" : "no")
			case gui_menuFloat_t:
				gui_drawText({NOFFS, offs*SIZE}, SIZE, col, elems[i].(gui_menuFloat_t).name)
				gui_drawText({VOFFS, offs*SIZE}, SIZE, vcol, fmt.tprint(elems[i].(gui_menuFloat_t).val^))
			case gui_menuTitle_t:
				offs += 0.6
				gui_drawText({NOFFS, offs*SIZE}, SIZE * 0.8, {200,200,200,100}, elems[i].(gui_menuTitle_t).name)
				offs -= 0.1
		}
		
		if isSelected {
			gui_drawText({NOFFS - 30, offs*SIZE}, SIZE, vcol, ">")
		}

		offs += 1
	}

	selElem := elems[gui_data.selected]
	switch in selElem {
		case gui_menuButton_t:
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) ||
				rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				selElem.(gui_menuButton_t).val^ = !selElem.(gui_menuButton_t).val^
			}
		case gui_menuBool_t:
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) ||
				rl.IsKeyPressed(rl.KeyboardKey.SPACE) ||
				rl.IsKeyPressed(rl.KeyboardKey.RIGHT) || 
				rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
				selElem.(gui_menuBool_t).val^ = !selElem.(gui_menuBool_t).val^
			}
		case gui_menuFloat_t:
			if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
				selElem.(gui_menuFloat_t).val^ += 0.1
			} else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
				selElem.(gui_menuFloat_t).val^ -= 0.1
			}
		case gui_menuTitle_t:
	}
}

