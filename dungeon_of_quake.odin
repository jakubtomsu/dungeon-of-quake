package dungeon_of_quake

// 'Dungeon of Quake' is a simple first person shooter, heavily inspired by the Quake franchise
// using raylib


import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/rand"
import "core:fmt"
import "core:time"
//RAYLIB_USE_LINALG :: true
import rl "vendor:raylib"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:strconv"
//import win32 "core:sys/win32"




println :: fmt.println
vec2 :: rl.Vector2
vec3 :: rl.Vector3
vec4 :: rl.Vector4
ivec2 :: [2]i32
ivec3 :: [3]i32
mat3 :: linalg.Matrix3f32



WINDOW_X :: 1440
WINDOW_Y :: 810

debugIsEnabled : bool = true

camera: rl.Camera = {}
viewmodelCamera: rl.Camera = {}

framespassed : i64 = 0
deltatime : f32 = 0.01
timepassed : f32 = 0.0
app_shouldExitNextFrame : bool = false
loadpath : string

rendertextureMain : rl.RenderTexture2D
postprocessShader : rl.Shader
randData : rand.Rand

normalFont : rl.Font

gameIsPlaying : bool
gameIsRendered : bool
screenTint : vec3 = {1,1,1}




//
// MAIN
//

main :: proc() {
	_app_init()

	for !rl.WindowShouldClose() && !app_shouldExitNextFrame {
		println("frame =", framespassed, "deltatime =", deltatime)
		framespassed += 1

		rl.UpdateCamera(&camera)
		rl.UpdateCamera(&viewmodelCamera)
		rl.DisableCursor()

		_app_update()

		rl.BeginTextureMode(rendertextureMain)
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
			rl.BeginShaderMode(postprocessShader)
				rl.DrawTextureRec(
					rendertextureMain.texture,
					rl.Rectangle{0, 0, cast(f32)rendertextureMain.texture.width,
						-cast(f32)rendertextureMain.texture.height},
					{0, 0},
					rl.ColorFromNormalized(vec4{screenTint.r, screenTint.g, screenTint.b, 1.0}),
				)
			rl.EndShaderMode()
			_app_render2d()
		rl.EndDrawing()


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

	rendertextureMain	= rl.LoadRenderTexture(WINDOW_X, WINDOW_Y)
	postprocessShader	= loadFragShader("postprocess.frag")
	map_data.tileShader	= loadShader("tile.vert", "tile.frag")
	map_data.portalShader	= loadShader("portal.vert", "portal.frag")
	map_data.tileShaderCamPosUniformIndex = cast(rl.ShaderLocationIndex)rl.GetShaderLocation(map_data.tileShader, "camPos")
	bullet_data.linearEffectShader = loadShader("bulletLinearEffect.vert", "bulletLinearEffect.frag")


	map_data.wallTexture			= loadTexture("tile0.png")
	map_data.portalTexture			= loadTexture("portal.png")
	map_data.elevatorTexture		= loadTexture("metal.png")
	map_data.healthPickupTexture	= loadTexture("box.png")

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
    player_data.healthPickupSound   = loadSound("heal.wav")
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

	enemy_data.gruntHitSound	= loadSound("death2.wav")
	enemy_data.gruntDeathSound	= enemy_data.gruntHitSound
	enemy_data.knightHitSound	= enemy_data.gruntHitSound
	enemy_data.knightDeathSound	= enemy_data.gruntHitSound



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

	normalFont = loadFont("metalord.ttf")

	rand.init(&randData, cast(u64)time.now()._nsec)
	
	map_clearAll()
	map_data.bounds = {MAP_MAX_WIDTH, MAP_MAX_WIDTH}
	if os.is_file(appendToAssetPath("maps", "_quickload.doqm")) {
		map_loadFromFile("_quickload.doqm")
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

_debugtext_y : i32 = 0
_app_render2d :: proc() {
	_debugtext_y = 2

	// cursor
	//rl.DrawRectangle(WINDOW_X/2 - 3, WINDOW_Y/2 - 3, 6, 6, rl.Fade(rl.BLACK, 0.5))
	//rl.DrawRectangle(WINDOW_X/2 - 2, WINDOW_Y/2 - 2, 4, 4, rl.Fade(rl.WHITE, 0.5))

	gunindex := cast(i32)gun_data.equipped

	// draw ammo
	ui_drawText({WINDOW_X - 150, WINDOW_Y - 50},	30, rl.Color{255,200, 50,255}, fmt.tprint("ammo: ", gun_data.ammoCounts[gunindex]))
	ui_drawText({30, WINDOW_Y - 50},		30, rl.Color{255, 80, 80,255}, fmt.tprint("health: ", player_data.health))

	for i : i32 = 0; i < GUN_COUNT; i += 1 {
		LINE :: 40
		TEXTHEIGHT :: LINE*0.5
		pos := vec2{WINDOW_X - 120, WINDOW_Y*0.5 + GUN_COUNT*LINE*0.5 - cast(f32)i*LINE}
		if i == cast(i32)gun_data.equipped {
			W :: 8
			rl.DrawRectangle(cast(i32)pos.x-W, cast(i32)pos.y-W, 120, TEXTHEIGHT+W*2, {150,150,150,100})
		}

		ui_drawText(pos, TEXTHEIGHT, gun_data.ammoCounts[i] == 0 ? {255,255,255,100} : rl.WHITE, fmt.tprint(cast(gun_kind_t)i))
	}

	if debugIsEnabled {
		rl.DrawFPS(0, 0)
		debugtext :: proc(args : ..any) {
			tstr := fmt.tprint(args=args)
			cstr := strings.clone_to_cstring(tstr, context.temp_allocator)
			rl.DrawText(cstr, 6, _debugtext_y * 12, 10, rl.Fade(rl.WHITE, 0.8))
			_debugtext_y += 1
		}

		debugtext("player")
		debugtext("    pos", player_data.pos)
		debugtext("    vel", player_data.vel)
		debugtext("    onground", player_data.isOnGround)
		debugtext("system")
		debugtext("    IsAudioDeviceReady", rl.IsAudioDeviceReady())
		debugtext("    loadpath", loadpath)
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
		debugtext("    linear effect count", bullet_data.linearEffectsCount)
		debugtext("enemies")
		debugtext("    grunt count", enemy_data.gruntCount)
		debugtext("    knight count", enemy_data.knightCount)
	}
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
// MAP
//

MAP_MAX_WIDTH	:: 128
TILE_WIDTH		:: 30.0
TILE_MIN_HEIGHT		:: TILE_WIDTH
TILEMAP_Y_TILES		:: 7
TILE_HEIGHT		:: TILE_WIDTH * TILEMAP_Y_TILES
TILEMAP_MID		:: 4

TILE_ELEVATOR_MOVE_FACTOR	:: 0.55
TILE_ELEVATOR_Y0		:: cast(f32)-4.5*TILE_WIDTH + 2.0
TILE_ELEVATOR_Y1		:: cast(f32)-1.5*TILE_WIDTH - 2.0
TILE_ELEVATOR_SPEED		:: (TILE_ELEVATOR_Y1 - TILE_ELEVATOR_Y0) * TILE_ELEVATOR_MOVE_FACTOR

MAP_GUN_PICKUP_MAX_COUNT	:: 32
MAP_HEALTH_PICKUP_MAX_COUNT	:: 32
MAP_HEALTH_PICKUP_SIZE :: vec3{2,1.5,2}

MAP_TILE_FINISH_SIZE :: vec3{8, 16, 8}

// 'translated' tiles are changed into different tiles when a map gets loaded
map_tileKind_t :: enum u8 {
	NONE			= '-',
	EMPTY			= ' ',
	FULL			= '#',
	WALL_MID		= 'w',
	CEILING			= 'c',
	START_LOWER		= 's', // translated
	START_UPPER		= 'S', // translated
	FINISH_LOWER		= 'f', // translated
	FINISH_UPPER		= 'F', // translated
	PLATFORM_SMALL		= 'p',
	PLATFORM_LARGE		= 'P',
	ELEVATOR		= 'e',
	OBSTACLE_LOWER		= 'o',
	OBSTACLE_UPPER		= 'O',

	PICKUP_HEALTH_LOWER	= 'h', // translated
	PICKUP_HEALTH_UPPER	= 'H', // translated

	GUN_SHOTGUN_LOWER	= 'd', // translated // as default
	GUN_SHOTGUN_UPPER	= 'D', // translated
	GUN_MACHINEGUN_LOWER	= 'm', // translated
	GUN_MACHINEGUN_UPPER	= 'M', // translated
	GUN_LASERRIFLE_LOWER	= 'l', // translated
	GUN_LASERRIFLE_UPPER	= 'L', // translated

	ENEMY_KNIGHT_LOWER	= 'k', // translated
	ENEMY_KNIGHT_UPPER	= 'K', // translated
	ENEMY_GRUNT_LOWER	= 'g', // translated
	ENEMY_GRUNT_UPPER	= 'G', // translated
}

map_data : struct {
	mapName		: string,
	nextMapName	: string,
	authorName	: string, // TODO
	startMessage	: string, // TODO
	startPlayerDir	: vec2,
	skyColor		: vec3,
	fogStrength		: f32,

	tiles		: [MAP_MAX_WIDTH][MAP_MAX_WIDTH]map_tileKind_t,
	bounds		: ivec2,
	startPos	: vec3,
	finishPos	: vec3,

	elevatorHeights		: map[[2]u8]f32,

	gunPickupCount		: i32,
	gunPickupSpawnCount	: i32,
	gunPickups		: [MAP_GUN_PICKUP_MAX_COUNT]struct {
		pos	: vec3,
		kind	: gun_kind_t,
	},

	healthPickupCount	: i32,
	healthPickupSpawnCount	: i32,
	healthPickups		: [MAP_HEALTH_PICKUP_MAX_COUNT]vec3,

	tileShader			: rl.Shader,
	tileShaderCamPosUniformIndex	: rl.ShaderLocationIndex,
	portalShader			: rl.Shader,

	wallTexture		: rl.Texture2D,
	portalTexture		: rl.Texture2D,
	elevatorTexture		: rl.Texture2D,
	healthPickupTexture	: rl.Texture2D,
	backgroundMusic		: rl.Music,
	ambientMusic		: rl.Music,
	elevatorSound		: rl.Sound,
	elevatorEndSound	: rl.Sound,

	tileModel	: rl.Model,
	elevatorModel	: rl.Model,
}



// @returns: 2d tile position from 3d worldspace 'p'
map_worldToTile :: proc(p : vec3) -> ivec2 {
	return ivec2{cast(i32)((p.x / TILE_WIDTH)), cast(i32)((p.z / TILE_WIDTH))}
}

// @returns: tile center position in worldspace
map_tileToWorld :: proc(p : ivec2) -> vec3 {
	return vec3{((cast(f32)p.x) + 0.5) * TILE_WIDTH, 0.0, ((cast(f32)p.y) + 0.5) * TILE_WIDTH}
}

map_isTilePosInBufferBounds :: proc(coord : ivec2) -> bool {
	return coord.x >= 0 && coord.y >= 0 && coord.x < MAP_MAX_WIDTH && coord.y < MAP_MAX_WIDTH
}

map_isTilePosValid :: proc(coord : ivec2) -> bool {
	return map_isTilePosInBufferBounds(coord) && coord.x <= map_data.bounds.x && coord.y <= map_data.bounds.y
}

map_tilePosClamp :: proc(coord : ivec2) -> ivec2 {
	return ivec2{clamp(coord.x, 0, map_data.bounds.x), clamp(coord.y, 0, map_data.bounds.y)}
}



map_addGunPickup :: proc(pos : vec3, kind : gun_kind_t) {
	if map_data.gunPickupCount + 1 >= MAP_GUN_PICKUP_MAX_COUNT do return
	map_data.gunPickups[map_data.gunPickupCount].pos  = pos
	map_data.gunPickups[map_data.gunPickupCount].kind = kind
	map_data.gunPickupCount += 1
	map_data.gunPickupSpawnCount = map_data.gunPickupCount
}

map_addHealthPickup :: proc(pos : vec3) {
	if map_data.healthPickupCount + 1 >= MAP_HEALTH_PICKUP_MAX_COUNT do return
	map_data.healthPickups[map_data.healthPickupCount] = pos
	map_data.healthPickupCount += 1
	map_data.healthPickupSpawnCount = map_data.healthPickupCount
}




// fills input buffer with axis-aligned boxes for a given tile
// @returns: number of boxes for the tile
map_getTileBoxes :: proc(coord : ivec2, boxbuf : []phy_box_t) -> i32 {
	tileKind := map_data.tiles[coord[0]][coord[1]]

	phy_calcBox :: proc(posxz : vec2, posy : f32, sizey : f32) -> phy_box_t {
		return phy_box_t{
			vec3{posxz.x, posy*TILE_WIDTH, posxz.y},
			vec3{TILE_WIDTH, sizey * TILE_WIDTH, TILE_WIDTH} / 2,
		}
	}

	posxz := vec2{cast(f32)coord[0]+0.5, cast(f32)coord[1]+0.5}*TILE_WIDTH

	#partial switch tileKind {
		case map_tileKind_t.NONE:
			return 0

		case map_tileKind_t.FULL:
			boxbuf[0] = phy_box_t{vec3{posxz[0], 0.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_HEIGHT/2, TILE_WIDTH/2}}
			return 1

		case map_tileKind_t.EMPTY:
			boxsize := vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			return 2

		case map_tileKind_t.WALL_MID:
			boxbuf[0] = phy_calcBox(posxz, -2, 5)
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0}
			return 2

		case map_tileKind_t.PLATFORM_SMALL:
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[2] = phy_calcBox(posxz, 0, 1)
			return 3
        case map_tileKind_t.PLATFORM_LARGE:
            boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[2] = phy_calcBox(posxz, 0, 3)
			return 3

		case map_tileKind_t.CEILING:
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[1] = phy_calcBox(posxz, 2, 5)
			return 2

		case map_tileKind_t.ELEVATOR: // the actual moving elevator box is at index 0
			boxsize := vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			height, ok := map_data.elevatorHeights[{cast(u8)coord.x, cast(u8)coord.y}]
			if !ok do height = 0.0
			boxbuf[0] = {
                vec3{posxz[0], math.lerp(TILE_ELEVATOR_Y0, TILE_ELEVATOR_Y1, height), posxz[1]},
                vec3{TILE_WIDTH, TILE_WIDTH*TILEMAP_MID, TILE_WIDTH}/2,
            }
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			return 2

        case map_tileKind_t.OBSTACLE_LOWER:
			boxbuf[0] = phy_calcBox(posxz, -3, 3)
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0}
			return 2
        case map_tileKind_t.OBSTACLE_UPPER:
			boxbuf[0] = phy_calcBox(posxz, -1, 5)
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0}
			return 2
		
	}

	return 0
}



