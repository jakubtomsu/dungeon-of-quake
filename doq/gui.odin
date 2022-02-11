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
import "core:os"
import "core:path/filepath"
import rl "vendor:raylib"



//
// MENU
//

MENU_MAX_MAP_SELECT_FILES :: 256

MENU_BACKGROUND :: vec4{0.08,0.08,0.1,1.0}

menu_data : struct {
	loadScreenLogo	: rl.Texture,
	loadScreenTimer	: f32,

	pauseMenuIsOpen	: bool,
	selected	: i32, // this can be shared, since we always have only one menu on screen
	startOffs	: f32,

	normalFont	: rl.Font,

	selectSound		: rl.Sound,
	setValSound		: rl.Sound,
	loadScreenMusic		: rl.Music,
	
	mapSelectFileElemsCount : i32,
	mapSelectFileElems	: [MENU_MAX_MAP_SELECT_FILES]gui_menuElem_t,
	mapSelectButtonBool	: bool, // shared
	mapSelectIsOpen		: bool,
}



menu_resetState :: proc() {
	menu_data.selected = 0
	//menu_data.startOffs = -10
	menu_data.mapSelectIsOpen = false
	menu_data.mapSelectButtonBool = false
	menu_data.pauseMenuIsOpen = false
	menu_data.loadScreenTimer = 0.0
}



menu_drawPlayerUI :: proc() {
	// crosshair
	{
		W :: 8
		H :: 4
		
		// horizontal
		rl.DrawRectangle(windowSizeX/2-10-W/2, windowSizeY/2-1, W, 2, rl.Fade(rl.WHITE, settings.crosshairOpacity))
		rl.DrawRectangle(windowSizeX/2+10-W/2, windowSizeY/2-1, W, 2, rl.Fade(rl.WHITE, settings.crosshairOpacity))
		
		// vertical
		rl.DrawRectangle(windowSizeX/2-1, windowSizeY/2-7-H/2, 2, H, rl.Fade(rl.WHITE, settings.crosshairOpacity))
		rl.DrawRectangle(windowSizeX/2-1, windowSizeY/2+7-H/2, 2, H, rl.Fade(rl.WHITE, settings.crosshairOpacity))
		
		// center dot
		//rl.DrawRectangle(windowSizeX/2-1, windowSizeY/2-1, 2, 2, rl.WHITE)
	}

	gunindex := cast(i32)gun_data.equipped

	// draw ammo
	gui_drawText({f32(windowSizeX) - 150, f32(windowSizeY) - 50},	30, rl.Color{255,200, 50,255}, fmt.tprint("ammo: ", gun_data.ammoCounts[gunindex]))
	gui_drawText({30, f32(windowSizeY) - 50},		30, rl.Color{255, 80, 80,255}, fmt.tprint("health: ", player_data.health))

	// draw guns
	for i : i32 = 0; i < GUN_COUNT; i += 1 {
		LINE :: 40
		TEXTHEIGHT :: LINE*0.5
		pos := vec2{f32(windowSizeX)-120, f32(windowSizeY)*0.5 + GUN_COUNT*LINE*0.5 - cast(f32)i*LINE}
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
		debugtext("    pos",		player_data.pos)
		debugtext("    vel",		player_data.vel)
		debugtext("    speed",		i32(linalg.length(player_data.vel)))
		debugtext("    onground",	player_data.isOnGround)
		debugtext("    onground timer",	player_data.onGroundTimer)
		debugtext("system")
		debugtext("    windowSize",	[]i32{windowSizeX, windowSizeY})
		debugtext("    app_updatePathKind",	app_updatePathKind)
		debugtext("    IsAudioDeviceReady",	rl.IsAudioDeviceReady())
		debugtext("    loadpath",		loadpath)
		debugtext("    gameIsPaused",		gameIsPaused)
		debugtext("map")
		debugtext("    bounds",			map_data.bounds)
		debugtext("    nextMapName",		map_data.nextMapName)
		debugtext("    startPlayerDir",		map_data.startPlayerDir)
		debugtext("    gunPickupCount",		map_data.gunPickupCount,
			"gunPickupSpawnCount",		map_data.gunPickupCount)
		debugtext("    healthPickupCount",	map_data.healthPickupCount,
			"healthPickupSpawnCount",	map_data.healthPickupSpawnCount)
		debugtext("    skyColor",		map_data.skyColor)
		debugtext("    fogStrengh",		map_data.fogStrength)
		debugtext("gun")
		debugtext("    equipped",	gun_data.equipped)
		debugtext("    timer",		gun_data.timer)
		debugtext("    ammo counts",	gun_data.ammoCounts)
		debugtext("bullets")
		debugtext("    bulletline count", bullet_data.bulletLinesCount)
		debugtext("enemies")
		debugtext("    grunt count",	enemy_data.gruntCount)
		debugtext("    knight count",	enemy_data.knightCount)
		debugtext("menus")
		debugtext("    pauseMenuIsOpen",		menu_data.pauseMenuIsOpen)
		debugtext("    selected",			menu_data.selected)
		debugtext("    startOffset",			menu_data.startOffs)
		debugtext("    mapSelectFileElemsCount",	menu_data.mapSelectFileElemsCount)
	}
}



