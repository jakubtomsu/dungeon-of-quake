package doq



// 'Dungeon of Quake' is a simple first person shooter, heavily inspired by the Quake franchise
// using raylib



import "core:math/linalg"
import "core:math/rand"
import "core:fmt"
import "core:time"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:strconv"
import rl "vendor:raylib"



println :: fmt.println
vec2 :: rl.Vector2
vec3 :: rl.Vector3
vec4 :: rl.Vector4
ivec2 :: [2]i32
ivec3 :: [3]i32
mat3 :: linalg.Matrix3f32



windowSizeX : i32 = 0
windowSizeY : i32 = 0

camera: rl.Camera = {}
viewmodelCamera: rl.Camera = {}

framespassed : i64 = 0
deltatime : f32 = 0.01
timepassed : f32 = 0.0
app_shouldExitNextFrame : bool = false
loadpath : string

renderTextureMain : rl.RenderTexture2D
postprocessShader : rl.Shader
randData : rand.Rand

playingMusic : ^rl.Music

gameIsPaused : bool = false
settings : struct {
	drawFPS			: bool,
	debugIsEnabled		: bool,
	audioMasterVolume	: f32,
	audioMusicVolume	: f32,
	crosshairOpacity	: f32,
	mouseSensitivity	: f32,
	FOV			: f32,
	viewmodelFOV		: f32,
	gunXOffset		: f32,
}



screenTint : vec3 = {1,1,1}

app_updatePathKind_t :: enum {
	LOADSCREEN = 0,
	MAIN_MENU,
	GAME,
}

app_updatePathKind : app_updatePathKind_t



// this just gets called from main
_doq_main :: proc() {
	_app_init()

	menu_data.startOffs = -10

	for !rl.WindowShouldClose() && !app_shouldExitNextFrame {
		println("### frame =", framespassed, "deltatime =", deltatime)
		framespassed += 1
		
		// fixup
		settings.audioMasterVolume	= clamp(settings.audioMasterVolume, 0.0, 1.0)
		settings.audioMusicVolume	= clamp(settings.audioMusicVolume, 0.0, 1.0)
		settings.crosshairOpacity	= clamp(settings.crosshairOpacity, 0.0, 1.0)
		settings.mouseSensitivity	= clamp(settings.mouseSensitivity, 0.1, 5.0)
		settings.FOV			= clamp(settings.FOV,		20.0, 170.0)
		settings.viewmodelFOV		= clamp(settings.viewmodelFOV,	80.0, 120.0)
		settings.gunXOffset		= clamp(settings.gunXOffset,	-0.4, 0.4)
		rl.SetMasterVolume(settings.audioMasterVolume)

		camera.fovy		= settings.FOV
		viewmodelCamera.fovy	= settings.viewmodelFOV
	
		rl.DisableCursor()

		if playingMusic != nil {
			rl.UpdateMusicStream(playingMusic^)
		}

		if settings.debugIsEnabled do rl.SetTraceLogLevel(rl.TraceLogLevel.ALL)
		else do rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)


		if app_updatePathKind != .GAME do gameStopSounds()

		switch app_updatePathKind {
			case .LOADSCREEN:
				menu_updateAndDrawLoadScreenUpdatePath()
			case .MAIN_MENU:
				menu_updateAndDrawMainMenuUpdatePath()
			case .GAME:
			// main game update path
			{
				rl.UpdateCamera(&camera)
				rl.UpdateCamera(&viewmodelCamera)

				_app_update()

				rl.BeginTextureMode(renderTextureMain)
					bckgcol := vec4{
						map_data.skyColor.r,
						map_data.skyColor.g,
						map_data.skyColor.b,
						1.0,
					}
					rl.ClearBackground(rl.ColorFromNormalized(bckgcol))
					rl.BeginMode3D(camera)
						_app_render3d()
						if !gameIsPaused {
							_gun_update()
							_player_update()
						}
						_enemy_updateDataAndRender()
						_bullet_updateDataAndRender()
					rl.EndMode3D()
					rl.BeginMode3D(viewmodelCamera)
						gun_drawModel(gun_calcViewportPos())
					rl.EndMode3D()
				rl.EndTextureMode()

				rl.BeginDrawing()
					rl.ClearBackground(rl.PINK) // for debug
					rl.SetShaderValue(
						postprocessShader,
						cast(rl.ShaderLocationIndex)rl.GetShaderLocation(postprocessShader, "tintColor"),
						&screenTint,
						rl.ShaderUniformDataType.VEC3,
					)

					rl.BeginShaderMode(postprocessShader)
						rl.DrawTextureRec(
							renderTextureMain.texture,
							rl.Rectangle{
								0, 0,
								cast(f32)renderTextureMain.texture.width,
								-cast(f32)renderTextureMain.texture.height,
							},
							{0, 0},
							rl.WHITE,
						)
					rl.EndShaderMode()
					
					if gameIsPaused{
						menu_updateAndDrawPauseMenu()
					}
					
					_app_render2d()
				rl.EndDrawing()
			}
		}



		deltatime = rl.GetFrameTime()
		if !gameIsPaused {
			timepassed += deltatime // not really accurate but whatever
		}
	}

	rl.CloseWindow()
	rl.CloseAudioDevice()
}




//
// APP
//