map_clearAll :: proc() {
	map_data.bounds[0] = 0
	map_data.bounds[1] = 0
	map_data.mapName = "_cleared_map"
	map_data.nextMapName = ""
	map_data.skyColor = {0.6, 0.5, 0.8} * 0.6
	map_data.fogStrength = 2.0

	delete(map_data.elevatorHeights)

	for x : u32 = 0; x < MAP_MAX_WIDTH; x += 1 {
		for y : u32 = 0; y < MAP_MAX_WIDTH; y += 1 {
			map_data.tiles[x][y] = map_tileKind_t.NONE
		}
	}
}

map_loadFromFile :: proc(name: string) {
	fullpath := appendToAssetPath("maps", name)
	println("! loading map: ", fullpath)
	data, success := os.read_entire_file_from_filename(fullpath)

	if !success {
		//app_shouldExitNextFrame = true
		println("! error: map file not found!")
		return
	}

	defer free(&data[0])

	map_clearAll()

	map_data.elevatorHeights = make(type_of(map_data.elevatorHeights))


	index : i32 = 0
	x : i32 = 0
	y : i32 = 0
	dataloop : for index < cast(i32)len(data) {
		ch : u8 = data[index]
		index += 1

		switch ch {
			case '\x00':
				println("null")
				return
			case '\n':
				println("\\n")
				y += 1
				map_data.bounds[0] = max(map_data.bounds[0], x)
				map_data.bounds[1] = max(map_data.bounds[1], y)
				x = 0
				continue dataloop
			case '\r':
				println("\\r")
				continue dataloop
			case '{':
				println("attributes")
				for data[index] != '}' {
					if !skipWhitespace(data, &index) do index += 1
					println("index", index, "ch", cast(rune)data[index])
					if attribMatch(data, &index, "test")		do println("test detected, ch", cast(rune)data[index], "val", readF32(data, &index))
					if attribMatch(data, &index, "test1")		do println("test1 detected, ch", cast(rune)data[index], "val", readF32(data, &index))
					if attribMatch(data, &index, "test3")		do println("test3 detected, ch", cast(rune)data[index], "val", readString(data, &index))
					if attribMatch(data, &index, "test4")		do println("test4 detected, ch", cast(rune)data[index], "val", readI32(data, &index))
					if attribMatch(data, &index, "mapName")		do map_data.mapName = readString(data, &index)
					if attribMatch(data, &index, "nextMapName")	do map_data.nextMapName = readString(data, &index)
					
					if attribMatch(data, &index, "startPlayerDir") {
						map_data.startPlayerDir.x = readF32(data, &index)
						map_data.startPlayerDir.y = readF32(data, &index)
						map_data.startPlayerDir = linalg.normalize(map_data.startPlayerDir)
					}
					
					if attribMatch(data, &index, "skyColor") {
						map_data.skyColor.r = readF32(data, &index)
						map_data.skyColor.g = readF32(data, &index)
						map_data.skyColor.b = readF32(data, &index)
					}
					
					if attribMatch(data, &index, "fogStrength")	do map_data.fogStrength = readF32(data, &index)
				}
		}

		tile := cast(map_tileKind_t)ch
		
		if map_isTilePosInBufferBounds({x, y}) {
			//println("pre ", tile)
			lowpos :=  map_tileToWorld({x, y}) - vec3{0, TILE_WIDTH*TILEMAP_Y_TILES/2 - TILE_WIDTH, 0}
			highpos := map_tileToWorld({x, y}) + vec3{0, TILE_WIDTH*0.5, 0}
		
			// tile translation
			#partial switch tile {
				case map_tileKind_t.START_LOWER:
					map_data.startPos = lowpos + vec3{0, PLAYER_SIZE.y*2, 0}
					tile = map_tileKind_t.EMPTY
				case map_tileKind_t.START_UPPER:
					map_data.startPos = highpos + vec3{0, PLAYER_SIZE.y*2, 0}
					tile = map_tileKind_t.WALL_MID

				case map_tileKind_t.FINISH_LOWER:
					map_data.finishPos = lowpos + vec3{0, MAP_TILE_FINISH_SIZE.y, 0}
					tile = map_tileKind_t.EMPTY
				case map_tileKind_t.FINISH_UPPER:
					map_data.finishPos = highpos + vec3{0, MAP_TILE_FINISH_SIZE.y, 0}
					tile = map_tileKind_t.WALL_MID

				case map_tileKind_t.ELEVATOR: map_data.elevatorHeights[{cast(u8)x, cast(u8)y}] = 0.0

				case map_tileKind_t.ENEMY_GRUNT_LOWER:
					enemy_spawnGrunt(lowpos + vec3{0, ENEMY_GRUNT_SIZE.y*1.2, 0})
					tile = map_tileKind_t.EMPTY
				case map_tileKind_t.ENEMY_GRUNT_UPPER:
					enemy_spawnGrunt(highpos + vec3{0, ENEMY_GRUNT_SIZE.y*1.2, 0})
					tile = map_tileKind_t.WALL_MID

				case map_tileKind_t.ENEMY_KNIGHT_LOWER:
					enemy_spawnKnight(lowpos + vec3{0, ENEMY_KNIGHT_SIZE.y*1.2, 0})
					tile = map_tileKind_t.EMPTY
				case map_tileKind_t.ENEMY_KNIGHT_UPPER:
					enemy_spawnKnight(highpos + vec3{0, ENEMY_KNIGHT_SIZE.y*1.2, 0})
					tile = map_tileKind_t.WALL_MID

				case map_tileKind_t.GUN_SHOTGUN_LOWER:
					map_addGunPickup(lowpos + vec3{0, PLAYER_SIZE.y, 0}, .SHOTGUN)
					tile = map_tileKind_t.EMPTY
				case map_tileKind_t.GUN_SHOTGUN_UPPER:
					map_addGunPickup(highpos + vec3{0, PLAYER_SIZE.y, 0}, .SHOTGUN)
					tile = map_tileKind_t.WALL_MID

				case map_tileKind_t.GUN_MACHINEGUN_LOWER:
					map_addGunPickup(lowpos + vec3{0, PLAYER_SIZE.y, 0}, .MACHINEGUN)
					tile = map_tileKind_t.EMPTY
				case map_tileKind_t.GUN_MACHINEGUN_UPPER:
					map_addGunPickup(highpos + vec3{0, PLAYER_SIZE.y, 0}, .MACHINEGUN)
					tile = map_tileKind_t.WALL_MID

				case map_tileKind_t.GUN_LASERRIFLE_LOWER:
					map_addGunPickup(lowpos + vec3{0, PLAYER_SIZE.y, 0}, .LASERRIFLE)
					tile = map_tileKind_t.EMPTY
				case map_tileKind_t.GUN_LASERRIFLE_UPPER:
					map_addGunPickup(highpos + vec3{0, PLAYER_SIZE.y, 0}, .LASERRIFLE)
					tile = map_tileKind_t.WALL_MID
                    
                case map_tileKind_t.PICKUP_HEALTH_LOWER:
                    rnd := vec2{
                        rand.float32_range(-1.0, 1.0, &randData),
                        rand.float32_range(-1.0, 1.0, &randData),
                    } * TILE_WIDTH * 0.3
					map_addHealthPickup(lowpos + vec3{rnd.x, MAP_HEALTH_PICKUP_SIZE.y, rnd.y})
					tile = map_tileKind_t.EMPTY
				case map_tileKind_t.PICKUP_HEALTH_UPPER:
                    rnd := vec2{
                        rand.float32_range(-1.0, 1.0, &randData),
                        rand.float32_range(-1.0, 1.0, &randData),
                    } * TILE_WIDTH * 0.3
					map_addHealthPickup(highpos + vec3{rnd.x, MAP_HEALTH_PICKUP_SIZE.y, rnd.y})
					tile = map_tileKind_t.WALL_MID
			}

			map_data.tiles[x][y] = tile
			//println("post", tile)
		}

		x += 1

		//println(cast(map_tileKind_t)ch)
	}

	map_data.bounds[1] += 1
	println("end")

	println("bounds[0]", map_data.bounds[0], "bounds[1]", map_data.bounds[1])
	println("mapName", map_data.mapName)
	println("nextMapName", map_data.nextMapName)

	rl.SetShaderValue(
		map_data.portalShader,
		cast(rl.ShaderLocationIndex)rl.GetShaderLocation(map_data.portalShader, "portalPos"),
		&map_data.finishPos,
		rl.ShaderUniformDataType.VEC3,
	)


	attribMatch :: proc(buf : []u8, index : ^i32, name : string) -> bool {
		//println("buf", buf, "index", index^, "name", name)
		endindex : i32 = cast(i32)strings.index_byte(string(buf[index^:]), ':') + 1
		if endindex <= 0 do return false
		src : string = string(buf[index^:index^ + endindex])
		checkstr := fmt.tprint(args={name, ":"}, sep="")
		val := strings.compare(src, checkstr)
		res := val == 0
		if res {
			index^ += cast(i32)len(name) + 1
			skipWhitespace(buf, index)
		}
		return res
	}

	skipWhitespace :: proc(buf : []u8, index : ^i32) -> bool {
		skipped := false
		for strings.is_space(cast(rune)buf[index^]) || buf[index^]=='\n' || buf[index^]=='\r' {
			index^ += 1
			skipped = true
		}
		return skipped
	}

	readF32 :: proc(buf : []u8, index : ^i32) -> f32 {
		skipWhitespace(buf, index)
		str := string(buf[index^:])
		val, ok := strconv.parse_f32(str)
		_ = ok
		skipToNextWhitespace(buf, index)
		return val
	}

	readI32 :: proc(buf : []u8, index : ^i32) -> i32 {
		skipWhitespace(buf, index)
		str := string(buf[index^:])
		val, ok := strconv.parse_int(str)
		_ = ok
		skipToNextWhitespace(buf, index)
		return cast(i32)val
	}

	// reads string in between "
	readString :: proc(buf : []u8, index : ^i32) -> string {
		skipWhitespace(buf, index)
		if buf[index^] != '\"' do return ""
		startindex := index^ + 1
		endindex := startindex + cast(i32)strings.index_byte(string(buf[startindex:]), '\"')
		index^ = endindex + 1
		res := string(buf[startindex:endindex])
		println("startindex", startindex, "endindex", endindex, "res", res)
		return res
	}

	skipToNextWhitespace :: proc(buf : []u8, index : ^i32) {
		for !strings.is_space(cast(rune)buf[index^]) && buf[index^]!='\n' && buf[index^]!='\r' {
			index^ += 1
			println("skip to next line")
		}
		index^ += 1
	}
}

