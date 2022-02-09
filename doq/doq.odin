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
import rl "vendor:raylib"



println :: fmt.println
vec2 :: rl.Vector2
vec3 :: rl.Vector3
vec4 :: rl.Vector4
ivec2 :: [2]i32
ivec3 :: [3]i32
mat3 :: linalg.Matrix3f32



WINDOW_X :: 1440
WINDOW_Y :: 810

debugIsEnabled : bool = false

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

gameIsPaused : bool = false
gameDrawFPS	: bool = false

screenTint : vec3 = {1,1,1}

app_updatePathKind : enum {
	LOADSCREEN = 0,
	MAIN_MENU,
	GAME,
} = .LOADSCREEN

audioMasterVolume : f32 = 1.0


// this just gets called from main
_doq_main :: proc() {
	_app_init()

	for !rl.WindowShouldClose() && !app_shouldExitNextFrame {
		println("### frame =", framespassed, "deltatime =", deltatime)
		framespassed += 1
		
		audioMasterVolume = clamp(audioMasterVolume, 0.0, 1.0)
		rl.SetMasterVolume(audioMasterVolume)

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
				rl.DisableCursor()

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
						_gun_update()
						_player_update()
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
					_app_render2d()
				rl.EndDrawing()
			}
		}

		deltatime = rl.GetFrameTime()
		timepassed += deltatime // not really accurate but whatever
	}

	rl.CloseWindow()
	rl.CloseAudioDevice()
}




//
// APP
//

_app_init :: proc() {
	rl.InitWindow(WINDOW_X, WINDOW_Y, "Dungeon of Quake")
	rl.SetWindowState({
		rl.ConfigFlag.WINDOW_TOPMOST,
		rl.ConfigFlag.WINDOW_HIGHDPI,
		rl.ConfigFlag.WINDOW_HIGHDPI,
		rl.ConfigFlag.VSYNC_HINT,
	})
	rl.InitAudioDevice()
	

	rl.SetTargetFPS(75)
	loadpath = filepath.clean(string(rl.GetWorkingDirectory()))
	println("loadpath", loadpath)

	rl.SetExitKey(rl.KeyboardKey.NULL)

	renderTextureMain	= rl.LoadRenderTexture(WINDOW_X, WINDOW_Y)

	gui_data.loadScreenLogo	= loadTexture("dungeon_of_quake_logo.png")
	rl.SetTextureFilter(gui_data.loadScreenLogo, rl.TextureFilter.TRILINEAR)

	postprocessShader	= loadFragShader("postprocess.frag")
	map_data.tileShader	= loadShader("tile.vert", "tile.frag")
	map_data.portalShader	= loadShader("portal.vert", "portal.frag")
	map_data.tileShaderCamPosUniformIndex = cast(rl.ShaderLocationIndex)rl.GetShaderLocation(map_data.tileShader, "camPos")
	bullet_data.bulletLineShader = loadShader("bulletLine.vert", "bulletLine.frag")



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
	rl.SetSoundVolume(gun_data.headshotSound, 0.85)
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

	map_data.tileModel = rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
	map_data.tileModel.materials[0].shader = map_data.tileShader
	rl.SetMaterialTexture(&map_data.tileModel.materials[0], rl.MaterialMapIndex.DIFFUSE, map_data.wallTexture)
	map_data.elevatorModel = loadModel("elevator.glb")
	map_data.elevatorModel.materials[0].shader = map_data.tileShader
	rl.SetMaterialTexture(&map_data.elevatorModel.materials[0], rl.MaterialMapIndex.DIFFUSE, map_data.elevatorTexture)
	map_data.healthPickupModel = loadModel("healthpickup.glb")

	enemy_data.gruntHitSound	= loadSound("death2.wav")
	enemy_data.gruntDeathSound	= enemy_data.gruntHitSound
	enemy_data.knightHitSound	= enemy_data.gruntHitSound
	enemy_data.knightDeathSound	= enemy_data.gruntHitSound
	enemy_data.gruntModel		= loadModel("grunt.glb")
	enemy_data.knightModel		= enemy_data.gruntModel


	camera.position = {0, 3, 0}
	camera.target = {}
	camera.up = vec3{0.0, 1.0, 0.0}
	camera.fovy = PLAYER_FOV
	camera.projection = rl.CameraProjection.PERSPECTIVE
	rl.SetCameraMode(camera, rl.CameraMode.CUSTOM)

	viewmodelCamera.position = {0,0,0}
	viewmodelCamera.target = {0,0,1}
	viewmodelCamera.up = {0,1,0}
	viewmodelCamera.fovy = PLAYER_VIEWMODEL_FOV
	viewmodelCamera.projection = rl.CameraProjection.PERSPECTIVE
	rl.SetCameraMode(viewmodelCamera, rl.CameraMode.CUSTOM)

	//normalFont = loadFont("metalord.ttf")
	gui_data.titleFont	= loadFont("eurcntrc.ttf")
	gui_data.normalFont	= loadFont("germania_one.ttf")
	gui_data.selectSound	= loadSound("button.wav")
	gui_data.setValSound	= loadSound("elevator_end0.wav")
	gui_data.loadScreenMusic	= loadMusic("ambient0.wav")

	rand.init(&randData, cast(u64)time.now()._nsec)
	
	map_clearAll()
	map_data.bounds = {MAP_MAX_WIDTH, MAP_MAX_WIDTH}
	if os.is_file(appendToAssetPath("maps", "_quickload.doqm")) {
		map_loadFromFile("_quickload.doqm")
		// app_updatePathKind = .GAME
	} else {

	}
	//map_debugPrint()

	player_startMap()

}

