package doq



import "core:strings"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import rl "vendor:raylib"
import "gui"




MENU_MAX_MAP_SELECT_FILES :: 256

MENU_BACKGROUND :: vec4{0.08,0.08,0.1,1.0}

menu_data : struct {
	loadScreenTimer	: f32,
	pauseMenuIsOpen	: bool,
	
	mapSelectFileElemsCount : i32,
	mapSelectFileElems	: [MENU_MAX_MAP_SELECT_FILES]gui.menuElem_t,
	mapSelectButtonBool	: bool, // shared
	mapSelectIsOpen		: bool,
}


menu_resetState :: proc() {
	gui.menuContext.selected = 0
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
	gui.drawText({f32(windowSizeX) - 150, f32(windowSizeY) - 50},	30, rl.Color{255,200, 50,255}, fmt.tprint("AMMO: ", gun_data.ammoCounts[gunindex]))
	// health
	gui.drawText({30, f32(windowSizeY) - 50},		30, rl.Color{255, 80, 80,255}, fmt.tprint("HEALTH: ", player_data.health))

	// draw gun ui
	for i : i32 = 0; i < GUN_COUNT; i += 1 {
		LINE :: 40
		TEXTHEIGHT :: LINE*0.5
		pos := vec2{f32(windowSizeX)-120, f32(windowSizeY)*0.5 + GUN_COUNT*LINE*0.5 - cast(f32)i*LINE}

		col := gun_data.ammoCounts[i]==0 ? gui.INACTIVE_COLOR:gui.ACTIVE_COLOR
		if i == cast(i32)gun_data.equipped do col = gui.ACTIVE_VAL_COLOR
		gui.drawText(pos, TEXTHEIGHT, col, fmt.tprint(cast(gun_kind_t)i))
		gui.drawText(pos - vec2{30,0}, TEXTHEIGHT, gui.TITLE_COLOR, fmt.tprint(args={i+1,"."}, sep=""))
	}

}

_debugtext_y : i32 = 2
menu_drawDebugUI :: proc() {
	if settings.drawFPS || settings.debugIsEnabled do rl.DrawFPS(0, 0)

	_debugtext_y = 2

	if settings.debugIsEnabled {
		debugtext :: proc(args : ..any) {
			SIZE :: 10
			tstr := fmt.tprint(args=args)
			cstr := strings.clone_to_cstring(tstr, context.temp_allocator)
			col := tstr[0] == ' ' ? rl.WHITE : rl.YELLOW
			rl.DrawText(cstr, tstr[0]==' '?16:4, _debugtext_y*(SIZE+2), SIZE, col)
			_debugtext_y += 1
		}

		debugtext("player")
		debugtext(" pos",		player_data.pos)
		debugtext(" vel",		player_data.vel)
		debugtext(" speed",		i32(linalg.length(player_data.vel)))
		debugtext(" onground",		player_data.isOnGround)
		debugtext(" onground timer",	player_data.onGroundTimer)
		debugtext("system")
		debugtext(" windowSize",		[]i32{windowSizeX, windowSizeY})
		debugtext(" app_updatePathKind",	app_updatePathKind)
		debugtext(" IsAudioDeviceReady",	rl.IsAudioDeviceReady())
		debugtext(" loadpath",			loadpath)
		debugtext(" gameIsPaused",		gameIsPaused)
		debugtext("map")
		debugtext(" bounds",			map_data.bounds)
		debugtext(" nextMapName",		map_data.nextMapName)
		debugtext(" startPlayerDir",		map_data.startPlayerDir)
		debugtext(" gunPickupCount",		map_data.gunPickupCount,
			"gunPickupSpawnCount",		map_data.gunPickupCount)
		debugtext(" healthPickupCount",		map_data.healthPickupCount,
			"healthPickupSpawnCount",	map_data.healthPickupSpawnCount)
		debugtext(" skyColor",			map_data.skyColor)
		debugtext(" fogStrengh",		map_data.fogStrength)
		debugtext("gun")
		debugtext(" equipped",		gun_data.equipped)
		debugtext(" last equipped",	gun_data.lastEquipped)
		debugtext(" timer",		gun_data.timer)
		debugtext(" ammo counts",	gun_data.ammoCounts)
		debugtext("bullets")
		debugtext(" bulletline count", bullet_data.bulletLinesCount)
		debugtext("enemies")
		debugtext(" grunt count",		enemy_data.gruntCount)
		debugtext(" knight count",		enemy_data.knightCount)
		debugtext(" knight anim count",		asset_data.enemy.knightAnimCount)
		debugtext(" knight anim[0] bone count",	asset_data.enemy.knightAnim[0].boneCount)
		debugtext(" knight anim[0] frame count",asset_data.enemy.knightAnim[0].frameCount)
		debugtext(" knight anim frame",		enemy_data.knightAnimFrame)
		debugtext("menus")
		debugtext(" pauseMenuIsOpen",		menu_data.pauseMenuIsOpen)
		debugtext(" mapSelectFileElemsCount",	menu_data.mapSelectFileElemsCount)
		debugtext("gui")
		debugtext(" selected",			gui.menuContext.selected)
		debugtext(" startOffset",		gui.menuContext.startOffs)
	}
}