map_debugPrint :: proc() {
	for x : i32 = 0; x < map_data.bounds[0]; x += 1 {
		for y : i32 = 0; y < map_data.bounds[1]; y += 1 {
			fmt.print(map_data.tiles[x][y] == map_tileKind_t.FULL ? "#" : " ")
		}
		println("")
	}
}

// draw tilemap, pickups, etc.
map_drawTilemap :: proc() {
	rl.BeginShaderMode(map_data.tileShader)
	for x : i32 = 0; x < map_data.bounds[0]; x += 1 {
		for y : i32 = 0; y < map_data.bounds[1]; y += 1 {
			//rl.DrawCubeWires(vec3{posxz[0], 0.0, posxz[1]}, TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.GRAY)
			tilekind := map_data.tiles[x][y]

			boxbuf : [PHY_MAX_TILE_BOXES]phy_box_t = {}
			boxcount := map_getTileBoxes({x, y}, boxbuf[0:])
			//checker := cast(bool)((x%2) ~ (y%2))
			#partial switch tilekind {
				case:
					for i : i32 = 0; i < boxcount; i += 1 {
						rl.DrawModelEx(map_data.tileModel, boxbuf[i].pos, {0,1,0}, 0.0, boxbuf[i].size*2.0, rl.WHITE)
					}
				case map_tileKind_t.ELEVATOR:
					rl.DrawModelEx(map_data.elevatorModel, boxbuf[0].pos, {0,1,0}, 0.0, boxbuf[0].size*2.0, rl.WHITE)
					for i : i32 = 1; i < boxcount; i += 1 {
						rl.DrawModelEx(map_data.tileModel, boxbuf[i].pos, {0,1,0}, 0.0, boxbuf[i].size*2.0, rl.WHITE)
					}
			}
		}
	}
	rl.EndShaderMode()

	rl.BeginShaderMode(map_data.portalShader)
	// draw finish
	rl.DrawCubeTexture(map_data.portalTexture, map_data.finishPos, MAP_TILE_FINISH_SIZE.x*2, MAP_TILE_FINISH_SIZE.y*2, MAP_TILE_FINISH_SIZE.z*2, rl.WHITE)
	rl.EndShaderMode()

	// draw pickups and update them
	{
		ROTSPEED :: 180
		SCALE :: 5.0

		// update gun pickups
		// draw gun pickups
		for i : i32 = 0; i < map_data.gunPickupCount; i += 1 {
			pos := map_data.gunPickups[i].pos + vec3{0, math.sin(timepassed*8.0)*0.2, 0}
			gunindex := cast(i32)map_data.gunPickups[i].kind
			rl.DrawModelEx(gun_data.gunModels[gunindex], pos, {0,1,0}, timepassed*ROTSPEED, SCALE, rl.WHITE)
			rl.DrawSphere(pos, -2.0, {255,230,180,40})
            RAD :: 4.5
			if linalg.length2(player_data.pos - pos) < RAD*RAD {
				gun_data.equipped = map_data.gunPickups[i].kind
				gun_data.ammoCounts[gunindex] = gun_startAmmoCounts[gunindex]
				playSoundMulti(gun_data.ammoPickupSound)

				temp := map_data.gunPickups[i]
				map_data.gunPickupCount -= 1
				map_data.gunPickups[i] = map_data.gunPickups[map_data.gunPickupCount]
				map_data.gunPickups[map_data.gunPickupCount] = temp
			}
		}
        
		// update health pickups
		// draw health pickups
        for i : i32 = 0; i < map_data.healthPickupCount; i += 1 {
            rl.DrawCubeTexture(
				map_data.healthPickupTexture,
                map_data.healthPickups[i],
                MAP_HEALTH_PICKUP_SIZE.x*2.0,
                MAP_HEALTH_PICKUP_SIZE.y*2.0,
                MAP_HEALTH_PICKUP_SIZE.z*2.0,
                rl.WHITE,
            )
	
            RAD :: 4.5
            if linalg.length2(player_data.pos - map_data.healthPickups[i]) < RAD*RAD {
                player_data.health = PLAYER_MAX_HEALTH
                screenTint = {1.0,1.0,0.1}
                playSound(player_data.healthPickupSound)
                
                temp := map_data.healthPickups[i]
				map_data.healthPickupCount -= 1
				map_data.healthPickups[i] = map_data.healthPickups[map_data.healthPickupCount]
				map_data.healthPickups[map_data.healthPickupCount] = temp
            }
        }
	}
}