_app_update :: proc() {
	//rl.UpdateMusicStream(map_data.backgroundMusic)
	//rl.UpdateMusicStream(map_data.ambientMusic)
	//rl.SetMusicVolume(player_data.swooshMusic, clamp(linalg.length(player_data.vel * 0.05), 0.0, 1.0))

	if rl.IsKeyPressed(rl.KeyboardKey.RIGHT_ALT) do debugIsEnabled = !debugIsEnabled
	
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

	screenTint = linalg.lerp(screenTint, vec3{1, 1, 1}, clamp(deltatime * 2.0, 0.0, 1.0))
}

_app_render2d :: proc() {
	// crosshair
	//rl.DrawRectangle(WINDOW_X/2 - 3, WINDOW_Y/2 - 3, 6, 6, rl.Fade(rl.BLACK, 0.5))
	//rl.DrawRectangle(WINDOW_X/2 - 2, WINDOW_Y/2 - 2, 4, 4, rl.Fade(rl.WHITE, 0.5))

	gunindex := cast(i32)gun_data.equipped

	// draw ammo
	gui_drawText({WINDOW_X - 150, WINDOW_Y - 50},	30, rl.Color{255,200, 50,255}, fmt.tprint("ammo: ", gun_data.ammoCounts[gunindex]))
	gui_drawText({30, WINDOW_Y - 50},		30, rl.Color{255, 80, 80,255}, fmt.tprint("health: ", player_data.health))

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


	menu_drawDebugUI()
}