menu_updateAndDrawPauseMenu :: proc() {
	if map_data.isMapFinished {
		screenTint = {}
		shouldContinue := false
		shouldExitToMainMenu := false
		shouldReset := false
		elems : []gui_menuElem_t = {
			gui_menuButton_t{"continue",		&shouldContinue},
			gui_menuButton_t{"play again",		&shouldReset},
			gui_menuButton_t{"exit to main menu",	&shouldExitToMainMenu},
		}
	
		gui_updateAndDrawElemBuf(elems[:])


		if shouldContinue {
			if map_data.nextMapName == "" {
				shouldExitToMainMenu = true
			} else {
				if map_loadFromFile(map_data.nextMapName) {
					app_setUpdatePathKind(.GAME)
					menu_resetState()
				} else {
					shouldExitToMainMenu = true
				}
			}
		}
		if shouldExitToMainMenu {
			app_setUpdatePathKind(.MAIN_MENU)
		}
		if shouldReset {
			player_die()
			menu_resetState()
			gameIsPaused = false
		}
	} else {
		shouldExitToMainMenu := false
		shouldReset := false
		elems : []gui_menuElem_t = {
			gui_menuButton_t{"resume",		&gameIsPaused},
			gui_menuButton_t{"reset",		&shouldReset},
			gui_menuButton_t{"go to main menu",	&shouldExitToMainMenu},
			gui_menuButton_t{"exit to desktop",	&app_shouldExitNextFrame},

			gui_menuTitle_t{"settings"},
			gui_menuFloat_t{"audio volume",			&settings.audioMasterVolume,	0.05},
			gui_menuFloat_t{"music volume",			&settings.audioMusicVolume,	0.05},
			gui_menuFloat_t{"mouse sensitivity",		&settings.mouseSensitivity,	0.05},
			gui_menuFloat_t{"crosshair visibility",		&settings.crosshairOpacity,	0.1},
			gui_menuFloat_t{"gun X offset",			&settings.gunXOffset,		0.025},
			gui_menuFloat_t{"fild of view",			&settings.FOV,			10.0},
			gui_menuFloat_t{"viewmodel field of view",	&settings.viewmodelFOV,		10.0},
			gui_menuBool_t{"show FPS",			&settings.drawFPS},
			gui_menuBool_t{"enable debug mode",		&settings.debugIsEnabled},
		}

		menu_drawNavTips()
		if gui_updateAndDrawElemBuf(elems[:]) {
			settings_saveToFile()
		}

		rl.SetSoundVolume(player_data.swooshSound, 0.0)

		screenTint = linalg.lerp(screenTint, vec3{0.1,0.1,0.1}, clamp(deltatime*5.0, 0.0, 1.0))

		if shouldExitToMainMenu {
			app_setUpdatePathKind(.MAIN_MENU)
		}
		if shouldReset {
			player_die()
			menu_resetState()
			gameIsPaused = false
		}
	}
}