//
// PLAYER
//
// player movement code
// also handles elevators, death, etc.
//

PLAYER_MAX_HEALTH   :: 10
PLAYER_HEAD_CENTER_OFFSET	:: 0.8
PLAYER_LOOK_SENSITIVITY		:: 0.004
PLAYER_FOV			:: 110
PLAYER_VIEWMODEL_FOV		:: 90
PLAYER_SIZE			:: vec3{1,2,1}
PLAYER_HEAD_SIN_TIME		::  math.PI * 5.0

PLAYER_GRAVITY			:: 210 // 800
PLAYER_SPEED			:: 105 // 320
PLAYER_GROUND_ACCELERATION	:: 6 // 10
PLAYER_GROUND_FRICTION		:: 6 // 6
PLAYER_AIR_ACCELERATION		:: 0.5 // 0.7
PLAYER_AIR_FRICTION		:: 0.01 // 0
PLAYER_JUMP_SPEED		:: 70 // 270
PLAYER_MIN_NORMAL_Y		:: 0.25

PLAYER_FALL_DEATH_Y :: -TILE_HEIGHT*1.2

PLAYER_KEY_JUMP :: rl.KeyboardKey.SPACE

player_data : struct {
	rotImpulse	: vec3,
	health		: f32,
	lookRotEuler	: vec3,
	pos		: vec3,
	isOnGround	: bool,
	vel		: vec3,
	lookDir		: vec3,
	lookRotMat3	: mat3,
	stepTimer	: f32,

	jumpSound	: rl.Sound,
	footstepSound	: rl.Sound,
	landSound	: rl.Sound,
	damageSound	: rl.Sound,
	swooshSound	: rl.Sound,
    healthPickupSound   : rl.Sound,

	swooshStrength	: f32, // just lerped velocity length
}



player_damage :: proc(damage : f32) {
	player_data.health -= damage
	playSoundMulti(player_data.damageSound)
    screenTint = {1,0.2,0}
}