_app_render3d :: proc() {
	when false {
		if debugIsEnabled {
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
		map_data.skyColor.r*1.1,
		map_data.skyColor.g*1.1,
		map_data.skyColor.b*1.1,
		map_data.fogStrength,
	}
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






world_reset :: proc() {
	player_initData()

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
	tn, hit, enemykind, enemyindex := phy_boxCastWorld(start, start + dir*1e6, vec3{rad,rad,rad})
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

ENEMY_GRUNT_MAX_COUNT	:: 32
ENEMY_KNIGHT_MAX_COUNT	:: 32

ENEMY_HEALTH_MULTIPLIER		:: 1.5
ENEMY_HEADSHOT_HALF_OFFSET	:: 0.0
ENEMY_GRAVITY			:: 5.0

ENEMY_GRUNT_SIZE		:: vec3{2, 4, 2}
ENEMY_GRUNT_ACCELERATION	:: 13
ENEMY_GRUNT_MAX_SPEED		:: 14
ENEMY_GRUNT_FRICTION		:: 5
ENEMY_GRUNT_MIN_GOOD_DIST	:: 30
ENEMY_GRUNT_MAX_GOOD_DIST	:: 60
ENEMY_GRUNT_ATTACK_TIME		:: 1.5
ENEMY_GRUNT_DAMAGE		:: 1.0
ENEMY_GRUNT_HEALTH		:: 1.0
ENEMY_GRUNT_SPEED_RAND		:: 0.005 // NOTE: multiplier for length(player velocity) ^ 2
ENEMY_GRUNT_DIST_RAND		:: 0.5
ENEMY_GRUNT_MAX_DIST		:: 120.0

ENEMY_KNIGHT_SIZE		:: vec3{1.5, 3, 1.5}
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
	enemy_data.grunts[index].target = pos
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
	enemy_data.knights[index].target = pos
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
			p_tn, p_hit := phy_boxCastPlayer(pos, dir, {0,0,0})
			EPS :: 0.0
			t_tn, t_norm, t_hit := phy_boxCastTilemap(pos, pos + dir*1e6, {EPS,EPS,EPS})
			seeplayer := p_tn < t_tn && p_hit
	
			if pos.y < -TILE_HEIGHT do enemy_data.knights[i].health = -1.0
	
			// println("p_tn", p_tn, "p_hit", p_hit, "t_tn", t_tn, "t_hit", t_hit)
		
			enemy_data.grunts[i].attackTimer -= deltatime
	
	
			if seeplayer {
				enemy_data.grunts[i].target = player_data.pos
				enemy_data.grunts[i].isMoving = true
			}
	
	
			flatdir := linalg.normalize((enemy_data.grunts[i].target - pos) * vec3{1,0,1})
	
			if seeplayer && p_tn < ENEMY_GRUNT_MAX_DIST {
				if enemy_data.grunts[i].attackTimer < 0.0 { // attack
					enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME
					rndstrength := (linalg.length2(player_data.vel)*ENEMY_GRUNT_SPEED_RAND +
						p_tn*ENEMY_GRUNT_DIST_RAND) * 1e-3 * 0.5
					// cast bullet
					bulletdir := linalg.normalize(dir + randVec3()*rndstrength + player_data.vel*deltatime/PLAYER_SPEED)
					bullet_tn, bullet_norm, bullet_hit := phy_boxCastTilemap(pos, pos + bulletdir*1e6, {EPS,EPS,EPS})
					bullet_createBulletLine(pos, pos + bulletdir*bullet_tn, 2.0, vec4{1.0, 0.0, 0.5, 0.9}, 1.0)
					bulletplayer_tn, bulletplayer_hit := phy_boxCastPlayer(pos, bulletdir, {0,0,0})
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
			
			mov_tn, mov_norm, mov_hit := phy_boxCastTilemap(pos, pos + enemy_data.grunts[i].vel, ENEMY_GRUNT_SIZE)
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
			p_tn, p_hit := phy_boxCastPlayer(pos, dir, {0,0,0})
			t_tn, t_norm, t_hit := phy_boxCastTilemap(pos, pos + dir*1e6, {1,1,1})
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
			
			mov_tn, mov_norm, mov_hit := phy_boxCastTilemap(pos, pos + enemy_data.knights[i].vel, ENEMY_KNIGHT_SIZE)
			if mov_hit && mov_norm.y > 0.2 { // if on ground
				enemy_data.knights[i].vel = phy_applyFrictionToVelocity(enemy_data.knights[i].vel, ENEMY_KNIGHT_FRICTION)
				if enemy_data.knights[i].isMoving {
					enemy_data.knights[i].vel += flatdir * ENEMY_KNIGHT_ACCELERATION * deltatime
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



	if debugIsEnabled {
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