_app_init :: proc() {
	loadpath = filepath.clean(string(rl.GetWorkingDirectory()))
	println("loadpath", loadpath)
	
	settings_setDefault()
	settings_loadFromFile()

	rl.SetWindowState({
		.WINDOW_TOPMOST,
		.WINDOW_RESIZABLE,
		.FULLSCREEN_MODE,
		//.WINDOW_HIGHDPI,
		.VSYNC_HINT,
	})
	rl.InitWindow(0, 0, "Dungeon of Quake")
	rl.ToggleFullscreen()
	windowSizeX = rl.GetScreenWidth()
	windowSizeY = rl.GetScreenHeight()

	rl.SetExitKey(rl.KeyboardKey.NULL)
	//rl.SetTargetFPS(75)

	rl.InitAudioDevice()

	rl.SetMasterVolume(settings.audioMasterVolume)


	renderTextureMain = rl.LoadRenderTexture(windowSizeX, windowSizeY)

	menu_data.loadScreenLogo	= loadTexture("dungeon_of_quake_logo.png")
	rl.SetTextureFilter(menu_data.loadScreenLogo, rl.TextureFilter.TRILINEAR)

	map_data.defaultShader		= loadShader("default.vert", "default.frag")
	postprocessShader		= loadFragShader("postprocess.frag")
	map_data.tileShader		= loadShader("tile.vert", "tile.frag")
	map_data.portalShader		= loadShader("portal.vert", "portal.frag")
	bullet_data.bulletLineShader	= loadShader("bulletLine.vert", "bulletLine.frag")
	map_data.tileShaderCamPosUniformIndex = cast(rl.ShaderLocationIndex)rl.GetShaderLocation(map_data.tileShader, "camPos")



	map_data.wallTexture		= loadTexture("tile0.png")
	map_data.portalTexture		= loadTexture("portal.png")
	map_data.elevatorTexture	= loadTexture("metal.png")

	if !rl.IsAudioDeviceReady() do time.sleep(10)

	map_data.backgroundMusic	= loadMusic("music0.wav")
	map_data.ambientMusic		= loadMusic("wind.wav")
	map_data.elevatorSound		= loadSound("elevator.wav")
	map_data.elevatorEndSound	= loadSound("elevator_end0.wav")
	rl.SetSoundVolume(map_data.elevatorSound, 0.1)
	//rl.PlayMusicStream(map_data.backgroundMusic)
	rl.PlayMusicStream(map_data.ambientMusic)
	rl.SetMasterVolume(0.5)

	gun_data.shotgunSound		= loadSound("shotgun.wav")
	gun_data.machinegunSound	= loadSound("machinegun.wav")
	gun_data.laserrifleSound	= loadSound("laserrifle.wav")
	gun_data.headshotSound		= loadSound("headshot.wav")
	gun_data.emptyMagSound		= loadSound("emptymag.wav")
	gun_data.ammoPickupSound	= loadSound("ammo_pickup.wav")
	rl.SetSoundVolume(gun_data.headshotSound, 1.0)
	rl.SetSoundPitch (gun_data.headshotSound, 0.85)
	rl.SetSoundVolume(gun_data.shotgunSound, 0.55)
	rl.SetSoundPitch (gun_data.shotgunSound, 1.1)
	rl.SetSoundVolume(gun_data.laserrifleSound, 0.2)
	rl.SetSoundPitch(gun_data.laserrifleSound, 0.8)
	rl.SetSoundVolume(gun_data.emptyMagSound, 0.6)
	rl.SetSoundVolume(gun_data.ammoPickupSound, 1.2)

	player_data.jumpSound		= loadSound("jump.wav")
	player_data.footstepSound	= loadSound("footstep.wav")
	player_data.landSound		= loadSound("land.wav")
	player_data.damageSound		= loadSound("death0.wav")
	player_data.swooshSound		= loadSound("swoosh.wav")
	player_data.healthPickupSound	= loadSound("heal.wav")
	rl.SetSoundVolume(player_data.landSound, 0.45)
	rl.SetSoundPitch (player_data.landSound, 0.8)

	gun_data.gunModels[cast(i32)gun_kind_t.SHOTGUN]		= loadModel("shotgun.glb")
	gun_data.gunModels[cast(i32)gun_kind_t.MACHINEGUN]	= loadModel("machinegun.glb")
	gun_data.gunModels[cast(i32)gun_kind_t.LASERRIFLE]	= loadModel("laserrifle.glb")
	gun_data.flareModel		= loadModel("flare.glb")

	map_data.tileModel		= rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
	map_data.elevatorModel		= loadModel("elevator.glb")
	map_data.healthPickupModel	= loadModel("healthpickup.glb")
	map_data.boxModel		= loadModel("box.glb")
	rl.SetMaterialTexture(&map_data.tileModel.materials[0], rl.MaterialMapIndex.DIFFUSE, map_data.wallTexture)
	rl.SetMaterialTexture(&map_data.elevatorModel.materials[0], rl.MaterialMapIndex.DIFFUSE, map_data.elevatorTexture)
	map_data.tileModel.materials[0].shader		= map_data.tileShader
	map_data.elevatorModel.materials[0].shader	= map_data.tileShader
	map_data.boxModel.materials[1].shader		= map_data.defaultShader
	//rl.SetMaterialTexture(&map_data.boxModel.materials[1], rl.MaterialMapIndex.DIFFUSE, map_data.wallTexture)

	enemy_data.gruntHitSound	= loadSound("death2.wav")
	enemy_data.gruntDeathSound	= enemy_data.gruntHitSound
	enemy_data.knightHitSound	= enemy_data.gruntHitSound
	enemy_data.knightDeathSound	= enemy_data.gruntHitSound
	enemy_data.gruntModel		= loadModel("grunt.glb")
	enemy_data.knightModel		= enemy_data.gruntModel
	rl.SetSoundVolume(enemy_data.gruntHitSound, 0.3)


	camera.position = {0, 3, 0}
	camera.target = {}
	camera.up = vec3{0.0, 1.0, 0.0}
	camera.projection = rl.CameraProjection.PERSPECTIVE
	rl.SetCameraMode(camera, rl.CameraMode.CUSTOM)

	viewmodelCamera.position = {0,0,0}
	viewmodelCamera.target = {0,0,1}
	viewmodelCamera.up = {0,1,0}
	viewmodelCamera.projection = rl.CameraProjection.PERSPECTIVE
	rl.SetCameraMode(viewmodelCamera, rl.CameraMode.CUSTOM)

	//normalFont = loadFont("metalord.ttf")
	menu_data.titleFont		= loadFont("eurcntrc.ttf")
	menu_data.normalFont		= loadFont("germania_one.ttf")
	menu_data.selectSound		= loadSound("button4.wav")
	menu_data.setValSound		= loadSound("button3.wav")
	menu_data.loadScreenMusic	= loadMusic("ambient0.wav")
	rl.SetSoundVolume(menu_data.selectSound, 0.6)
	rl.SetSoundVolume(menu_data.setValSound, 0.8)
	rl.PlayMusicStream(menu_data.loadScreenMusic)

	rand.init(&randData, cast(u64)time.now()._nsec)
	
	map_clearAll()
	map_data.bounds = {MAP_MAX_WIDTH, MAP_MAX_WIDTH}
	if os.is_file(appendToAssetPath("maps", "_quickload.dqm")) {
		map_loadFromFile("_quickload.dqm")
		app_setUpdatePathKind(.GAME)
	}
	
	//map_debugPrint()

	player_startMap()

}