_player_update :: proc() {
    if player_data.pos.y < PLAYER_FALL_DEATH_Y {
		player_die()
		return
	} else if player_data.pos.y < PLAYER_FALL_DEATH_Y*0.4 {
        screenTint = {1,1,1} * (1.0 - clamp(abs(player_data.pos.y - PLAYER_FALL_DEATH_Y*0.4) * 0.02, 0.0, 1.0))
    }

	if phy_boxVsBox(player_data.pos, PLAYER_SIZE * 0.5, map_data.finishPos, MAP_TILE_FINISH_SIZE) {
		player_finishMap()
		return
	}

	if player_data.health <= 0.0 {
		player_die()
		return
	}

	vellen := linalg.length(player_data.vel)

	player_data.swooshStrength = math.lerp(player_data.swooshStrength, vellen, clamp(deltatime * 3.0, 0.0, 1.0))
	rl.SetSoundVolume(player_data.swooshSound, clamp(math.pow(0.001 + player_data.swooshStrength*0.003, 2.0), 0.0, 1.0) * 0.8)
	if !rl.IsSoundPlaying(player_data.swooshSound) do playSound(player_data.swooshSound)

	if player_data.isOnGround && linalg.length(player_data.vel * vec3{1,0,1}) > 5.0 {
		player_data.stepTimer += deltatime * PLAYER_HEAD_SIN_TIME
		if player_data.stepTimer > math.PI*2.0 {
			player_data.stepTimer = 0.0
			playSoundMulti(player_data.footstepSound)
		}
	} else {
		player_data.stepTimer = -0.01
	}

	player_data.rotImpulse = linalg.lerp(player_data.rotImpulse, vec3{0,0,0}, clamp(deltatime * 6.0, 0.0, 1.0))

	player_data.lookRotMat3 = linalg.matrix3_from_yaw_pitch_roll(
		player_data.lookRotEuler.y + player_data.rotImpulse.y,
		clamp(player_data.lookRotEuler.x + player_data.rotImpulse.x, -math.PI*0.5*0.95, math.PI*0.5*0.95),
		player_data.lookRotEuler.z + player_data.rotImpulse.z,
	)

	forw  := linalg.vector_normalize(linalg.matrix_mul_vector(player_data.lookRotMat3, vec3{0, 0, 1}) * vec3{1, 0, 1})
	right := linalg.vector_normalize(linalg.matrix_mul_vector(player_data.lookRotMat3, vec3{1, 0, 0}) * vec3{1, 0, 1})

	movedir : vec2 = {}
	if rl.IsKeyDown(rl.KeyboardKey.W)	do movedir.y += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.A)	do movedir.x += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.S)	do movedir.y -= 1.0
	if rl.IsKeyDown(rl.KeyboardKey.D)	do movedir.x -= 1.0
	//if rl.IsKeyPressed(rl.KeyboardKey.C)do player_data.pos.y -= 2.0

	tilepos := map_worldToTile(player_data.pos)
	c := [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
	isInElevatorTile := c in map_data.elevatorHeights

	player_data.vel.y -= PLAYER_GRAVITY * deltatime // * (player_data.isOnGround ? 0.25 : 1.0)

	jumped := rl.IsKeyPressed(PLAYER_KEY_JUMP) && player_data.isOnGround
	if jumped {
		player_data.vel.y = PLAYER_JUMP_SPEED
		if isInElevatorTile do player_data.pos.y += 0.05 * PLAYER_SIZE.y
		//player_data.isOnGround = false
		playSoundMulti(player_data.jumpSound)
	}


	player_accelerate :: proc(dir : vec3, wishspeed : f32, accel : f32) {
		currentspeed := linalg.dot(player_data.vel, dir)
		addspeed := wishspeed - currentspeed
		if addspeed < 0.0 do return

		accelspeed := accel * wishspeed * deltatime
		if accelspeed > addspeed do accelspeed = addspeed

		player_data.vel += dir * accelspeed
	}

	player_accelerate(forw*movedir.y + right*movedir.x, PLAYER_SPEED,
		player_data.isOnGround ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)

	wishpos := player_data.pos + player_data.vel * deltatime
	
	phy_tn, phy_norm, phy_hit := phy_boxCastTilemap(player_data.pos, wishpos, PLAYER_SIZE)
	phy_vec := player_data.pos + linalg.normalize(player_data.vel)*phy_tn
	
	println("pos", player_data.pos, "vel", player_data.vel)
	//println("phy vec", phy_vec, "norm", phy_norm, "hit", phy_hit)
	
	player_data.pos = phy_vec
	if phy_hit do player_data.pos += phy_norm*PHY_BOXCAST_EPS*2.0

	prevIsOnGround := player_data.isOnGround
	player_data.isOnGround = phy_hit && phy_norm.y > PLAYER_MIN_NORMAL_Y && !jumped

	if !prevIsOnGround && player_data.isOnGround { // just landed
		if !rl.IsSoundPlaying(player_data.landSound) {
			playSound(player_data.landSound)
			playSoundMulti(player_data.footstepSound)
		}
	}



	// elevator update
	elevatorIsMoving := false
	{
		tilepos = map_worldToTile(player_data.pos)
		c = [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
		isInElevatorTile = c in map_data.elevatorHeights

		if isInElevatorTile {
			height := map_data.elevatorHeights[c]
			elevatorIsMoving = false

			y := math.lerp(TILE_ELEVATOR_Y0, TILE_ELEVATOR_Y1, height) + TILE_WIDTH*TILEMAP_MID/2.0 + PLAYER_SIZE.y+0.01

			if player_data.pos.y - PLAYER_SIZE.y - 0.02 < y {
				height += TILE_ELEVATOR_MOVE_FACTOR * deltatime
				elevatorIsMoving = true
			}

			if height > 1.0 {
				height = 1.0
				elevatorIsMoving = false
			} else if height < 0.0 {
				height = 0.0
				elevatorIsMoving = false
			}
			map_data.elevatorHeights[c] = height

			if player_data.pos.y - 0.005 < y && elevatorIsMoving {
				player_data.pos.y = y + TILE_ELEVATOR_SPEED*deltatime
				player_data.vel.y = PLAYER_GRAVITY * deltatime
			}

			if rl.IsKeyPressed(PLAYER_KEY_JUMP) && elevatorIsMoving {
				player_data.vel.y += TILE_ELEVATOR_SPEED * 0.5
			}
		}

		if elevatorIsMoving {
			println("elevator moving")
			if !rl.IsSoundPlaying(map_data.elevatorSound) {
				playSound(map_data.elevatorSound)
			}
		} else {
			rl.StopSound(map_data.elevatorSound)
		}
	}

	player_data.isOnGround |= elevatorIsMoving



	if phy_hit do player_data.vel = phy_clipVelocity(player_data.vel, phy_norm, !player_data.isOnGround && phy_hit ? 1.2 : 0.98)

	player_data.vel = phy_applyFrictionToVelocity(player_data.vel, player_data.isOnGround ? PLAYER_GROUND_FRICTION : PLAYER_AIR_FRICTION)



	cam_forw := linalg.matrix_mul_vector(player_data.lookRotMat3, vec3{0, 0, 1})
	player_data.lookDir = cam_forw // TODO: update after the new rotation has been set

	// camera
	{
		if framespassed > 5 { // mouse input seems to have weird spike first frame
			player_data.lookRotEuler.y += -rl.GetMouseDelta().x * PLAYER_LOOK_SENSITIVITY
			player_data.lookRotEuler.x += rl.GetMouseDelta().y * PLAYER_LOOK_SENSITIVITY
			player_data.lookRotEuler.x = clamp(player_data.lookRotEuler.x, -math.PI*0.5*0.95, math.PI*0.5*0.95)
		}
	
		player_data.lookRotEuler.z = math.lerp(player_data.lookRotEuler.z, 0.0, clamp(deltatime * 7.5, 0.0, 1.0))
		player_data.lookRotEuler.z -= movedir.x*deltatime*0.75
		player_data.lookRotEuler.z = clamp(player_data.lookRotEuler.z, -math.PI*0.3, math.PI*0.3)

		cam_y : f32 = PLAYER_HEAD_CENTER_OFFSET
		camera.position = player_data.pos + camera.up * cam_y
		camera.target = camera.position + cam_forw
		camera.up = linalg.normalize(linalg.quaternion_mul_vector3(linalg.quaternion_angle_axis(player_data.lookRotEuler.z*1.3, cam_forw), vec3{0,1.0,0}))
	}


	if debugIsEnabled {
		size := vec3{1,1,1}
		tn, normal, hit := phy_boxCastTilemap(camera.position, camera.position + cam_forw*1000.0, size*0.5)
		hitpos := camera.position + cam_forw*tn
		rl.DrawCube(hitpos, size.x, size.y, size.z, rl.YELLOW)
		rl.DrawLine3D(hitpos, hitpos + normal*4, rl.ORANGE)
	}


	if debugIsEnabled {
		rl.DrawCubeWires(map_tileToWorld(tilepos), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, {0,255,0,100})
	}
}



player_startMap :: proc() {
	println("player started game")
	player_data.pos = map_data.startPos
	player_data.lookRotEuler.x = 0.0
	player_data.lookRotEuler.z = 0.0
	player_data.lookRotEuler.y = math.PI*2 - (math.atan2(-map_data.startPlayerDir.x, -map_data.startPlayerDir.y) * math.sign(-map_data.startPlayerDir.x))
	player_initData()
}

player_initData :: proc() {
	player_data.rotImpulse = {}
	player_data.vel = {}
	gun_data.timer = 0
	player_data.health = PLAYER_MAX_HEALTH
	player_data.vel = {0, 0.1, 0}
	player_data.lookDir = {0,0,1}

	gun_data.ammoCounts = gun_startAmmoCounts
}

player_die :: proc() {
	println("player died")
	player_damage(1.0)
	player_startMap()
	player_initData()
	world_reset()
}

player_finishMap :: proc() {
	println("player finished game")
}





//
// GUNS
//
// (guns for the player, not for the enemies)
//

GUN_SCALE :: 1.1
GUN_POS_X :: 0.1

GUN_COUNT :: 3
gun_kind_t :: enum {
	SHOTGUN		= 0,
	MACHINEGUN	= 1,
	LASERRIFLE	= 2,
}

GUN_SHOTGUN_SPREAD		:: 0.15
GUN_SHOTGUN_DAMAGE		:: 0.1
GUN_MACHINEGUN_SPREAD		:: 0.02
GUN_MACHINEGUN_DAMAGE		:: 0.2
GUN_LASERRIFLE_DAMAGE		:: 1.0

gun_startAmmoCounts : [GUN_COUNT]i32 = {24, 86, 12}
gun_shootTimes : [GUN_COUNT]f32 = {0.5, 0.15, 1.0}

gun_data : struct {
	equipped	: gun_kind_t,
	timer		: f32,

	ammoCounts	: [GUN_COUNT]i32,

	flareModel	: rl.Model,
	gunModels	: [GUN_COUNT]rl.Model,

	shotgunSound	: rl.Sound,
	machinegunSound	: rl.Sound,
	laserrifleSound	: rl.Sound,
	headshotSound	: rl.Sound,
	emptyMagSound	: rl.Sound,
	ammoPickupSound	: rl.Sound,
}



gun_calcViewportPos :: proc() -> vec3 {
	s := math.sin(player_data.stepTimer < 0.0 ? timepassed*PLAYER_HEAD_SIN_TIME*0.5 : player_data.stepTimer*0.5) * clamp(linalg.length(player_data.vel) * 0.01, 0.1, 1.0) *
		0.04 * (player_data.isOnGround ? 1.0 : 0.05)
	kick := clamp(gun_data.timer*0.5, 0.0, 1.0)*0.8
	return vec3{-GUN_POS_X + player_data.lookRotEuler.z*0.5,-0.2 + s + kick*0.15, 0.48 - kick}
}

gun_getMuzzleOffset :: proc() -> vec3 {
	offs := vec3{}
	switch gun_data.equipped {
		case gun_kind_t.SHOTGUN:	offs = {0,0,0.6}
		case gun_kind_t.MACHINEGUN:	offs = {0,0,0.9}
		case gun_kind_t.LASERRIFLE:	offs = {0,0,0.5}
	}
	return offs
}

gun_calcMuzzlePos :: proc() -> vec3 {
	offs := gun_getMuzzleOffset()
	return camera.position + linalg.matrix_mul_vector(player_data.lookRotMat3, gun_calcViewportPos() + offs)
}

gun_drawModel :: proc(pos : vec3) {
	if gun_data.ammoCounts[cast(i32)gun_data.equipped] <= 0 do return

	gunindex := cast(i32)gun_data.equipped
	rl.DrawModel(gun_data.gunModels[gunindex], pos, GUN_SCALE, rl.WHITE)

	// flare
	FADETIME :: 0.15
	fade := (gun_data.timer - gun_shootTimes[gunindex] + FADETIME) / FADETIME
	if fade > 0.0 {
		rnd := randVec3()
		muzzleoffs := gun_getMuzzleOffset() + rnd*0.02
		rl.DrawModel(gun_data.flareModel, pos + muzzleoffs, 0.4 - fade*fade*0.2, rl.Fade(rl.WHITE, clamp(fade, 0.0, 1.0)*0.9))
	}
}

_gun_update :: proc() {
	prevgun := gun_data.equipped
	gunindex := cast(i32)gun_data.equipped

	// scrool wheel gun switching
	if rl.GetMouseWheelMove() > 0.5			do gunindex += 1
	else if rl.GetMouseWheelMove() < -0.5		do gunindex -= 1
	else if rl.IsKeyPressed(rl.KeyboardKey.ONE)	do gunindex = 0
	else if rl.IsKeyPressed(rl.KeyboardKey.TWO)	do gunindex = 1
	else if rl.IsKeyPressed(rl.KeyboardKey.THREE)	do gunindex = 2
	if gunindex < 0 do gunindex = GUN_COUNT - 1
	gunindex %= GUN_COUNT
	gun_data.equipped = cast(gun_kind_t)gunindex
	gunindex = cast(i32)gun_data.equipped


	if gun_data.equipped != prevgun {
		gun_data.timer = -1.0
		if gun_data.ammoCounts[gunindex] <= 0 {
			playSoundMulti(gun_data.emptyMagSound)
		}
	}

	gun_data.timer -= deltatime



	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) && gun_data.timer < 0.0 {
		if gun_data.ammoCounts[gunindex] > 0 {
			muzzlepos := gun_calcMuzzlePos()
			switch gun_data.equipped {
				case gun_kind_t.SHOTGUN:
					right := linalg.cross(player_data.lookDir, camera.up)
					up := camera.up
					RAD :: 0.5
					COL :: vec4{1,0.7,0.2,0.9}
					DUR :: 0.7
					cl := bullet_shootRaycast(muzzlepos, player_data.lookDir,							GUN_SHOTGUN_DAMAGE, DUR, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*right),		GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*up),			GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir - GUN_SHOTGUN_SPREAD*right),		GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir - GUN_SHOTGUN_SPREAD*up),			GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*0.7*(+up + right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*0.7*(+up - right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*0.7*(-up + right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*0.7*(-up - right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)

					player_data.vel -= player_data.lookDir*cast(f32)(cl < PLAYER_SIZE.y*2.1 ? 55.0 : 2.0)
					player_data.rotImpulse.x -= 0.15
					playSound(gun_data.shotgunSound)

				case gun_kind_t.MACHINEGUN:
					rnd := randVec3()
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + rnd*GUN_MACHINEGUN_SPREAD), GUN_MACHINEGUN_DAMAGE, 1.1, {0.6,0.7,0.8, 1.0}, 0.7)
					if !player_data.isOnGround do player_data.vel -= player_data.lookDir * 6.0
					player_data.rotImpulse.x -= 0.035
					player_data.rotImpulse -= rnd * 0.01
					playSoundMulti(gun_data.machinegunSound)

				case gun_kind_t.LASERRIFLE:
					bullet_shootRaycast(muzzlepos, player_data.lookDir, GUN_LASERRIFLE_DAMAGE, 2.5, {1,0.3,0.2, 1.0}, 1.6)
					player_data.vel /= 1.5
					player_data.vel -= player_data.lookDir * 50
					player_data.rotImpulse.x -= 0.2
					player_data.rotImpulse.y += 0.04
					playSound(gun_data.laserrifleSound)

			}

			gun_data.ammoCounts[gunindex] -= 1

			switch gun_data.equipped {
				case gun_kind_t.SHOTGUN:	gun_data.timer = gun_shootTimes[gunindex]
				case gun_kind_t.MACHINEGUN:	gun_data.timer = gun_shootTimes[gunindex]
				case gun_kind_t.LASERRIFLE:	gun_data.timer = gun_shootTimes[gunindex]
			}
		} else if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			playSoundMulti(gun_data.emptyMagSound)
		}
	}
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
	linearEffectsCount : i32,
	linearEffects : [BULLET_LINEAR_EFFECT_MAX_COUNT]struct {
		start		: vec3,
		timeToLive	: f32,
		end		: vec3,
		radius		: f32,
		color		: vec4,
		duration	: f32,
	},

	linearEffectShader	: rl.Shader,
}