menu_updateAndDrawMainMenuUpdatePath :: proc() {
	rl.SetMusicVolume(menu_data.loadScreenMusic, 1.0)
	playingMusic = &menu_data.loadScreenMusic

	rl.BeginDrawing()
	rl.ClearBackground(rl.ColorFromNormalized(MENU_BACKGROUND))
	menu_drawNavTips()
	menu_drawDebugUI()

	if menu_data.mapSelectIsOpen {
		gui_updateAndDrawElemBuf(menu_data.mapSelectFileElems[:menu_data.mapSelectFileElemsCount])
		if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
			rl.PlaySound(menu_data.setValSound)
			menu_resetState()
		}

		if menu_data.mapSelectButtonBool {
			menu_data.mapSelectButtonBool = false
			elem, ok := menu_data.mapSelectFileElems[menu_data.selected].(gui_menuFileButton_t)
			if ok {
				if map_loadFromFileAbs(elem.fullpath) {
					app_setUpdatePathKind(.GAME)
					menu_resetState()
				}
			} else {
				println("! error: selected element is invalid")
			}
		}

	} else {
		shouldMapSelect := false
		elems : []gui_menuElem_t = {
			gui_menuButton_t{"singleplayer",	&shouldMapSelect},
			gui_menuButton_t{"exit to desktop",	&app_shouldExitNextFrame},

			gui_menuTitle_t{"settings"},
			gui_menuFloat_t{"audio volume",			&settings.audioMasterVolume,	0.05},
			gui_menuFloat_t{"music volume",			&settings.audioMusicVolume,	0.05},
			gui_menuFloat_t{"mouse sensitivity",		&settings.mouseSensitivity,	0.05},
			gui_menuFloat_t{"crosshair visibility",		&settings.crosshairOpacity,	0.1},
			gui_menuFloat_t{"gun size offset",		&settings.gunXOffset,		0.025},
			gui_menuFloat_t{"fild of view",			&settings.FOV,			10.0},
			gui_menuFloat_t{"viewmodel field of view",	&settings.viewmodelFOV,		10.0},
			gui_menuBool_t{"show FPS",			&settings.drawFPS},
			gui_menuBool_t{"enable debug mode",		&settings.debugIsEnabled},
		}

		if gui_updateAndDrawElemBuf(elems[:]) {
			settings_saveToFile()
		}

		if shouldMapSelect {
			menu_mainMenuFetchMapSelectFiles()
			menu_resetState()
			menu_data.mapSelectIsOpen = true
		}
	}

	rl.EndDrawing()
}