_app_update :: proc() {
	//rl.UpdateMusicStream(map_data.backgroundMusic)
	//rl.UpdateMusicStream(map_data.ambientMusic)
	//rl.SetMusicVolume(player_data.swooshMusic, clamp(linalg.length(player_data.vel * 0.05), 0.0, 1.0))

	if rl.IsKeyPressed(rl.KeyboardKey.RIGHT_ALT) do settings.debugIsEnabled = !settings.debugIsEnabled
	
	if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) do gameIsPaused = !gameIsPaused

	// pull elevators down
	{
		playerTilePos := map_worldToTile(player_data.pos)
		c := [2]u8{cast(u8)playerTilePos.x, cast(u8)playerTilePos.y}
		for key, val in map_data.elevatorHeights {
			if key == c do continue
			map_data.elevatorHeights[key] = clamp(val - (TILE_ELEVATOR_MOVE_FACTOR * deltatime), 0.0, 1.0)
		}
	}

	screenTint = linalg.lerp(screenTint, vec3{1, 1, 1}, clamp(deltatime * 3.0, 0.0, 1.0))
}

_app_render2d :: proc() {
	
	menu_drawPlayerUI()

	menu_drawDebugUI()
}

_app_render3d :: proc() {
	when false {
		if settings.debugIsEnabled {
			LEN :: 100
			WID :: 1
			rl.DrawCube(vec3{LEN, 0, 0}, LEN,WID,WID, rl.RED)
			rl.DrawCube(vec3{0, LEN, 0}, WID,LEN,WID, rl.GREEN)
			rl.DrawCube(vec3{0, 0, LEN}, WID,WID,LEN, rl.BLUE)
			rl.DrawCube(vec3{0, 0, 0}, WID,WID,WID, rl.RAYWHITE)
		}
	}

	//rl.DrawPlane(vec3{0.0, 0.0, 0.0}, vec2{32.0, 32.0}, rl.LIGHTGRAY) // Draw ground

	rl.SetShaderValue(map_data.tileShader, map_data.tileShaderCamPosUniformIndex, &camera.position, rl.ShaderUniformDataType.VEC3)
	fogColor := vec4{
		map_data.skyColor.r,
		map_data.skyColor.g,
		map_data.skyColor.b,
		map_data.fogStrength,
	}
	
	rl.SetShaderValue(
		map_data.defaultShader,
		cast(rl.ShaderLocationIndex)rl.GetShaderLocation(map_data.defaultShader, "camPos"),
		&camera.position,
		rl.ShaderUniformDataType.VEC3,
	)
	rl.SetShaderValue(
		map_data.defaultShader,
		cast(rl.ShaderLocationIndex)rl.GetShaderLocation(map_data.defaultShader, "fogColor"),
		&fogColor,
		rl.ShaderUniformDataType.VEC4,
	)

	rl.SetShaderValue(
		map_data.tileShader,
		cast(rl.ShaderLocationIndex)rl.GetShaderLocation(map_data.tileShader, "fogColor"),
		&fogColor,
		rl.ShaderUniformDataType.VEC4,
	)

	rl.SetShaderValue(
		map_data.portalShader,
		cast(rl.ShaderLocationIndex)rl.GetShaderLocation(map_data.portalShader, "timePassed"),
		&timepassed,
		rl.ShaderUniformDataType.FLOAT,
	)
	
	map_drawTilemap()
}



app_setUpdatePathKind :: proc(kind : app_updatePathKind_t) {
	app_updatePathKind = kind
	menu_resetState()
	gameIsPaused = false
}





world_reset :: proc() {
	player_initData()
	player_startMap()

	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		enemy_data.grunts[i].pos = enemy_data.grunts[i].spawnPos
		enemy_data.grunts[i].health = ENEMY_GRUNT_HEALTH
		enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME
		enemy_data.grunts[i].vel = {}
		enemy_data.grunts[i].target = {}
		enemy_data.grunts[i].isMoving = false
	}

	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		enemy_data.knights[i].pos = enemy_data.knights[i].spawnPos
		enemy_data.knights[i].health = ENEMY_KNIGHT_HEALTH
		enemy_data.knights[i].attackTimer = ENEMY_KNIGHT_ATTACK_TIME
		enemy_data.knights[i].vel = {}
		enemy_data.knights[i].target = {}
		enemy_data.knights[i].isMoving = false
	}

	map_data.gunPickupCount		= map_data.gunPickupSpawnCount
	map_data.healthPickupCount	= map_data.healthPickupSpawnCount
}