// @param timeToLive: in seconds
bullet_createLinearEffect :: proc(start : vec3, end : vec3, rad : f32, col : vec4, duration : f32) {
	if duration <= BULLET_REMOVE_THRESHOLD do return
	index := bullet_data.linearEffectsCount
	if index + 1 >= BULLET_LINEAR_EFFECT_MAX_COUNT do return
	bullet_data.linearEffectsCount += 1
	bullet_data.linearEffects[index] = {}
	bullet_data.linearEffects[index].start		= start
	bullet_data.linearEffects[index].timeToLive	= duration
	bullet_data.linearEffects[index].end		= end
	bullet_data.linearEffects[index].radius		= rad
	bullet_data.linearEffects[index].color		= col
	bullet_data.linearEffects[index].duration	= duration
}

bullet_shootRaycast :: proc(start : vec3, dir : vec3, damage : f32, rad : f32, col : vec4, effectDuration : f32) -> f32 {
	tn, hit, enemykind, enemyindex := phy_boxCastWorld(start, start + dir*1e6, vec3{rad,rad,rad})
	hitpos := start + dir*tn
	bullet_createLinearEffect(start + dir*rad*2.0, hitpos, rad, col, effectDuration)
	if hit {
		switch enemykind {
			case enemy_kind_t.NONE:
			case enemy_kind_t.GRUNT:
				headshot := hitpos.y > enemy_data.grunts[enemyindex].pos.y + ENEMY_GRUNT_SIZE.y*ENEMY_HEADSHOT_HALF_OFFSET
				enemy_data.grunts[enemyindex].health -= headshot ? damage*2 : damage
				if headshot do playSound(gun_data.headshotSound)
				playSoundMulti(enemy_data.gruntHitSound)
				if enemy_data.grunts[enemyindex].health <= 0.0 do playSoundMulti(enemy_data.gruntDeathSound)
			case enemy_kind_t.KNIGHT:
				headshot := hitpos.y > enemy_data.knights[enemyindex].pos.y + ENEMY_KNIGHT_SIZE.y*ENEMY_HEADSHOT_HALF_OFFSET
				enemy_data.knights[enemyindex].health -= headshot ? damage*2 : damage
				if headshot do playSound(gun_data.headshotSound)
				playSoundMulti(enemy_data.knightHitSound)
				if enemy_data.knights[enemyindex].health <= 0.0 do playSoundMulti(enemy_data.knightDeathSound)
		}
	}
	return tn
}

bullet_shootProjectile :: proc(start : vec3, dir : vec3, damage : f32, rad : f32, col : vec4) {

}

_bullet_updateDataAndRender :: proc() {
	assert(bullet_data.linearEffectsCount >= 0)
	assert(bullet_data.linearEffectsCount < BULLET_LINEAR_EFFECT_MAX_COUNT)

	// remove old
	loopremove : for i : i32 = 0; i < bullet_data.linearEffectsCount; i += 1 {
		bullet_data.linearEffects[i].timeToLive -= deltatime
		if bullet_data.linearEffects[i].timeToLive <= BULLET_REMOVE_THRESHOLD { // needs to be removed
			if i + 1 >= bullet_data.linearEffectsCount { // we're on the last one
				bullet_data.linearEffectsCount -= 1
				break loopremove
			}
			bullet_data.linearEffectsCount -= 1
			lastindex := bullet_data.linearEffectsCount
			bullet_data.linearEffects[i] = bullet_data.linearEffects[lastindex]
		}
	}

	// draw
	rl.BeginShaderMode(bullet_data.linearEffectShader)
	for i : i32 = 0; i < bullet_data.linearEffectsCount; i += 1 {
		fade := (bullet_data.linearEffects[i].timeToLive / bullet_data.linearEffects[i].duration)
		col := bullet_data.linearEffects[i].color

		rl.DrawCylinderEx(
			bullet_data.linearEffects[i].start,
			bullet_data.linearEffects[i].end,
			fade * bullet_data.linearEffects[i].radius * 0.05,
			fade * bullet_data.linearEffects[i].radius * 0.4,
			3,
			rl.ColorFromNormalized(vec4{1,1,1,0.5 + fade*0.5}),
		)

		rl.DrawCylinderEx(
			bullet_data.linearEffects[i].start,
			bullet_data.linearEffects[i].end,
			fade * bullet_data.linearEffects[i].radius * 0.1,
			fade * bullet_data.linearEffects[i].radius,
			BULLET_LINEAR_EFFECT_MESH_QUALITY,
			rl.ColorFromNormalized(vec4{col.r, col.g, col.b, col.a * fade}),
		)

		//rl.DrawSphere(
		//	bullet_data.linearEffects[i].start,
		//	fade * bullet_data.linearEffects[i].radius,
		//	rl.ColorFromNormalized(vec4{col.r, col.g, col.b, col.a * fade}),
		//)
	}
	rl.EndShaderMode()
}






//
// ENEMIES
//

ENEMY_GRUNT_MAX_COUNT :: 32
ENEMY_KNIGHT_MAX_COUNT :: 32

ENEMY_HEALTH_MULTIPLIER :: 1.5
ENEMY_HEADSHOT_HALF_OFFSET :: 0.0
ENEMY_GRAVITY           :: 5.0

ENEMY_GRUNT_SIZE		:: vec3{2, 4, 2}
ENEMY_GRUNT_ACCELERATION	:: 13
ENEMY_GRUNT_MAX_SPEED		:: 14
ENEMY_GRUNT_FRICTION		:: 6
ENEMY_GRUNT_MIN_GOOD_DIST	:: 30
ENEMY_GRUNT_MAX_GOOD_DIST	:: 60
ENEMY_GRUNT_ATTACK_TIME		:: 1.5
ENEMY_GRUNT_DAMAGE		:: 1.0
ENEMY_GRUNT_HEALTH		:: 1.0
ENEMY_GRUNT_SPEED_RAND	:: 1.0
ENEMY_GRUNT_DIST_RAND	:: 1.0
ENEMY_GRUNT_MAX_DIST	:: 120.0