menu_mainMenuFetchMapSelectFiles :: proc() {
	println(#procedure)
	path := fmt.tprint(args={loadpath, filepath.SEPARATOR_STRING, "maps"}, sep="")
	println("path:", path)

	menu_data.mapSelectFileElemsCount = 0

	mapSelectFilesFetchDirAndAppend(path)



	// WARNING: recursive! we also load subfolders!
	mapSelectFilesFetchDirAndAppend :: proc(dir : string) {
		println(#procedure)
		println("dir:", dir)
		dirhandle, oerr := os.open(dir)
		if oerr != os.ERROR_NONE do return
		filebuf, rerr := os.read_dir(dirhandle, MENU_MAX_MAP_SELECT_FILES, context.allocator)
		if rerr != os.ERROR_NONE do return
		defer delete(filebuf)
		
		for i := 0; i < len(filebuf); i += 1 do println(i, filebuf[i].fullpath, filebuf[i].name) // debug

		// get all maps
		for i := 0; i < len(filebuf); i += 1 {
			fileinfo := filebuf[i]
			if fileinfo.is_dir		do continue // skip for now
			if fileinfo.name[0] == '_'	do continue // hidden
			dotindex := strings.index_byte(fileinfo.name, '.')
			if dotindex == 0 do continue
			if fileinfo.name[dotindex:] != ".dqm" do continue // check suffix
			//menu_data.mapSelectFileElems[menu_data.mapSelectFileElemsCount] = gui_menuButton_t{fileinfo.name[:dotindex], &menu_data.mapSelectButtonBool}
			menu_data.mapSelectFileElems[menu_data.mapSelectFileElemsCount] = gui_menuFileButton_t{
				fileinfo.name[:dotindex], fileinfo.fullpath, &menu_data.mapSelectButtonBool,
			}
			menu_data.mapSelectFileElemsCount += 1
		}

		// get subfolders
		for i := 0; i < len(filebuf); i += 1 {
			fileinfo := filebuf[i]
			if !fileinfo.is_dir		do continue
			if fileinfo.name[0] == '_'	do continue // hidden
			menu_data.mapSelectFileElems[menu_data.mapSelectFileElemsCount] = gui_menuTitle_t{fileinfo.name}
			menu_data.mapSelectFileElemsCount += 1
			mapSelectFilesFetchDirAndAppend(fileinfo.fullpath)
		}
	}
}



menu_updateAndDrawLoadScreenUpdatePath :: proc() {
	if i32(rl.GetKeyPressed()) != 0 ||
		rl.IsMouseButtonPressed(rl.MouseButton.LEFT) ||
		rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) ||
		rl.IsMouseButtonPressed(rl.MouseButton.MIDDLE) {
		app_setUpdatePathKind(.MAIN_MENU)
		rl.PlaySound(menu_data.setValSound)
	}

	unfade := math.sqrt(glsl.smoothstep(0.0, 1.0, menu_data.loadScreenTimer * 0.5))

	rl.SetMusicVolume(menu_data.loadScreenMusic, unfade*unfade*unfade)
	playingMusic = &menu_data.loadScreenMusic

	rl.BeginDrawing()
		rl.ClearBackground(rl.ColorFromNormalized(linalg.lerp(vec4{0,0,0,0}, MENU_BACKGROUND, unfade)))
	
		OFFS :: 200
		STARTSCALE :: 12.0
		scale := glsl.min(
			f32(windowSizeX) / f32(menu_data.loadScreenLogo.width),
			f32(windowSizeY) / f32(menu_data.loadScreenLogo.height),
		) * (STARTSCALE + math.sqrt(unfade)) / (1.0 + STARTSCALE)
		rl.DrawTextureEx(
			menu_data.loadScreenLogo,
			{f32(windowSizeX)/2 - f32(menu_data.loadScreenLogo.width)*scale/4, f32(windowSizeY)/2 - f32(menu_data.loadScreenLogo.height)*scale/4},
			0.0, // rot
			scale * 0.5, // scale
			rl.ColorFromNormalized(linalg.lerp(vec4{0,0,0,0}, vec4{1,1,1,1}, unfade)),
		)

		gui_drawText(
			{f32(windowSizeX)/2-100, f32(windowSizeY)-130},
			25,
			rl.ColorFromNormalized(linalg.lerp(vec4{0,0,0,0}, vec4{1,1,1,1}, clamp(unfade-0.4 + math.sin(timepassed*4.0)*0.1, 0.0, 1.0))),
			"press any key to continue",
		)
	rl.EndDrawing()

	menu_data.loadScreenTimer += deltatime
}



// draw info about the menu navigation
menu_drawNavTips :: proc() {
	SIZE :: 25.0

	gui_drawText(
		{SIZE*2.0, f32(windowSizeY)-SIZE*3}, SIZE, {200,200,200,120},
		"hold CTRL to skip to next title / edit values faster",
	)
}






//
// GUI
//

GUI_SCROLL_MARGIN :: 200
GUI_SCROLL_SPEED :: 14.0

// val is not rendered
gui_menuButton_t :: struct {
	name	: string,
	val	: ^bool,
}

gui_menuBool_t :: struct {
	name	: string,
	val	: ^bool,
}

gui_menuFloat_t :: struct {
	name	: string,
	val	: ^f32,
	step	: f32,
}

gui_menuTitle_t :: struct {
	name	: string,
}

gui_menuFileButton_t :: struct {
	name		: string,
	fullpath	: string,
	val		: ^bool,
}

gui_menuElem_t :: union {
	gui_menuButton_t,
	gui_menuBool_t,
	gui_menuFloat_t,
	gui_menuTitle_t,
	gui_menuFileButton_t,
}



gui_drawText :: proc(pos : vec2, size : f32, color : rl.Color, text : string) {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	rl.DrawTextEx(menu_data.normalFont, cstr, pos, size, 0.0, color)
}

// @retunrs: true if any value changed
gui_updateAndDrawElemBuf :: proc(elems : []gui_menuElem_t) -> bool {
	selectDir := 0
	if rl.IsKeyPressed(rl.KeyboardKey.DOWN)	|| rl.IsKeyPressed(rl.KeyboardKey.S) do selectDir += 1
	if rl.IsKeyPressed(rl.KeyboardKey.UP)	|| rl.IsKeyPressed(rl.KeyboardKey.W) do selectDir -= 1
	
	if selectDir != 0 {
		rl.PlaySound(menu_data.selectSound)
	
		if !rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
			loopfind: for i := 0; i < len(elems); i += 1 {
				index := (int(menu_data.selected) + i*selectDir + selectDir) %% len(elems)
				#partial switch in elems[index] {
					case gui_menuTitle_t: continue loopfind
				}
				menu_data.selected = i32(index)
				break loopfind
			}
		} else { // jump between titles (also stops at first/last elem)
			loopfindjump: for i := 0; i < len(elems); i += 1 {
				index := (int(menu_data.selected) + i*selectDir + selectDir) %% len(elems)
				#partial switch in elems[index] {
					case gui_menuTitle_t:
						menu_data.selected = i32(index + selectDir)
						break loopfindjump
				}
			
				if index == 0 || index == len(elems)-1 {
					menu_data.selected = i32(index)
					break loopfindjump
				}
			}
		}
	}

	menu_data.selected = menu_data.selected %% i32(len(elems))

	SIZE :: 30
	offs : f32 = menu_data.startOffs
	selectedOffs : f32 = 0
	for i := 0; i < len(elems); i += 1 {
		isSelected := i32(i)==menu_data.selected
		col : rl.Color  = isSelected ? {220,220,220,220}:{200,200,200,160}
		vcol : rl.Color = isSelected ? {200,70,50,255}:{200,200,200,160}
		W :: 150
		nameoffs := f32(windowSizeX)/2 - W*1.2
		valoffs  := f32(windowSizeX)/2 + W
		switch elem in elems[i] {
			case gui_menuButton_t:
				gui_drawText({nameoffs, offs}, SIZE, vcol, elem.name)
			case gui_menuBool_t:
				gui_drawText({nameoffs, offs}, SIZE, col, elem.name)
				gui_drawText({valoffs, offs}, SIZE, vcol, elem.val^ ? "yes" : "no")
			case gui_menuFloat_t:
				gui_drawText({nameoffs, offs}, SIZE, col, elem.name)
				gui_drawText({valoffs, offs}, SIZE, vcol, fmt.tprint(elem.val^))
			case gui_menuTitle_t:
				offs += 0.8*SIZE
				gui_drawText({nameoffs-SIZE, offs}, SIZE * 0.8, {200,200,200,100}, elem.name)
			case gui_menuFileButton_t:
				gui_drawText({nameoffs, offs}, SIZE, vcol, elem.name)
				if isSelected {
					gui_drawText({valoffs, offs+SIZE*0.25}, SIZE*0.5, {col.r,col.g,col.b,100}, elem.fullpath)
				}
		}
		
		if isSelected {
			gui_drawText({nameoffs - 30, offs}, SIZE, vcol, ">")
			selectedOffs = offs
		}

		offs += SIZE
	}

	if selectedOffs > f32(windowSizeY)-GUI_SCROLL_MARGIN { // bottom
		menu_data.startOffs += (f32(windowSizeY)-GUI_SCROLL_MARGIN - selectedOffs) * clamp(deltatime * GUI_SCROLL_SPEED, 0.0, 1.0)
	}

	if selectedOffs < GUI_SCROLL_MARGIN { // top
		menu_data.startOffs += (GUI_SCROLL_MARGIN - selectedOffs) * clamp(deltatime * GUI_SCROLL_SPEED, 0.0, 1.0)
	}


	// edit selected value based on input
	isEdited := false
	switch elem in elems[menu_data.selected] {
		case gui_menuButton_t:
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) ||
				rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				elem.val^ = !elem.val^
				isEdited = true
			}
		case gui_menuBool_t:
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) ||
				rl.IsKeyPressed(rl.KeyboardKey.SPACE) ||
				rl.IsKeyPressed(rl.KeyboardKey.RIGHT) || 
				rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
				elem.val^ = !elem.val^
				isEdited = true
			}
		case gui_menuFloat_t:
			step := elem.step
			if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) do step *= 5.0
		
			if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
				elem.val^ += step
				isEdited = true
			} else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
				elem.val^ -= step
				isEdited = true
			}
		case gui_menuTitle_t:
		case gui_menuFileButton_t:
			if rl.IsKeyPressed(rl.KeyboardKey.ENTER) ||
				rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				elem.val^ = !elem.val^
				isEdited = true
			}
	}

	if isEdited {
		rl.PlaySound(menu_data.setValSound)
	}

	return isEdited
}