menu_updateAndDrawPauseMenu :: proc() {
	if map_data.isMapFinished {
		screenTint = {}
		shouldContinue := false
		shouldExitToMainMenu := false
		shouldReset := false
		elems : []gui.menuElem_t = {
			gui.menuButton_t{"continue",		&shouldContinue},
			gui.menuButton_t{"play again",		&shouldReset},
			gui.menuButton_t{"exit to main menu",	&shouldExitToMainMenu},
		}
	
		gui.updateAndDrawElemBuf(elems[:])


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
		elems : []gui.menuElem_t = {
			gui.menuButton_t{"resume",		&gameIsPaused},
			gui.menuButton_t{"reset",		&shouldReset},
			gui.menuButton_t{"go to main menu",	&shouldExitToMainMenu},
			gui.menuButton_t{"exit to desktop",	&app_shouldExitNextFrame},

			gui.menuTitle_t{"settings"},
			gui.menuFloat_t{"audio volume",			&settings.audioMasterVolume,	0.05},
			gui.menuFloat_t{"music volume",			&settings.audioMusicVolume,	0.05},
			gui.menuFloat_t{"mouse sensitivity",		&settings.mouseSensitivity,	0.05},
			gui.menuFloat_t{"crosshair visibility",		&settings.crosshairOpacity,	0.1},
			gui.menuFloat_t{"gun X offset",			&settings.gunXOffset,		0.025},
			gui.menuFloat_t{"fild of view",			&settings.FOV,			10.0},
			gui.menuFloat_t{"viewmodel field of view",	&settings.viewmodelFOV,		10.0},
			gui.menuBool_t{"show FPS",			&settings.drawFPS},
			gui.menuBool_t{"enable debug mode",		&settings.debugIsEnabled},
		}

		menu_drawNavTips()
		if gui.updateAndDrawElemBuf(elems[:]) {
			settings_saveToFile()
		}

		rl.SetSoundVolume(asset_data.player.swooshSound, 0.0)

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
	rl.SetMusicVolume(asset_data.loadScreenMusic, 1.0)
	playingMusic = &asset_data.loadScreenMusic

	rl.BeginDrawing()
	rl.ClearBackground(rl.ColorFromNormalized(MENU_BACKGROUND))
	menu_drawNavTips()
	menu_drawDebugUI()

	if menu_data.mapSelectIsOpen {
		gui.updateAndDrawElemBuf(menu_data.mapSelectFileElems[:menu_data.mapSelectFileElemsCount])
		if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
			rl.PlaySound(gui.menuContext.setValSound)
			menu_resetState()
		}

		if menu_data.mapSelectButtonBool {
			menu_data.mapSelectButtonBool = false
			elem, ok := menu_data.mapSelectFileElems[gui.menuContext.selected].(gui.menuFileButton_t)
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
		elems : []gui.menuElem_t = {
			gui.menuButton_t{"singleplayer",	&shouldMapSelect},
			gui.menuButton_t{"exit to desktop",	&app_shouldExitNextFrame},

			gui.menuTitle_t{"settings"},
			gui.menuFloat_t{"audio volume",			&settings.audioMasterVolume,	0.05},
			gui.menuFloat_t{"music volume",			&settings.audioMusicVolume,	0.05},
			gui.menuFloat_t{"mouse sensitivity",		&settings.mouseSensitivity,	0.05},
			gui.menuFloat_t{"crosshair visibility",		&settings.crosshairOpacity,	0.1},
			gui.menuFloat_t{"gun size offset",		&settings.gunXOffset,		0.025},
			gui.menuFloat_t{"fild of view",			&settings.FOV,			10.0},
			gui.menuFloat_t{"viewmodel field of view",	&settings.viewmodelFOV,		10.0},
			gui.menuBool_t{"show FPS",			&settings.drawFPS},
			gui.menuBool_t{"enable debug mode",		&settings.debugIsEnabled},
		}

		if gui.updateAndDrawElemBuf(elems[:]) {
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
			//menu_data.mapSelectFileElems[menu_data.mapSelectFileElemsCount] = gui.menuButton_t{fileinfo.name[:dotindex], &menu_data.mapSelectButtonBool}
			menu_data.mapSelectFileElems[menu_data.mapSelectFileElemsCount] = gui.menuFileButton_t{
				fileinfo.name[:dotindex], fileinfo.fullpath, &menu_data.mapSelectButtonBool,
			}
			menu_data.mapSelectFileElemsCount += 1
		}

		// get subfolders
		for i := 0; i < len(filebuf); i += 1 {
			fileinfo := filebuf[i]
			if !fileinfo.is_dir		do continue
			if fileinfo.name[0] == '_'	do continue // hidden
			menu_data.mapSelectFileElems[menu_data.mapSelectFileElemsCount] = gui.menuTitle_t{fileinfo.name}
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
		rl.PlaySound(gui.menuContext.setValSound)
	}

	unfade := math.sqrt(glsl.smoothstep(0.0, 1.0, menu_data.loadScreenTimer * 0.5))

	rl.SetMusicVolume(asset_data.loadScreenMusic, unfade*unfade*unfade)
	playingMusic = &asset_data.loadScreenMusic

	rl.BeginDrawing()
		rl.ClearBackground(rl.ColorFromNormalized(linalg.lerp(vec4{0,0,0,0}, MENU_BACKGROUND, unfade)))
	
		OFFS :: 200
		STARTSCALE :: 4.0
		scale := glsl.min(
			f32(windowSizeX) / f32(asset_data.loadScreenLogo.width),
			f32(windowSizeY) / f32(asset_data.loadScreenLogo.height),
		) * (STARTSCALE + math.sqrt(unfade)) / (1.0 + STARTSCALE)
		col := rl.ColorFromNormalized(linalg.lerp(vec4{0,0,0,0}, vec4{1,1,1,1}, unfade))
		rl.DrawTextureEx(
			asset_data.loadScreenLogo,
			{
                f32(windowSizeX)/2 - f32(asset_data.loadScreenLogo.width)*scale/4,
                f32(windowSizeY)/2 - f32(asset_data.loadScreenLogo.height)*scale/4,
            },
			0.0, // rot
			scale * 0.5, // scale
			col,
		)

		gui.drawText(
			{f32(windowSizeX)/2-100, f32(windowSizeY)-130},
			25,
			rl.ColorFromNormalized(
                linalg.lerp(vec4{0,0,0,0}, vec4{1,1,1,1}, clamp(unfade-0.4 + math.sin(timepassed*4.0)*0.1, 0.0, 1.0)),
            ),
			"press any key to continue",
		)

		gui.drawText(
			{f32(windowSizeX)-130, f32(windowSizeY)-50},
			25,
			col,
			DOQ_VERSION_STRING,
		)
	rl.EndDrawing()

	menu_data.loadScreenTimer += deltatime
}



// draw info about the menu navigation
menu_drawNavTips :: proc() {
	SIZE :: 25.0

	gui.drawText(
		{SIZE*2.0, f32(windowSizeY)-SIZE*3}, SIZE, {200,200,200,120},
		"hold CTRL to skip to next title / edit values faster",
	)
}