ENEMY_KNIGHT_SIZE		:: vec3{1.5, 3, 1.5}
ENEMY_KNIGHT_ACCELERATION	:: 18
ENEMY_KNIGHT_MAX_SPEED		:: 16
ENEMY_KNIGHT_FRICTION		:: 3.5
ENEMY_KNIGHT_DAMAGE		:: 0.8
ENEMY_KNIGHT_ATTACK_TIME	:: 0.6
ENEMY_KNIGHT_HEALTH		:: 1.0
ENEMY_KNIGHT_RANGE      :: 8.0

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

	gruntCount : i32,
	grunts : [ENEMY_GRUNT_MAX_COUNT]struct {
		spawnPos		: vec3,
		attackTimer		: f32,
		pos			: vec3,
		health			: f32,
		target			: vec3,
		isMoving		: bool,
		vel			: vec3,
		attackSinceStopped	: u16,
	},

	knightCount : i32,
	knights : [ENEMY_KNIGHT_MAX_COUNT]struct {
		spawnPos	: vec3,
		health		: f32,
		pos		: vec3,
		attackTimer	: f32,
		isMoving	: bool,
        vel         : vec3,
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

		// println("p_tn", p_tn, "p_hit", p_hit, "t_tn", t_tn, "t_hit", t_hit)
	
		enemy_data.grunts[i].attackTimer -= deltatime


		if seeplayer {
			enemy_data.grunts[i].target = player_data.pos
			enemy_data.grunts[i].isMoving = true
		}


		flatdir := linalg.normalize((enemy_data.grunts[i].target - pos) * vec3{1,0,1})

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

		if seeplayer && p_tn < ENEMY_GRUNT_MAX_DIST {
			if enemy_data.grunts[i].attackTimer < 0.0 { // attack
				enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME

				rndstrength := (linalg.length(player_data.vel)*ENEMY_GRUNT_SPEED_RAND +
					p_tn*ENEMY_GRUNT_DIST_RAND) * 0.1
	
				// cast bullet
				t_tn, t_norm, t_hit := phy_boxCastTilemap(pos, pos + (dir + randVec3()*rndstrength)*1e6, {EPS,EPS,EPS})

				
				bullet_createLinearEffect(pos, pos + dir*p_tn, 1.0, vec4{1.0, 0.0, 0.0, 0.5}, 1.0)
				player_damage(ENEMY_GRUNT_DAMAGE)
			}
		} else {
			enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME * 0.5
		}
	
        enemy_data.grunts[i].vel.y -= ENEMY_GRAVITY * deltatime
		enemy_data.grunts[i].vel = phy_applyFrictionToVelocity(enemy_data.grunts[i].vel, ENEMY_GRUNT_FRICTION)
		speed := linalg.length(enemy_data.grunts[i].vel)
		enemy_data.grunts[i].vel = speed < ENEMY_GRUNT_MAX_SPEED ? enemy_data.grunts[i].vel : (enemy_data.grunts[i].vel/speed)*ENEMY_GRUNT_MAX_SPEED
		speed = max(speed, ENEMY_GRUNT_MAX_SPEED)
		
		mov_tn, mov_norm, mov_hit := phy_boxCastTilemap(pos, pos + enemy_data.grunts[i].vel, ENEMY_GRUNT_SIZE)

		if mov_hit {
			enemy_data.grunts[i].vel = phy_clipVelocity(enemy_data.grunts[i].vel, mov_norm, mov_norm.y>0.5 ? 1.0 : 1.5)
		}

		if speed > 1e-6 {
			enemy_data.grunts[i].pos += (enemy_data.grunts[i].vel/speed) * mov_tn
		}
	}



	// update knights
	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		if enemy_data.knights[i].health <= 0.0 do continue
        
		pos := enemy_data.knights[i].pos + vec3{0, ENEMY_GRUNT_SIZE.y*0.5, 0}
		dir := linalg.normalize(player_data.pos - pos)
		p_tn, p_hit := phy_boxCastPlayer(pos, dir, {0,0,0})
		t_tn, t_norm, t_hit := phy_boxCastTilemap(pos, pos + dir*1e6, {1,1,1})
		seeplayer := p_tn < t_tn && p_hit

		// println("p_tn", p_tn, "p_hit", p_hit, "t_tn", t_tn, "t_hit", t_hit)
		
		enemy_data.knights[i].attackTimer -= deltatime


		if seeplayer {
			enemy_data.knights[i].target = player_data.pos
			enemy_data.knights[i].isMoving = true
		}


		flatdir := linalg.normalize((enemy_data.knights[i].target - pos) * vec3{1,0,1})

		if enemy_data.knights[i].isMoving {
			enemy_data.knights[i].vel += flatdir * ENEMY_KNIGHT_ACCELERATION * deltatime
		}

		if seeplayer {
			if enemy_data.knights[i].attackTimer < 0.0 && p_tn < ENEMY_KNIGHT_RANGE { // attack
				enemy_data.knights[i].attackTimer = ENEMY_KNIGHT_ATTACK_TIME
				player_damage(ENEMY_KNIGHT_DAMAGE)
                player_data.vel = flatdir * 100.0
                player_data.vel.y += 30.0
                enemy_data.knights[i].vel = -flatdir * ENEMY_KNIGHT_MAX_SPEED
			}
		} else {
			enemy_data.knights[i].attackTimer = ENEMY_KNIGHT_ATTACK_TIME * 0.5
		}
	
        enemy_data.knights[i].vel.y -= ENEMY_GRAVITY * deltatime
		enemy_data.knights[i].vel = phy_applyFrictionToVelocity(enemy_data.knights[i].vel, ENEMY_KNIGHT_FRICTION)
		speed := linalg.length(enemy_data.knights[i].vel)
		enemy_data.knights[i].vel = speed < ENEMY_KNIGHT_MAX_SPEED ? enemy_data.knights[i].vel : (enemy_data.knights[i].vel/speed)*ENEMY_KNIGHT_MAX_SPEED
		speed = max(speed, ENEMY_KNIGHT_MAX_SPEED)
		
		mov_tn, mov_norm, mov_hit := phy_boxCastTilemap(pos, pos + enemy_data.knights[i].vel, ENEMY_KNIGHT_SIZE)

		if mov_hit {
			enemy_data.knights[i].vel = phy_clipVelocity(enemy_data.knights[i].vel, mov_norm, mov_norm.y>0.5 ? 1.0 : 1.5)
		}

		if speed > 1e-6 {
			enemy_data.knights[i].pos += (enemy_data.knights[i].vel/speed) * mov_tn
		}
	}



	// render grunts
	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		if enemy_data.grunts[i].health <= 0.0 do continue
		rl.DrawCube(enemy_data.grunts[i].pos, ENEMY_GRUNT_SIZE.x*2, ENEMY_GRUNT_SIZE.y*2, ENEMY_GRUNT_SIZE.z*2, rl.PINK)
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
// MENU UI
//

ui_drawText :: proc(pos : vec2, size : f32, color : rl.Color, text : string) {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	rl.DrawTextEx(normalFont, cstr, pos, size, 0.0, color)
}








//
// PHYSICS
//

PHY_MAX_TILE_BOXES :: 4
PHY_BOXCAST_EPS :: 1e-2

phy_box_t :: struct {
	pos  : vec3,
	size : vec3,
}



phy_boxVsBox :: proc(pos0 : vec3, size0 : vec3, pos1 : vec3, size1 : vec3) -> bool {
	return  (pos0.x + size0.x > pos1.x - size1.x && pos0.x - size0.x < pos1.x + size1.x) &&
		(pos0.y + size0.y > pos1.y - size1.y && pos0.y - size0.y < pos1.y + size1.y) &&
		(pos0.z + size0.z > pos1.z - size1.z && pos0.z - size0.z < pos1.z + size1.z)
}

// calculates near and far hit points with a box
// @param pos: relative to box center
phy_rayBoxNearFar :: proc(pos : vec3, dirinv : vec3, dirinvabs : vec3, size : vec3) -> (f32, f32) {
	n := dirinv * pos
	k := dirinvabs * size
	t1 := -n - k
	t2 := -n + k
	tn := max(max(t1.x, t1.y), t1.z)
	tf := min(min(t2.x, t2.y), t2.z)
	return tn, tf
}

// hit or inside
phy_nearFarHit :: proc(tn : f32, tf : f32) -> bool {
	return tn<tf && tf>0
}