settings_setDefault :: proc() {
	settings = {
		drawFPS			= false,
		debugIsEnabled		= false,
		audioMasterVolume	= 0.5,
		audioMusicVolume	= 0.4,
		crosshairOpacity	= 0.2,
		mouseSensitivity	= 1.0,
		FOV			= 100.0,
		viewmodelFOV		= 100.0,
		gunXOffset		= 0.1,
	}
}

settings_getFilePath :: proc() -> string {
	return fmt.tprint(args={loadpath, filepath.SEPARATOR_STRING, ".doq_settings"}, sep="")
}

settings_saveToFile :: proc() {
	text := fmt.tprint(
		args={
			"drawFPS",		SERI_ATTRIB_SEPARATOR, " ", settings.drawFPS,		"\n",
			"debugIsEnabled",	SERI_ATTRIB_SEPARATOR, " ", settings.debugIsEnabled,	"\n",
			"audioMasterVolume",	SERI_ATTRIB_SEPARATOR, " ", settings.audioMasterVolume,	"\n",
			"audioMusicVolume",	SERI_ATTRIB_SEPARATOR, " ", settings.audioMusicVolume,	"\n",
			"crosshairOpacity",	SERI_ATTRIB_SEPARATOR, " ", settings.crosshairOpacity,	"\n",
			"mouseSensitivity",	SERI_ATTRIB_SEPARATOR, " ", settings.mouseSensitivity,	"\n",
			"FOV",			SERI_ATTRIB_SEPARATOR, " ", settings.FOV,		"\n",
			"viewmodelFOV",		SERI_ATTRIB_SEPARATOR, " ", settings.viewmodelFOV,	"\n",
			"gunXOffset",		SERI_ATTRIB_SEPARATOR, " ", settings.gunXOffset,	"\n",
		},
		sep="",
	)

	os.write_entire_file(settings_getFilePath(), transmute([]u8)text)
}

settings_loadFromFile :: proc() {
	buf, ok := os.read_entire_file_from_filename(settings_getFilePath())
	if !ok {
		println("! error: unable to read settings file")
		return
	}
	defer delete(buf)

	text := transmute(string)buf
	index : i32 = 0
	for index < i32(len(text)) {
		seri_skipWhitespace(buf, &index)
		if seri_attribMatch(buf, &index, "drawFPS")		do settings.drawFPS		= seri_readBool(buf, &index)
		if seri_attribMatch(buf, &index, "debugIsEnabled")	do settings.debugIsEnabled	= seri_readBool(buf, &index)
		if seri_attribMatch(buf, &index, "audioMasterVolume")	do settings.audioMasterVolume	= seri_readF32 (buf, &index)
		if seri_attribMatch(buf, &index, "audioMusicVolume")	do settings.audioMusicVolume	= seri_readF32 (buf, &index)
		if seri_attribMatch(buf, &index, "crosshairOpacity")	do settings.crosshairOpacity	= seri_readF32 (buf, &index)
		if seri_attribMatch(buf, &index, "mouseSensitivity")	do settings.mouseSensitivity	= seri_readF32 (buf, &index)
		if seri_attribMatch(buf, &index, "FOV")			do settings.FOV			= seri_readF32 (buf, &index)
		if seri_attribMatch(buf, &index, "viewmodelFOV")	do settings.viewmodelFOV	= seri_readF32 (buf, &index)
		if seri_attribMatch(buf, &index, "gunXOffset")		do settings.gunXOffset		= seri_readF32 (buf, &index)
	}
}



gameStopSounds :: proc() {
	rl.StopSound(map_data.elevatorSound)
	rl.StopSound(player_data.swooshSound)
}





//
// BULLETS
//

BULLET_LINEAR_EFFECT_MAX_COUNT :: 64
BULLET_LINEAR_EFFECT_MESH_QUALITY :: 5 // equal to cylinder slices

BULLET_REMOVE_THRESHOLD :: 0.04

bullet_ammoInfo_t :: struct {
	damage : f32,
	knockback : f32,
}

bullet_data : struct {
	bulletLinesCount : i32,
	bulletLines : [BULLET_LINEAR_EFFECT_MAX_COUNT]struct {
		start		: vec3,
		timeToLive	: f32,
		end		: vec3,
		radius		: f32,
		color		: vec4,
		duration	: f32,
	},

	bulletLineShader	: rl.Shader,
}

// @param timeToLive: in seconds
bullet_createBulletLine :: proc(start : vec3, end : vec3, rad : f32, col : vec4, duration : f32) {
	if duration <= BULLET_REMOVE_THRESHOLD do return
	index := bullet_data.bulletLinesCount
	if index + 1 >= BULLET_LINEAR_EFFECT_MAX_COUNT do return
	bullet_data.bulletLinesCount += 1
	bullet_data.bulletLines[index] = {}
	bullet_data.bulletLines[index].start		= start
	bullet_data.bulletLines[index].timeToLive	= duration
	bullet_data.bulletLines[index].end		= end
	bullet_data.bulletLines[index].radius		= rad
	bullet_data.bulletLines[index].color		= col
	bullet_data.bulletLines[index].duration	= duration
}