// "linecast" box through the map
// ! boxsize < TILE_WIDTH
// @returns: newpos, normal, tmin
phy_boxCastTilemap :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (f32, vec3, bool) {
	using math
	posxz := vec2{pos.x, pos.z}
	dir := wishpos - pos
	linelen := linalg.length(dir)
	if !map_isTilePosValid(map_worldToTile(pos)) do return linelen, {0,0.1,0}, false
	lowerleft := map_tilePosClamp(map_worldToTile(pos - vec3{dir.x>0.0 ? 1.0:-1.0, 0.0, dir.z>0.0 ? 1.0:-1.0}*TILE_WIDTH))
	tilepos := lowerleft

	dir = linelen == 0.0 ? {0,-1,0} : dir / linelen
	ddadir := linalg.normalize(vec2{dir.x, dir.z})

	phy_boxCastContext_t :: struct {
		pos		: vec3,
		dirsign		: vec3,
		dirinv		: vec3, // 1.0/dir
		dirinvabs	: vec3, // abs(1.0/dir)
		boxoffs		: vec3,
		tmin		: f32,
		normal		: vec3,
		boxlen		: f32,
		hit		: bool,
		linelen	: f32,
	}

	ctx : phy_boxCastContext_t = {}

	ctx.pos		= pos
	ctx.dirsign	= vec3{sign(dir.x), sign(dir.y), sign(dir.z)}
	ctx.dirinv	= vec3{
		dir.x==0.0?1e6:1.0/dir.x,
		dir.y==0.0?1e6:1.0/dir.y,
		dir.z==0.0?1e6:1.0/dir.z,
	}//vec3{1,1,1}/dir
	ctx.dirinvabs	= vec3{abs(ctx.dirinv.x), abs(ctx.dirinv.y), abs(ctx.dirinv.z)}
	ctx.boxoffs	= boxsize - {PHY_BOXCAST_EPS, PHY_BOXCAST_EPS, PHY_BOXCAST_EPS}
	ctx.tmin	= linelen
	ctx.normal	= vec3{0,0.1,0} // debug value
	ctx.boxlen	= linalg.length(boxsize)
	ctx.hit		= false
	ctx.linelen	= linelen

	// DDA init
	deltadist := vec2{abs(1.0/ddadir.x), abs(1.0/ddadir.y)}
	raystepf := vec2{sign(ddadir.x), sign(ddadir.y)}
	griddiff := vec2{cast(f32)lowerleft.x, cast(f32)lowerleft.y} - posxz/TILE_WIDTH
	sidedist := (raystepf * griddiff + (raystepf * 0.5) + vec2{0.5, 0.5}) * deltadist
	raystep := ivec2{ddadir.x>0.0 ? 1 : -1, ddadir.y>0.0 ? 1 : -1}

	//println("pos", pos, "griddiff", griddiff, "lowerleft", lowerleft, "posxz", posxz, "sidedist", sidedist, "deltadist", deltadist)

	for {
		if !map_isTilePosValid(tilepos) ||
		(linalg.length(vec2{cast(f32)(tilepos.x - lowerleft.x), cast(f32)(tilepos.y - lowerleft.y)})-3.0)*TILE_WIDTH > ctx.tmin {
				break
		}

		checktiles : [2]ivec2
		checktiles[0] = tilepos
		checktiles[1] = tilepos

		// advance DDA
		if sidedist.x < sidedist.y {
			sidedist.x += deltadist.x
			tilepos.x += raystep.x
			checktiles[1].y += raystep.y
		} else {
			sidedist.y += deltadist.y
			tilepos.y += raystep.y
			checktiles[1].x += raystep.x
		}

		//println("tilepos", tilepos, "(orig)checktiles[0]", checktiles[0], "(near)checktiles[1]", checktiles[1])
	
		for j : i32 = 0; j < len(checktiles); j += 1 {
			//println("checktile")
			if !map_isTilePosValid(checktiles[j]) do continue
			phy_boxCastTilemapTile(checktiles[j], &ctx)
			//rl.DrawCube(map_tileToWorld(checktiles[j]), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
			//rl.DrawCube(map_tileToWorld(checktiles[j]), 2, 1000, 2, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
			//rl.DrawCubeWires(map_tileToWorld(checktiles[j]), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.Fade(j==0? rl.BLUE : rl.ORANGE, 0.1))
		}
	}

	// @dir: precomputed normalize(wishpos - pos)
	// @returns : clipped pos
	phy_boxCastTilemapTile :: proc(coord : ivec2, ctx : ^phy_boxCastContext_t) {
		boxbuf : [PHY_MAX_TILE_BOXES]phy_box_t = {}
		boxcount := map_getTileBoxes(coord, boxbuf[0:])

		for i : i32 = 0; i < boxcount; i += 1 {
			box := boxbuf[i]

			// if debugIsEnabled do rl.DrawCube(box.pos, box.size.x*2+0.2, box.size.y*2+0.2, box.size.z*2+0.2, rl.Fade(rl.GREEN, 0.1))

			n := ctx.dirinv * (ctx.pos - box.pos)
			k := ctx.dirinvabs * (box.size + ctx.boxoffs)
			t1 := -n - k
			t2 := -n + k
			tn := max(max(t1.x, t1.y), t1.z)
			tf := min(min(t2.x, t2.y), t2.z)

			//println("tn", tn, "tf", tf)

			if tn>tf || tf<0.0 do continue // no intersection (inside counts as intersection)
			if tn>ctx.tmin do continue // this hit is worse than the one we already have

			if math.is_nan(tn) || math.is_nan(tf) || math.is_inf(tn) || math.is_inf(tf) do continue

			//println("ok")
		
			ctx.tmin = tn
			ctx.normal = -ctx.dirsign * cast(vec3)(glsl.step(glsl.vec3{t1.y,t1.z,t1.x}, glsl.vec3{t1.x,t1.y,t1.z}) * glsl.step(glsl.vec3{t1.z,t1.x,t1.y}, glsl.vec3{t1.x,t1.y,t1.z}))
			ctx.hit = true

		}
	}
	
	ctx.tmin = clamp(ctx.tmin, -MAP_MAX_WIDTH*TILE_WIDTH, MAP_MAX_WIDTH*TILE_WIDTH)

	//return pos + dir*ctx.tmin, ctx.normal, ctx.hit
	return ctx.tmin, ctx.normal, ctx.hit
}



// O(n), n = number of enemies
phy_boxCastEnemies :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (res_tn : f32, res_hit : bool, res_enemykind : enemy_kind_t, res_enemyindex : i32) {
	using math

	dir := wishpos - pos
	dirlen := linalg.length(dir)
	dir = dirlen == 0.0 ? {0,-1,0} : dir/dirlen
	dirinv := vec3{
		dir.x==0.0?1e6:1.0/dir.x,
		dir.y==0.0?1e6:1.0/dir.y,
		dir.z==0.0?1e6:1.0/dir.z,
	}
	dirinvabs := vec3{abs(dirinv.x), abs(dirinv.y), abs(dirinv.z)}

	tnear : f32 = dirlen

	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		if enemy_data.grunts[i].health <= 0.0 do continue
		tn, tf := phy_rayBoxNearFar(pos - enemy_data.grunts[i].pos, dirinv, dirinvabs, ENEMY_GRUNT_SIZE + boxsize)
		if phy_nearFarHit(tn, tf) && tn < tnear {
			tnear = tn
			res_hit = true
			res_enemykind = enemy_kind_t.GRUNT
			res_enemyindex = i
		}
	}

	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		if enemy_data.knights[i].health <= 0.0 do continue
		tn, tf := phy_rayBoxNearFar(pos - enemy_data.knights[i].pos, dirinv, dirinvabs, ENEMY_KNIGHT_SIZE + boxsize)
		if phy_nearFarHit(tn, tf) && tn < tnear {
			tnear = tn
			res_hit = true
			res_enemykind = enemy_kind_t.KNIGHT
			res_enemyindex = i
		}
	}

	res_tn = tnear
	return
}


phy_boxCastPlayer :: proc(pos : vec3, dir : vec3, boxsize : vec3) -> (f32, bool) {
	dirinv := vec3{
		dir.x==0.0?1e6:1.0/dir.x,
		dir.y==0.0?1e6:1.0/dir.y,
		dir.z==0.0?1e6:1.0/dir.z,
	}
	dirinvabs := vec3{abs(dirinv.x), abs(dirinv.y), abs(dirinv.z)}
	tn, tf := phy_rayBoxNearFar(pos - player_data.pos, dirinv, dirinvabs, PLAYER_SIZE + boxsize)
	return tn, phy_nearFarHit(tn, tf)
}


phy_boxCastWorldRes_t :: struct {
	newpos	: vec3,
	hit	: bool,
}

phy_boxCastWorld :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (res_tn : f32, res_hit : bool, res_enemykind : enemy_kind_t, res_enemyindex : i32) {
	e_tn, e_hit, e_enemykind, e_enemyindex := phy_boxCastEnemies(pos, wishpos, boxsize)
	t_tn, t_norm, t_hit := phy_boxCastTilemap(pos, wishpos, boxsize)
	_ = t_norm

	if e_tn < t_tn {
		res_tn		= e_tn
		res_hit		= e_hit
		res_enemykind	= e_enemykind
		res_enemyindex	= e_enemyindex
	} else {
		res_tn		= t_tn
		res_hit		= t_hit
		res_enemykind	= enemy_kind_t.NONE
	}
	return
}


phy_clipVelocity :: proc(vel : vec3, normal : vec3, overbounce : f32) -> vec3 {
	backoff := linalg.vector_dot(vel, normal) * overbounce
	change := normal*backoff
	return vel - change
}


phy_applyFrictionToVelocity :: proc(vel : vec3, friction : f32) -> vec3 {
	len := linalg.vector_length(vel)
	drop := len * friction * deltatime
	return (len == 0.0 ? {} : vel / len) * (len - drop)
}






//
// HELPER PROCEDURES
//

appendToAssetPath :: proc(subdir : string, path : string) -> string {
	return fmt.tprint(
		args={loadpath, filepath.SEPARATOR_STRING, "assets", filepath.SEPARATOR_STRING, subdir, filepath.SEPARATOR_STRING, path},
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
   if !rl.IsAudioDeviceReady() do return {}
	fullpath := appendToAssetPathCstr("audio", path)
	println("! loading sound: ", fullpath)
	return rl.LoadSound(fullpath)
}

loadMusic :: proc(path : string) -> rl.Music {
    if !rl.IsAudioDeviceReady() do return {}
	fullpath := appendToAssetPathCstr("audio", path)
	println("! loading music: ", fullpath)
	return rl.LoadMusicStream(fullpath)
}

loadFont :: proc(path : string) -> rl.Font {
	fullpath := appendToAssetPathCstr("fonts", path)
	println("! loading font: ", fullpath)
	return rl.LoadFont(fullpath)
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
    playSound(sound)
}

playSoundMulti :: proc(sound : rl.Sound) {
    if !rl.IsAudioDeviceReady() do return
    playSoundMulti(sound)
}

// rand vector with elements in -1..1
randVec3 :: proc() -> vec3 {
	return vec3{
		rand.float32_range(-1.0, 1.0, &randData),
		rand.float32_range(-1.0, 1.0, &randData),
		rand.float32_range(-1.0, 1.0, &randData),
	}
}