bullet_shootRaycast :: proc(start : vec3, dir : vec3, damage : f32, rad : f32, col : vec4, effectDuration : f32) -> f32 {
	tn, hit, enemykind, enemyindex := phy_boxcastWorld(start, start + dir*1e6, vec3{rad,rad,rad})
	hitpos := start + dir*tn
	bullet_createBulletLine(start + dir*rad*2.0, hitpos, rad, col, effectDuration)
	if hit {
		switch enemykind {
			case enemy_kind_t.NONE:
			case enemy_kind_t.GRUNT:
				headshot := hitpos.y > enemy_data.grunts[enemyindex].pos.y + ENEMY_GRUNT_SIZE.y*ENEMY_HEADSHOT_HALF_OFFSET
				enemy_data.grunts[enemyindex].health -= headshot ? damage*2 : damage
				if headshot do playSound(gun_data.headshotSound)
				playSoundMulti(enemy_data.gruntHitSound)
				if enemy_data.grunts[enemyindex].health <= 0.0 do playSoundMulti(enemy_data.gruntDeathSound)
				enemy_data.grunts[enemyindex].vel += dir * 10.0 * damage
			case enemy_kind_t.KNIGHT:
				headshot := hitpos.y > enemy_data.knights[enemyindex].pos.y + ENEMY_KNIGHT_SIZE.y*ENEMY_HEADSHOT_HALF_OFFSET
				enemy_data.knights[enemyindex].health -= headshot ? damage*2 : damage
				if headshot do playSound(gun_data.headshotSound)
				playSoundMulti(enemy_data.knightHitSound)
				if enemy_data.knights[enemyindex].health <= 0.0 do playSoundMulti(enemy_data.knightDeathSound)
				enemy_data.knights[enemyindex].vel += dir * 10.0 * damage
		}
	}
	return tn
}

bullet_shootProjectile :: proc(start : vec3, dir : vec3, damage : f32, rad : f32, col : vec4) {
	// TODO
}

_bullet_updateDataAndRender :: proc() {
	assert(bullet_data.bulletLinesCount >= 0)
	assert(bullet_data.bulletLinesCount < BULLET_LINEAR_EFFECT_MAX_COUNT)

	if !gameIsPaused {
		// remove old
		loopremove : for i : i32 = 0; i < bullet_data.bulletLinesCount; i += 1 {
			bullet_data.bulletLines[i].timeToLive -= deltatime
			if bullet_data.bulletLines[i].timeToLive <= BULLET_REMOVE_THRESHOLD { // needs to be removed
				if i + 1 >= bullet_data.bulletLinesCount { // we're on the last one
					bullet_data.bulletLinesCount -= 1
					break loopremove
				}
				bullet_data.bulletLinesCount -= 1
				lastindex := bullet_data.bulletLinesCount
				bullet_data.bulletLines[i] = bullet_data.bulletLines[lastindex]
			}
		}
	}

	// draw
	rl.BeginShaderMode(bullet_data.bulletLineShader)
	for i : i32 = 0; i < bullet_data.bulletLinesCount; i += 1 {
		fade := (bullet_data.bulletLines[i].timeToLive / bullet_data.bulletLines[i].duration)
		col := bullet_data.bulletLines[i].color

		rl.DrawCylinderEx(
			bullet_data.bulletLines[i].start,
			bullet_data.bulletLines[i].end,
			fade * bullet_data.bulletLines[i].radius * 0.05,
			fade * bullet_data.bulletLines[i].radius * 0.4,
			3,
			rl.ColorFromNormalized(vec4{1,1,1,0.5 + fade*0.5}),
		)

		rl.DrawCylinderEx(
			bullet_data.bulletLines[i].start,
			bullet_data.bulletLines[i].end,
			fade * bullet_data.bulletLines[i].radius * 0.1,
			fade * bullet_data.bulletLines[i].radius,
			BULLET_LINEAR_EFFECT_MESH_QUALITY,
			rl.ColorFromNormalized(vec4{col.r, col.g, col.b, col.a * fade}),
		)

		//rl.DrawSphere(
		//	bullet_data.bulletLines[i].start,
		//	fade * bullet_data.bulletLines[i].radius,
		//	rl.ColorFromNormalized(vec4{col.r, col.g, col.b, col.a * fade}),
		//)
	}
	rl.EndShaderMode()
}






//
// ENEMIES
//

ENEMY_GRUNT_MAX_COUNT	:: 64
ENEMY_KNIGHT_MAX_COUNT	:: 64

ENEMY_HEALTH_MULTIPLIER		:: 1.5
ENEMY_HEADSHOT_HALF_OFFSET	:: 0.0
ENEMY_GRAVITY			:: 5.0

ENEMY_GRUNT_SIZE		:: vec3{2.5, 4.5, 2.5}
ENEMY_GRUNT_ACCELERATION	:: 13
ENEMY_GRUNT_MAX_SPEED		:: 14
ENEMY_GRUNT_FRICTION		:: 5
ENEMY_GRUNT_MIN_GOOD_DIST	:: 30
ENEMY_GRUNT_MAX_GOOD_DIST	:: 60
ENEMY_GRUNT_ATTACK_TIME		:: 1.5
ENEMY_GRUNT_DAMAGE		:: 1.0
ENEMY_GRUNT_HEALTH		:: 1.0
ENEMY_GRUNT_SPEED_RAND		:: 0.008 // NOTE: multiplier for length(player velocity) ^ 2
ENEMY_GRUNT_DIST_RAND		:: 0.7
ENEMY_GRUNT_MAX_DIST		:: 250.0

ENEMY_KNIGHT_SIZE		:: vec3{2.0, 3.5, 2.0}
ENEMY_KNIGHT_ACCELERATION	:: 12
ENEMY_KNIGHT_MAX_SPEED		:: 12
ENEMY_KNIGHT_FRICTION		:: 4
ENEMY_KNIGHT_DAMAGE		:: 0.8
ENEMY_KNIGHT_ATTACK_TIME	:: 0.6
ENEMY_KNIGHT_HEALTH		:: 1.0
ENEMY_KNIGHT_RANGE		:: 8.0

enemy_kind_t :: enum u8 {
	NONE = 0,
	GRUNT,
	KNIGHT,
}

enemy_data : struct {
	gruntHitSound		: rl.Sound,
	gruntDeathSound		: rl.Sound,
	knightHitSound		: rl.Sound,
	knightDeathSound	: rl.Sound,
	gruntModel		: rl.Model,
	knightModel		: rl.Model,

	gruntCount : i32,
	grunts : [ENEMY_GRUNT_MAX_COUNT]struct {
		spawnPos		: vec3,
		attackTimer		: f32,
		pos			: vec3,
		health			: f32,
		target			: vec3,
		isMoving		: bool,
		vel			: vec3,
	},

	knightCount : i32,
	knights : [ENEMY_KNIGHT_MAX_COUNT]struct {
		spawnPos	: vec3,
		health		: f32,
		pos		: vec3,
		attackTimer	: f32,
		isMoving	: bool,
		vel		: vec3,
		target		: vec3,
	},
}



// guy with a gun
enemy_spawnGrunt :: proc(pos : vec3) {
	index := enemy_data.gruntCount
	if index + 1 >= ENEMY_GRUNT_MAX_COUNT do return
	enemy_data.gruntCount += 1
	enemy_data.grunts[index] = {}
	enemy_data.grunts[index].spawnPos = pos
	enemy_data.grunts[index].pos = pos
	enemy_data.grunts[index].target = {}
	enemy_data.grunts[index].health = ENEMY_GRUNT_HEALTH * ENEMY_HEALTH_MULTIPLIER
}

// guy with a sword
enemy_spawnKnight :: proc(pos : vec3) {
	index := enemy_data.knightCount
	if index + 1 >= ENEMY_KNIGHT_MAX_COUNT do return
	enemy_data.knightCount += 1
	enemy_data.knights[index] = {}
	enemy_data.knights[index].spawnPos = pos
	enemy_data.knights[index].pos = pos
	enemy_data.knights[index].target = {}
	enemy_data.knights[index].health = ENEMY_KNIGHT_HEALTH * ENEMY_HEALTH_MULTIPLIER
}



_enemy_updateDataAndRender :: proc() {
	assert(enemy_data.gruntCount  >= 0)
	assert(enemy_data.knightCount >= 0)
	assert(enemy_data.gruntCount  < ENEMY_GRUNT_MAX_COUNT)
	assert(enemy_data.knightCount < ENEMY_KNIGHT_MAX_COUNT)


	if !gameIsPaused {
		// update grunts
		for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
			if enemy_data.grunts[i].health <= 0.0 do continue
	
			pos := enemy_data.grunts[i].pos + vec3{0, ENEMY_GRUNT_SIZE.y*0.5, 0}
			dir := linalg.normalize(player_data.pos - pos)
			// cast player
			p_tn, p_hit := phy_boxcastPlayer(pos, dir, {0,0,0})
			EPS :: 0.0
			t_tn, t_norm, t_hit := phy_boxcastTilemap(pos, pos + dir*1e6, {EPS,EPS,EPS})
			seeplayer := p_tn < t_tn && p_hit
	
			if pos.y < -TILE_HEIGHT do enemy_data.knights[i].health = -1.0
	
			// println("p_tn", p_tn, "p_hit", p_hit, "t_tn", t_tn, "t_hit", t_hit)
		
			enemy_data.grunts[i].attackTimer -= deltatime
	
	
			if seeplayer {
				enemy_data.grunts[i].target = player_data.pos
				enemy_data.grunts[i].isMoving = true
			}


			flatdir := linalg.normalize((enemy_data.grunts[i].target - pos) * vec3{1,0,1})

			if p_tn < ENEMY_GRUNT_SIZE.y {
				player_data.vel = flatdir * 50.0
				player_data.slowness = 0.1
			}

			if seeplayer && p_tn < ENEMY_GRUNT_MAX_DIST {
				if enemy_data.grunts[i].attackTimer < 0.0 { // attack
					enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME
					rndstrength := clamp((linalg.length2(player_data.vel)*ENEMY_GRUNT_SPEED_RAND +
						p_tn*ENEMY_GRUNT_DIST_RAND) * 1e-3 * 0.5, 0.0005, 0.04)
					// cast bullet
					bulletdir := linalg.normalize(dir + randVec3()*rndstrength + player_data.vel*deltatime/PLAYER_SPEED)
					bullet_tn, bullet_norm, bullet_hit := phy_boxcastTilemap(pos, pos + bulletdir*1e6, {EPS,EPS,EPS})
					bullet_createBulletLine(pos, pos + bulletdir*bullet_tn, 2.0, vec4{1.0, 0.0, 0.5, 0.9}, 1.0)
					bulletplayer_tn, bulletplayer_hit := phy_boxcastPlayer(pos, bulletdir, {0,0,0})
					if bulletplayer_hit && bulletplayer_tn < bullet_tn { // if the ray actually hit player first
						player_damage(ENEMY_GRUNT_DAMAGE)
						player_data.vel += bulletdir * 40.0
						player_data.rotImpulse += {0.1, 0.0, 0.0}
					}
				}
			} else {
				enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME * 0.5
			}
		
			enemy_data.grunts[i].vel.y -= ENEMY_GRAVITY * deltatime
			speed := linalg.length(enemy_data.grunts[i].vel)
			enemy_data.grunts[i].vel = speed < ENEMY_GRUNT_MAX_SPEED ? enemy_data.grunts[i].vel : (enemy_data.grunts[i].vel/speed)*ENEMY_GRUNT_MAX_SPEED
			speed = max(speed, ENEMY_GRUNT_MAX_SPEED)
			
			mov_tn, mov_norm, mov_hit := phy_boxcastTilemap(pos, pos + enemy_data.grunts[i].vel, ENEMY_GRUNT_SIZE)
			if mov_hit && mov_norm.y > 0.2 { // if on ground
				enemy_data.grunts[i].vel = phy_applyFrictionToVelocity(enemy_data.grunts[i].vel, ENEMY_GRUNT_FRICTION)
	
				if enemy_data.grunts[i].isMoving {
					if !seeplayer {
						enemy_data.grunts[i].vel += flatdir * ENEMY_GRUNT_ACCELERATION * deltatime
					} else {
						if p_tn < ENEMY_GRUNT_MIN_GOOD_DIST {
							enemy_data.grunts[i].vel -= flatdir * ENEMY_GRUNT_ACCELERATION * deltatime
						} else if p_tn > ENEMY_GRUNT_MAX_GOOD_DIST {
							enemy_data.grunts[i].vel += flatdir * ENEMY_GRUNT_ACCELERATION * deltatime
						}
					}
				}

				if speed > 0.01 {
					forwdepth := phy_raycastDepth(pos + flatdir*ENEMY_GRUNT_SIZE.x*1.7)
					if forwdepth > ENEMY_GRUNT_SIZE.y*2 {
						enemy_data.grunts[i].vel = -enemy_data.grunts[i].vel
					}
				}
			}


			if mov_hit {
				enemy_data.grunts[i].vel = phy_clipVelocity(enemy_data.grunts[i].vel, mov_norm, mov_norm.y>0.5 ? 1.0 : 1.5)
				enemy_data.grunts[i].pos += mov_norm*PHY_BOXCAST_EPS*2.0
				enemy_data.grunts[i].vel += mov_norm*deltatime
			}
	
			if speed > 1e-6 {
				enemy_data.grunts[i].pos += (enemy_data.grunts[i].vel/speed) * mov_tn
			}
		}
	
	
	
		// update knights
		for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
			if enemy_data.knights[i].health <= 0.0 do continue
	
			pos := enemy_data.knights[i].pos + vec3{0, ENEMY_KNIGHT_SIZE.y*0.5, 0}
			dir := linalg.normalize(player_data.pos - pos)
			p_tn, p_hit := phy_boxcastPlayer(pos, dir, {0,0,0})
			t_tn, t_norm, t_hit := phy_boxcastTilemap(pos, pos + dir*1e6, {1,1,1})
			seeplayer := p_tn < t_tn && p_hit
	
			if pos.y < -TILE_HEIGHT do enemy_data.knights[i].health = -1.0
	
			// println("p_tn", p_tn, "p_hit", p_hit, "t_tn", t_tn, "t_hit", t_hit)
			
			enemy_data.knights[i].attackTimer -= deltatime
	
	
			if seeplayer {
				enemy_data.knights[i].target = player_data.pos
				enemy_data.knights[i].isMoving = true
			}
	
	
			flatdir := linalg.normalize((enemy_data.knights[i].target - pos) * vec3{1,0,1})
	
			if seeplayer {
				if enemy_data.knights[i].attackTimer < 0.0 && p_tn < ENEMY_KNIGHT_RANGE { // attack
					enemy_data.knights[i].attackTimer = ENEMY_KNIGHT_ATTACK_TIME
					player_damage(ENEMY_KNIGHT_DAMAGE)
					player_data.vel = flatdir * 100.0
					player_data.vel.y += 30.0
					enemy_data.knights[i].vel = -flatdir * ENEMY_KNIGHT_MAX_SPEED * 0.1
				}
			} else {
				enemy_data.knights[i].attackTimer = ENEMY_KNIGHT_ATTACK_TIME * 0.5
			}
		
			enemy_data.knights[i].vel.y -= ENEMY_GRAVITY * deltatime
			speed := linalg.length(enemy_data.knights[i].vel)
			enemy_data.knights[i].vel = speed < ENEMY_KNIGHT_MAX_SPEED ? enemy_data.knights[i].vel : (enemy_data.knights[i].vel/speed)*ENEMY_KNIGHT_MAX_SPEED
			speed = max(speed, ENEMY_KNIGHT_MAX_SPEED)
			
			mov_tn, mov_norm, mov_hit := phy_boxcastTilemap(pos, pos + enemy_data.knights[i].vel, ENEMY_KNIGHT_SIZE)
			if mov_hit && mov_norm.y > 0.2 { // if on ground
				enemy_data.knights[i].vel = phy_applyFrictionToVelocity(enemy_data.knights[i].vel, ENEMY_KNIGHT_FRICTION)
				if enemy_data.knights[i].isMoving {
					enemy_data.knights[i].vel += flatdir * ENEMY_KNIGHT_ACCELERATION * deltatime
				}

				if speed > 0.01 {
					forwdepth := phy_raycastDepth(pos + flatdir*ENEMY_KNIGHT_SIZE.x*1.7)
					if forwdepth > ENEMY_KNIGHT_SIZE.y*2 {
						enemy_data.knights[i].vel = -enemy_data.knights[i].vel*0.5
					}
				}
			}
	
			if mov_hit {
				enemy_data.knights[i].vel = phy_clipVelocity(enemy_data.knights[i].vel, mov_norm, mov_norm.y>0.5 ? 1.0 : 1.5)
			}

	
			if speed > 1e-6 {
				enemy_data.knights[i].pos += (enemy_data.knights[i].vel/speed) * mov_tn
			}
		}
	} // if !gameIsPaused


	// render grunts
	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		if enemy_data.grunts[i].health <= 0.0 do continue
		//rl.DrawCube(enemy_data.grunts[i].pos, ENEMY_GRUNT_SIZE.x*2, ENEMY_GRUNT_SIZE.y*2, ENEMY_GRUNT_SIZE.z*2, rl.PINK)
		rl.DrawModel(enemy_data.gruntModel, enemy_data.grunts[i].pos, 1.0, rl.WHITE)
	}

	// render knights
	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		if enemy_data.knights[i].health <= 0.0 do continue
		rl.DrawCube(enemy_data.knights[i].pos, ENEMY_KNIGHT_SIZE.x*2, ENEMY_KNIGHT_SIZE.y*2, ENEMY_KNIGHT_SIZE.z*2, rl.PINK)
	}



	if settings.debugIsEnabled {
		// render grunt physics AABBS
		for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
			if enemy_data.grunts[i].health <= 0.0 do continue
			rl.DrawCubeWires(enemy_data.grunts[i].pos, ENEMY_GRUNT_SIZE.x*2, ENEMY_GRUNT_SIZE.y*2, ENEMY_GRUNT_SIZE.z*2, rl.GREEN)
		}

		// render knight physics AABBS
		for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
			if enemy_data.knights[i].health <= 0.0 do continue
			rl.DrawCubeWires(enemy_data.knights[i].pos, ENEMY_KNIGHT_SIZE.x*2, ENEMY_KNIGHT_SIZE.y*2, ENEMY_KNIGHT_SIZE.z*2, rl.GREEN)
		}
	}
}






//
// HELPERS PROCEDURES
//

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

loadTexture :: proc(path : string) -> rl.Texture {
	fullpath := appendToAssetPathCstr("textures", path)
	println("! loading texture: ", fullpath)
	return rl.LoadTexture(fullpath)
}

loadSound :: proc(path : string) -> rl.Sound {
	//if !rl.IsAudioDeviceReady() do return {}
	fullpath := appendToAssetPathCstr("audio", path)
	println("! loading sound: ", fullpath)
	return rl.LoadSound(fullpath)
}

loadMusic :: proc(path : string) -> rl.Music {
	//if !rl.IsAudioDeviceReady() do return {}
	fullpath := appendToAssetPathCstr("audio", path)
	println("! loading music: ", fullpath)
	return rl.LoadMusicStream(fullpath)
}

loadFont :: proc(path : string) -> rl.Font {
	fullpath := appendToAssetPathCstr("fonts", path)
	println("! loading font: ", fullpath)
	return rl.LoadFontEx(fullpath, 32, nil, 0)
	//return rl.LoadFont(fullpath)
}

loadModel :: proc(path : string) -> rl.Model {
	fullpath := appendToAssetPathCstr("models", path)
	println("! loading model: ", fullpath)
	return rl.LoadModel(fullpath)
}

loadShader :: proc(vertpath : string, fragpath : string) -> rl.Shader {
	vertfullpath := appendToAssetPathCstr("shaders", vertpath)
	fragfullpath := appendToAssetPathCstr("shaders", fragpath)
	println("! loading shader: vert: ", vertfullpath, "frag:", fragfullpath)
	return rl.LoadShader(vertfullpath, fragfullpath)
}

// uses default vertex shader
loadFragShader :: proc(path : string) -> rl.Shader {
	fullpath := appendToAssetPathCstr("shaders", path)
	println("! loading shader: ", fullpath)
	return rl.LoadShader(nil, fullpath)
}



playSound :: proc(sound : rl.Sound) {
	if !rl.IsAudioDeviceReady() do return
	rl.PlaySound(sound)
}

playSoundMulti :: proc(sound : rl.Sound) {
	if !rl.IsAudioDeviceReady() do return
	rl.PlaySoundMulti(sound)
}

// rand vector with elements in -1..1
randVec3 :: proc() -> vec3 {
	return vec3{
		rand.float32_range(-1.0, 1.0, &randData),
		rand.float32_range(-1.0, 1.0, &randData),
		rand.float32_range(-1.0, 1.0, &randData),
	}
}





//
// SERIALIZATION/DESERIALIZATION
//

SERI_ATTRIB_SEPARATOR :: ":"

seri_attribMatch :: proc(buf : []u8, index : ^i32, name : string) -> bool {
	//println("buf", buf, "index", index^, "name", name)
	endindex : i32 = cast(i32)strings.index_byte(string(buf[index^:]), ':') + 1
	if endindex <= 0 do return false
	src : string = string(buf[index^:index^ + endindex])
	checkstr := fmt.tprint(args={name, SERI_ATTRIB_SEPARATOR}, sep="")
	val := strings.compare(src, checkstr)
	res := val == 0
	if res {
		index^ += cast(i32)len(name) + 1
		seri_skipWhitespace(buf, index)
	}
	return res
}

seri_skipWhitespace :: proc(buf : []u8, index : ^i32) -> bool {
	skipped := false
	for strings.is_space(cast(rune)buf[index^]) || buf[index^]=='\n' || buf[index^]=='\r' {
		index^ += 1
		skipped = true
	}
	return skipped
}

seri_readF32 :: proc(buf : []u8, index : ^i32) -> f32 {
	seri_skipWhitespace(buf, index)
	str := string(buf[index^:])
	val, ok := strconv.parse_f32(str)
	_ = ok
	seri_skipToNextWhitespace(buf, index)
	return val
}

seri_readI32 :: proc(buf : []u8, index : ^i32) -> i32 {
	seri_skipWhitespace(buf, index)
	str := string(buf[index^:])
	val, ok := strconv.parse_int(str)
	_ = ok
	seri_skipToNextWhitespace(buf, index)
	return cast(i32)val
}

seri_readBool :: proc(buf : []u8, index : ^i32) -> bool {
	seri_skipWhitespace(buf, index)
	str := string(buf[index^:])
	res := strings.has_prefix(str, "true")
	seri_skipToNextWhitespace(buf, index)
	return res
}

// reads string in between "
seri_readString :: proc(buf : []u8, index : ^i32) -> string {
	seri_skipWhitespace(buf, index)
	if buf[index^] != '\"' do return ""
	startindex := index^ + 1
	endindex := startindex + cast(i32)strings.index_byte(string(buf[startindex:]), '\"')
	index^ = endindex + 1
	res := string(buf[startindex:endindex])
	println("startindex", startindex, "endindex", endindex, "res", res)
	return res
}

seri_skipToNextWhitespace :: proc(buf : []u8, index : ^i32) {
	for !strings.is_space(cast(rune)buf[index^]) && buf[index^]!='\n' && buf[index^]!='\r' {
		index^ += 1
		println("skip to next line")
	}
	index^ += 1
}