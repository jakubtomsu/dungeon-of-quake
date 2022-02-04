package miniquake



import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/rand"
import "core:fmt"
import "core:c"
import "core:time"
//RAYLIB_USE_LINALG :: true
import rl "vendor:raylib"
import "core:os"
import "core:path/filepath"
import str "core:strings"
//import win32 "core:sys/win32"



println :: fmt.println
vec2 :: rl.Vector2
vec3 :: rl.Vector3
vec4 :: rl.Vector4
ivec2 :: [2]i32
ivec3 :: [3]i32



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
tileShader : rl.Shader
tileShaderCamPosUniformIndex : rl.ShaderLocationIndex
cubeModel : rl.Model
randData : rand.Rand


// gameplay entity
// TODO
entity_t :: struct {
	pos : vec3,
	rot : rl.Quaternion,
}

entId_t :: distinct u16
entityBuf : map[entId_t]entity_t







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
			rl.ClearBackground(rl.BLACK)

			rl.BeginMode3D(camera)
				_app_render3d()
				_player_update() // TODO: update player after _app_update() call. for now it's here since we need drawing for debug
				_gun_update()
				_enemy_updateDataAndRender()
				_bullet_updateDataAndRender()
			rl.EndMode3D()

			rl.BeginMode3D(viewmodelCamera)
				gun_drawModel(gun_calcViewportPos())
			rl.EndMode3D()
		rl.EndTextureMode()
		
		rl.BeginDrawing()
			rl.ClearBackground(rl.PINK)
			rl.BeginShaderMode(postprocessShader)
				rl.DrawTextureRec(
					rendertextureMain.texture,
					rl.Rectangle{0, 0, cast(f32)rendertextureMain.texture.width,
						-cast(f32)rendertextureMain.texture.height},
					{0, 0},
					rl.WHITE,
				)
			rl.EndShaderMode()

			_app_render2d()
		rl.EndDrawing()


		deltatime = rl.GetFrameTime()
		timepassed += deltatime // not really accurate but whatever
	}

	rl.CloseWindow()
}




//
// APP
//

_app_init :: proc() {
	rl.InitWindow(WINDOW_X, WINDOW_Y, "miniquake")
	rl.SetWindowState({
		rl.ConfigFlag.WINDOW_TOPMOST,
		rl.ConfigFlag.WINDOW_HIGHDPI,
		rl.ConfigFlag.WINDOW_HIGHDPI,
		rl.ConfigFlag.VSYNC_HINT,
	})

	rl.SetTargetFPS(75)
	loadpath = filepath.clean(string(rl.GetWorkingDirectory()))
	println("loadpath", loadpath)

	rendertextureMain = rl.LoadRenderTexture(WINDOW_X, WINDOW_Y)
	postprocessShader = loadFragShader("postprocess.frag")
	tileShader = loadShader("tile.vert", "tile.frag")
	tileShaderCamPosUniformIndex  = cast(rl.ShaderLocationIndex)rl.GetShaderLocation(tileShader, "camPos")

	map_basetexture = loadTexture("metal.png")

	cubeModel = rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
	cubeModel.materials[0].shader = tileShader
	rl.SetMaterialTexture(&cubeModel.materials[0], rl.MaterialMapIndex.DIFFUSE, map_basetexture)

	rand.init(&randData, cast(u64)time.now()._nsec)

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

	entityBuf = make(type_of(entityBuf))

	map_clearAll()
	map_data.bounds = {TILEMAP_MAX_WIDTH, TILEMAP_MAX_WIDTH}
	if os.is_file(appendToAssetPath("maps", "_quickload.mqm")) {
		map_loadFromFile("_quickload.mqm")
	} else {
		map_loadFromFile("test.mqm")
	}
	//map_debugPrint()

	player_startMap()
}

_app_update :: proc() {
	if rl.IsKeyPressed(rl.KeyboardKey.RIGHT_ALT) do debugIsEnabled = !debugIsEnabled

	// pull elevators down
	{
		playerTilePos := map_worldToTile(player_position)
		c := [2]u8{cast(u8)playerTilePos.x, cast(u8)playerTilePos.y}
		for key, val in map_data.elevatorHeights {
			if key == c do continue
			map_data.elevatorHeights[key] = clamp(val - (TILE_ELEVATOR_MOVE_FACTOR * deltatime), 0.0, 1.0)
		}
	}
}

_debugtext_y : i32 = 0
_app_render2d :: proc() {
	_debugtext_y = 2

	// cursor
	//rl.DrawRectangle(WINDOW_X/2 - 3, WINDOW_Y/2 - 3, 6, 6, rl.Fade(rl.BLACK, 0.5))
	//rl.DrawRectangle(WINDOW_X/2 - 2, WINDOW_Y/2 - 2, 4, 4, rl.Fade(rl.WHITE, 0.5))

	gunindex := cast(i32)gun_equipped

	// draw ammo
	ui_drawText({WINDOW_X - 150, WINDOW_Y - 50}, 20, rl.Color{255,200,50,255}, fmt.tprint("ammo: ", gun_ammoCounts[gunindex]))

	if debugIsEnabled {
		rl.DrawFPS(0, 0)
		debugtext :: proc(args : ..any) {
			tstr := fmt.tprint(args=args)
			cstr := str.clone_to_cstring(tstr, context.temp_allocator)
			rl.DrawText(cstr, 6, _debugtext_y * 12, 10, rl.Fade(rl.WHITE, 0.8))
			_debugtext_y += 1
		}

		debugtext("player")
		debugtext("    pos", player_position)
		debugtext("    vel", player_velocity)
		debugtext("    onground", player_isOnGround)
		debugtext("map")
		debugtext("    bounds", map_data.bounds)
		debugtext("gun")
		debugtext("    equipped", gun_equipped)
		debugtext("    timer", gun_timer)
		debugtext("    ammo counts", gun_ammoCounts)
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

	rl.SetShaderValue(tileShader, tileShaderCamPosUniformIndex, &camera.position, rl.ShaderUniformDataType.VEC3)
	map_drawTilemap()
}






//
// MAP
//

TILEMAP_MAX_WIDTH	:: 128
TILE_WIDTH		:: 30.0
TILE_MIN_HEIGHT		:: TILE_WIDTH
TILEMAP_Y_TILES		:: 7
TILE_HEIGHT		:: TILE_WIDTH * TILEMAP_Y_TILES
TILEMAP_MID		:: 4

TILE_ELEVATOR_MOVE_FACTOR	:: 0.55
TILE_ELEVATOR_Y0		:: cast(f32)-4.5*TILE_WIDTH + 2.0
TILE_ELEVATOR_Y1		:: cast(f32)-1.5*TILE_WIDTH - 2.0
TILE_ELEVATOR_SPEED		:: (TILE_ELEVATOR_Y1 - TILE_ELEVATOR_Y0) * TILE_ELEVATOR_MOVE_FACTOR

MAP_TILE_FINISH_SIZE :: vec3{8, 16, 8}

map_basetexture : rl.Texture2D



map_tileKind_t :: enum u8 {
	NONE			= '\\',
	EMPTY			= ' ',
	WALL			= '#',
	WALL_MID		= 'w',
	CEILING			= 'c',
	START_LOWER		= 's', // translated
	START_UPPER		= 'S', // translated
	FINISH_LOWER		= 'f', // translated
	FINISH_UPPER		= 'F', // translated
	PLATFORM		= 'p',
	ELEVATOR		= 'e',
	ENEMY_KNIGHT_LOWER	= 'k', // translated
	ENEMY_KNIGHT_UPPER	= 'K', // translated
	ENEMY_GRUNT_LOWER	= 'g', // translated
	ENEMY_GRUNT_UPPER	= 'G', // translated
}


map_data : struct {
	tiles		: [TILEMAP_MAX_WIDTH][TILEMAP_MAX_WIDTH]map_tileKind_t,
	bounds		: ivec2,
	startPos	: vec3,
	finishPos	: vec3,
	elevatorHeights	: map[[2]u8]f32,
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
	return coord.x >= 0 && coord.y >= 0 && coord.x < TILEMAP_MAX_WIDTH && coord.y < TILEMAP_MAX_WIDTH
}

map_isTilePosValid :: proc(coord : ivec2) -> bool {
	return map_isTilePosInBufferBounds(coord) && coord.x < map_data.bounds.x && coord.y < map_data.bounds.y
}

map_tilePosClamp :: proc(coord : ivec2) -> ivec2 {
	return ivec2{clamp(coord.x, 0, map_data.bounds.x), clamp(coord.y, 0, map_data.bounds.y)}
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

		case map_tileKind_t.WALL:
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

		case map_tileKind_t.PLATFORM:
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[2] = phy_calcBox(posxz, 0, 1)
			return 3
		
		case map_tileKind_t.CEILING:
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[1] = phy_calcBox(posxz, 2, 5)
			return 2
		
		case map_tileKind_t.ELEVATOR:
			boxsize := vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			height, ok := map_data.elevatorHeights[{cast(u8)coord.x, cast(u8)coord.y}]
			if !ok do height = 0.0
			boxbuf[0] = {vec3{posxz[0], math.lerp(TILE_ELEVATOR_Y0, TILE_ELEVATOR_Y1, height), posxz[1]}, vec3{TILE_WIDTH, TILE_WIDTH*TILEMAP_MID, TILE_WIDTH}/2}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			return 2
	}
	return 0
}



map_clearAll :: proc() {
	map_data.bounds[0] = 0
	map_data.bounds[1] = 0

	delete(map_data.elevatorHeights)

	for x : u32 = 0; x < TILEMAP_MAX_WIDTH; x += 1 {
		for y : u32 = 0; y < TILEMAP_MAX_WIDTH; y += 1 {
			map_data.tiles[x][y] = map_tileKind_t.EMPTY
		}
	}
}

map_loadFromFile :: proc(name: string) {
	fullpath := filepath.clean(str.concatenate({loadpath, filepath.SEPARATOR_STRING, "maps", filepath.SEPARATOR_STRING, name}))
	println("! loading map: ", fullpath)
	data, success := os.read_entire_file_from_filename(fullpath)

	if !success {
		//app_shouldExitNextFrame = true
		println("! error: level file not found!")
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
		}

		tile := cast(map_tileKind_t)ch
		
		if map_isTilePosInBufferBounds({x, y}) {
			println("pre ", tile)
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
					enemy_spawnGrunt(lowpos + vec3{0, 0, 0})
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
			}

			map_data.tiles[x][y] = tile
			println("post", tile)
		}

		x += 1

		//println(cast(map_tileKind_t)ch)
	}

	map_data.bounds[1] += 1
	println("end")

	println("bounds[0]", map_data.bounds[0], "bounds[1]", map_data.bounds[1])

}

map_debugPrint :: proc() {
	for x : i32 = 0; x < map_data.bounds[0]; x += 1 {
		for y : i32 = 0; y < map_data.bounds[1]; y += 1 {
			fmt.print(map_data.tiles[x][y] == map_tileKind_t.WALL ? "#" : " ")
		}
		println("")
	}
}

map_drawTilemap :: proc() {
	map_drawTileBox :: proc(pos : vec3, size : vec3) {
		//rl.DrawCubeTexture(map_basetexture, pos, size.x, size.y, size.z, rl.WHITE)
		rl.DrawModelEx(cubeModel, pos, {0,1,0}, 0.0, size, rl.WHITE)
	}
	
	rl.BeginShaderMode(tileShader)
	for x : i32 = 0; x < map_data.bounds[0]; x += 1 {
		for y : i32 = 0; y < map_data.bounds[1]; y += 1 {
			posxz : vec2 = {(cast(f32)x) * TILE_WIDTH, (cast(f32)y) * TILE_WIDTH} + vec2{TILE_WIDTH/2.0, TILE_WIDTH/2.0}
			//rl.DrawCubeWires(vec3{posxz[0], 0.0, posxz[1]}, TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.GRAY)
			
			checker := cast(bool)((x%2) ~ (y%2))
			boxbuf : [PHY_MAX_TILE_BOXES]phy_box_t = {}
			boxcount := map_getTileBoxes({x, y}, boxbuf[0:])
			for i : i32 = 0; i < boxcount; i += 1 {
				map_drawTileBox(boxbuf[i].pos, boxbuf[i].size*2)
			}
		}
	}

	// draw finish
	rl.DrawCube(map_data.finishPos, MAP_TILE_FINISH_SIZE.x*2, MAP_TILE_FINISH_SIZE.y*2, MAP_TILE_FINISH_SIZE.z*2, rl.PINK)

	rl.EndShaderMode()
}




//
// PLAYER
//
// mainly player movement code
// also handles elevators etc.
//

player_lookRotEuler : vec3 = {}
player_position : vec3 = {TILE_WIDTH/2, 0, TILE_WIDTH/2}
player_isOnGround : bool
player_velocity : vec3 = {0,0.1,0.6}
player_lookdir : vec3 = {0,0,1}

PLAYER_HEAD_CENTER_OFFSET	:: 0.8
PLAYER_LOOK_SENSITIVITY		:: 0.004
PLAYER_FOV			:: 120
PLAYER_VIEWMODEL_FOV		:: 120
PLAYER_SIZE			:: vec3{1,2,1}

PLAYER_GRAVITY			:: 200 // 800
PLAYER_SPEED			:: 105 // 320
PLAYER_GROUND_ACCELERATION	:: 6 // 10
PLAYER_GROUND_FRICTION		:: 6 // 6
PLAYER_AIR_ACCELERATION		:: 0.7 // 0.7
PLAYER_AIR_FRICTION		:: 0 // 0
PLAYER_JUMP_SPEED		:: 70 // 270
PLAYER_MIN_NORMAL_Y		:: 0.25

PLAYER_FALL_DEATH_Y :: -TILE_HEIGHT

PLAYER_NOISE_SPEED :: 7.0

PLAYER_KEY_JUMP :: rl.KeyboardKey.SPACE

player_data : struct {
	rotImpulse	: vec3,
}



_player_update :: proc() {
	oldpos := player_position

	if player_position.y < PLAYER_FALL_DEATH_Y {
		player_die()
		return
	}

	if phy_boxVsBox(player_position, PLAYER_SIZE * 0.3, map_data.finishPos, MAP_TILE_FINISH_SIZE) {
		player_finishMap()
		return
	}

	player_data.rotImpulse = linalg.lerp(player_data.rotImpulse, vec3{0,0,0}, clamp(deltatime * 6.0, 0.0, 1.0))

	player_lookRotMatrix3 := linalg.matrix3_from_yaw_pitch_roll(
		player_lookRotEuler.y + player_data.rotImpulse.y,
		player_lookRotEuler.x + player_data.rotImpulse.x,
		player_lookRotEuler.z + player_data.rotImpulse.z,
	)

	forw  := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1}) * vec3{1, 0, 1})
	right := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{1, 0, 0}) * vec3{1, 0, 1})

	movedir : vec2 = {}
	if rl.IsKeyDown(rl.KeyboardKey.W)	do movedir.y += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.A)	do movedir.x += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.S)	do movedir.y -= 1.0
	if rl.IsKeyDown(rl.KeyboardKey.D)	do movedir.x -= 1.0
	//if rl.IsKeyPressed(rl.KeyboardKey.C)do player_position.y -= 2.0

	tilepos := map_worldToTile(player_position)
	c := [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
	isInElevatorTile := c in map_data.elevatorHeights

	player_velocity.y -= PLAYER_GRAVITY * deltatime // * (player_isOnGround ? 0.25 : 1.0)

	jumped := rl.IsKeyPressed(PLAYER_KEY_JUMP) && player_isOnGround
	if jumped {
		player_velocity.y = PLAYER_JUMP_SPEED
		if isInElevatorTile do player_position.y += 0.05 * PLAYER_SIZE.y
		player_isOnGround = false
	}


	player_accelerate :: proc(dir : vec3, wishspeed : f32, accel : f32) {
		currentspeed := linalg.dot(player_velocity, dir)
		addspeed := wishspeed - currentspeed
		if addspeed < 0.0 do return

		accelspeed := accel * wishspeed * deltatime
		if accelspeed > addspeed do accelspeed = addspeed

		player_velocity += dir * accelspeed
	}

	player_accelerate(forw*movedir.y + right*movedir.x, PLAYER_SPEED,
		player_isOnGround ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)

	wishpos := player_position + player_velocity * deltatime
	
	phy_tn, phy_norm, phy_hit := phy_boxCastTilemap(player_position, wishpos, PLAYER_SIZE)
	phy_vec := player_position + linalg.normalize(player_velocity)*phy_tn
	
	println("pos", player_position, "vel", player_velocity)
	//println("phy vec", phy_vec, "norm", phy_norm, "hit", phy_hit)
	
	player_position = phy_vec
	if phy_hit do player_position += phy_norm*PHY_BOXCAST_EPS*2.0

	prevIsOnGround := player_isOnGround
	player_isOnGround = phy_hit && phy_norm.y > PLAYER_MIN_NORMAL_Y && !jumped



	// elevator update
	elevatorIsMoving := false
	{
		tilepos = map_worldToTile(player_position)
		c = [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
		isInElevatorTile = c in map_data.elevatorHeights

		if isInElevatorTile {
			height := map_data.elevatorHeights[c]
			elevatorIsMoving := false

			y := math.lerp(TILE_ELEVATOR_Y0, TILE_ELEVATOR_Y1, height) + TILE_WIDTH*TILEMAP_MID/2.0 + PLAYER_SIZE.y+0.01

			if player_position.y - PLAYER_SIZE.y - 0.02 < y {
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

			if player_position.y - 0.005 < y && elevatorIsMoving {
				player_position.y = y + TILE_ELEVATOR_SPEED*deltatime
				player_velocity.y = PLAYER_GRAVITY * deltatime
			}

			if rl.IsKeyPressed(PLAYER_KEY_JUMP) && elevatorIsMoving {
				player_velocity.y += TILE_ELEVATOR_SPEED * 0.5
			}
		}
	}

	player_isOnGround |= elevatorIsMoving



	if phy_hit do player_velocity = phy_clipVelocity(player_velocity, phy_norm, !player_isOnGround && phy_hit ? 1.5 : 0.98)

	player_velocity = phy_applyFrictionToVelocity(player_velocity, player_isOnGround ? PLAYER_GROUND_FRICTION : PLAYER_AIR_FRICTION)



	cam_forw := linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1})
	player_lookdir = cam_forw // TODO: update after the new rotation has been set

	// camera
	{
		player_lookRotEuler.y += -rl.GetMouseDelta().x * PLAYER_LOOK_SENSITIVITY
		player_lookRotEuler.x += rl.GetMouseDelta().y * PLAYER_LOOK_SENSITIVITY
		player_lookRotEuler.x = clamp(player_lookRotEuler.x, -0.48 * math.PI, 0.48 * math.PI)
		player_lookRotEuler.z = math.lerp(player_lookRotEuler.z, 0.0, clamp(deltatime * 7.5, 0.0, 1.0))
		player_lookRotEuler.z -= movedir.x*deltatime*0.75
		player_lookRotEuler.z = clamp(player_lookRotEuler.z, -math.PI*0.3, math.PI*0.3)

		cam_y : f32 = PLAYER_HEAD_CENTER_OFFSET
		camera.position = player_position + camera.up * cam_y
		camera.target = camera.position + cam_forw
		camera.up = linalg.normalize(linalg.quaternion_mul_vector3(linalg.quaternion_angle_axis(player_lookRotEuler.z*1.3, cam_forw), vec3{0,1.0,0}))
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
	player_position = map_data.startPos
}

player_reset :: proc() {
	player_data.rotImpulse = {}
	player_velocity = {}
	gun_timer = 0
}

player_die :: proc() {
	println("player died")
	player_startMap()
	player_reset()
}

player_finishMap :: proc() {
	println("player finished game")
}





//
// GUNS
//
// (guns for the player, not for the enemies)
//

GUN_SCALE :: 0.7
GUN_POS_X :: 0.1

GUN_COUNT :: 3
gun_kind_t :: enum {
	SHOTGUN		= 0,
	MACHINEGUN	= 1,
	RAILGUN	= 2,
}

GUN_SHOTGUN_SPREAD		:: 0.12
GUN_SHOTGUN_DAMAGE		:: 0.1
GUN_MACHINEGUN_SPREAD		:: 0.02
GUN_MACHINEGUN_DAMAGE		:: 0.1
GUN_ROCKETLAUNCHER_DAMAGE	:: 2.0

gun_equipped : gun_kind_t = gun_kind_t.SHOTGUN
gun_timer : f32 = 0.0
// GUN_LEVEL_START_AMMO_COUNTS : [GUN_COUNT]i32{24, 0, 0} // TODO
gun_ammoCounts : [GUN_COUNT]i32 = {24, 86, 12}

gun_calcViewportPos :: proc() -> vec3 {
	s := math.sin(timepassed * math.PI * 3.0) * clamp(linalg.length(player_velocity) * 0.01, 0.0, 1.0) *
		0.04 * (player_isOnGround ? 1.0 : 0.05)
	kick := clamp(gun_timer*0.5, 0.0, 1.0)*0.8
	return vec3{-GUN_POS_X + player_lookRotEuler.z*0.5,-0.2 + s + kick*0.15, 0.2 - kick}
}

gun_calcMuzzlePos :: proc() {
	// TODO
}

gun_drawModel :: proc(pos : vec3) {
	switch gun_equipped {
		case gun_kind_t.SHOTGUN:
			rl.DrawCube(pos + {0,-0.05,-0.05}, 0.2*GUN_SCALE, 0.2*GUN_SCALE,0.3*GUN_SCALE, rl.BROWN)
			rl.DrawCube(pos + {+0.03,0,0.05}, 0.07*GUN_SCALE, 0.08*GUN_SCALE,0.35*GUN_SCALE, rl.DARKGRAY)
			rl.DrawCube(pos + {-0.03,0,0.05}, 0.07*GUN_SCALE, 0.08*GUN_SCALE,0.35*GUN_SCALE, rl.DARKGRAY)
		case gun_kind_t.MACHINEGUN:
			rl.DrawCube(pos, 0.1*GUN_SCALE, 0.15*GUN_SCALE,0.3*GUN_SCALE, rl.DARKGRAY)
			rl.DrawCube(pos + {0,0,0.1}, 0.04*GUN_SCALE, 0.04*GUN_SCALE,0.4*GUN_SCALE, rl.Color{30,30,30,255})
			rl.DrawCube(pos, 0.2*GUN_SCALE,0.1*GUN_SCALE,0.15*GUN_SCALE, rl.GRAY)
			rl.DrawCube(pos + {0,0,0.1}, 0.05*GUN_SCALE,0.2*GUN_SCALE,0.15*GUN_SCALE, rl.GRAY)
		case gun_kind_t.RAILGUN:
			rl.DrawCube(pos, 0.2*GUN_SCALE, 0.2*GUN_SCALE,0.4*GUN_SCALE, rl.Color{120, 50, 16, 255})
	}
}

_gun_update :: proc() {
	// scrool wheel gun switching
	if rl.GetMouseWheelMove() > 0.5 {
		gun_equipped = cast(gun_kind_t)((cast(u32)gun_equipped + 1) % GUN_COUNT)
	} else if rl.GetMouseWheelMove() < -0.5 {
		gun_equipped = cast(gun_kind_t)((cast(u32)gun_equipped - 1) % GUN_COUNT)
	} // keyboard gun switching
	else if rl.IsKeyPressed(rl.KeyboardKey.ONE)	do gun_equipped = gun_kind_t.SHOTGUN
	else if rl.IsKeyPressed(rl.KeyboardKey.TWO)	do gun_equipped = gun_kind_t.MACHINEGUN
	else if rl.IsKeyPressed(rl.KeyboardKey.THREE)	do gun_equipped = gun_kind_t.RAILGUN

	gun_timer -= deltatime

	gunindex := cast(i32)gun_equipped

	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) && gun_timer < 0.0 && gun_ammoCounts[gunindex] > 0 {
		switch gun_equipped {
			case gun_kind_t.SHOTGUN:
				right := linalg.cross(player_lookdir, camera.up)
				up := camera.up
				RAD :: 0.5
				COL :: vec4{1,0.7,0.3,0.3}
				DUR :: 0.8
				cl := bullet_shootRaycast(player_position, player_lookdir,							GUN_SHOTGUN_DAMAGE, DUR, COL, DUR)
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir + GUN_SHOTGUN_SPREAD*right),		GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir + GUN_SHOTGUN_SPREAD*up),			GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir - GUN_SHOTGUN_SPREAD*right),		GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir - GUN_SHOTGUN_SPREAD*up),			GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir + GUN_SHOTGUN_SPREAD*0.7*(+up + right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir + GUN_SHOTGUN_SPREAD*0.7*(+up - right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir + GUN_SHOTGUN_SPREAD*0.7*(-up + right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir + GUN_SHOTGUN_SPREAD*0.7*(-up - right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)

				player_velocity -= player_lookdir*cast(f32)(cl < PLAYER_SIZE.y ? 55.0 : 2.0)
				player_data.rotImpulse.x -= 0.15
			case gun_kind_t.MACHINEGUN:
				rnd := vec3{
					rand.float32_range(-1.0, 1.0, &randData),
					rand.float32_range(-1.0, 1.0, &randData),
					rand.float32_range(-1.0, 1.0, &randData),
				}
				bullet_shootRaycast(player_position, linalg.normalize(player_lookdir + rnd*GUN_MACHINEGUN_SPREAD), GUN_MACHINEGUN_DAMAGE, 0.5, {0.6,0.7,0.8, 0.2}, 2.0)
				if !player_isOnGround do player_velocity -= player_lookdir * 6.0
				player_data.rotImpulse.x -= 0.035
				player_data.rotImpulse -= rnd * 0.01
			case gun_kind_t.RAILGUN:
				bullet_shootRaycast(player_position, player_lookdir, GUN_ROCKETLAUNCHER_DAMAGE, 1.0, {1,0.3,0.2, 0.5}, 2.0)
				player_velocity /= 2.0
				player_data.rotImpulse.x -= 0.2
				player_data.rotImpulse.y += 0.04
		}
		gun_ammoCounts[gunindex] -= 1

		switch gun_equipped {
			case gun_kind_t.SHOTGUN:	gun_timer = 0.5
			case gun_kind_t.MACHINEGUN:	gun_timer = 0.15
			case gun_kind_t.RAILGUN:	gun_timer = 1.0
		}
	}
}







//
// BULLETS
//

BULLET_LINEAR_EFFECT_MAX_COUNT :: 64
BULLET_LINEAR_EFFECT_MESH_QUALITY :: 3 // equal to cylinder slices

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
	bullet_createLinearEffect(start, start+dir*tn, rad, col, effectDuration)
	if hit {
		switch enemykind {
			case enemy_kind_t.NONE:
			case enemy_kind_t.GRUNT:
				enemy_data.grunts[enemyindex].health -= damage
			case enemy_kind_t.KNIGHT:
				enemy_data.knights[enemyindex].health -= damage
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
	for i : i32 = 0; i < bullet_data.linearEffectsCount; i += 1 {
		fade := bullet_data.linearEffects[i].timeToLive / bullet_data.linearEffects[i].duration
		col := bullet_data.linearEffects[i].color
		rl.DrawCylinderEx(
			linalg.lerp(bullet_data.linearEffects[i].start, bullet_data.linearEffects[i].end, 0.0),
			bullet_data.linearEffects[i].end,
			fade * bullet_data.linearEffects[i].radius * bullet_data.linearEffects[i].radius * 0.5,
			fade * bullet_data.linearEffects[i].radius,
			BULLET_LINEAR_EFFECT_MESH_QUALITY,
			rl.ColorFromNormalized(vec4{col.r, col.g, col.b, col.a * fade}),
		)
	}
}






//
// ENEMIES
//

ENEMY_GRUNT_MAX_COUNT :: 32
ENEMY_KNIGHT_MAX_COUNT :: 32

ENEMY_HEALTH_MULTIPLIER :: 4

ENEMY_GRUNT_SIZE  :: vec3{3, 6, 3}
ENEMY_GRUNT_ACCELERATION :: 80.0
ENEMY_GRUNT_MAX_SPEED :: 300.0
ENEMY_GRUNT_FRICTION :: 1
ENEMY_KNIGHT_SIZE :: vec3{1.2, 3, 1.2}

enemy_kind_t :: enum u8 {
	NONE = 0,
	GRUNT,
	KNIGHT,
}

enemy_data : struct {
	gruntCount : i32,
	grunts : [ENEMY_GRUNT_MAX_COUNT]struct {
		pos		: vec3,
		attackTimer	: f32,
		target		: vec3,
		health		: f32,
		vel		: vec3,
	},

	knightCount : i32,
	knights : [ENEMY_KNIGHT_MAX_COUNT]struct {
		pos		: vec3,
		attackTimer	: f32,
		target		: vec3,
		health		: f32,
	},
}



// guy with a gun
enemy_spawnGrunt :: proc(pos : vec3) {
	index := enemy_data.gruntCount
	if index + 1 >= ENEMY_GRUNT_MAX_COUNT do return
	enemy_data.gruntCount += 1
	enemy_data.grunts[index] = {}
	enemy_data.grunts[index].pos = pos
	enemy_data.grunts[index].health = 1.0 * ENEMY_HEALTH_MULTIPLIER
}

// guy with a sword
enemy_spawnKnight :: proc(pos : vec3) {
	index := enemy_data.knightCount
	if index + 1 >= ENEMY_KNIGHT_MAX_COUNT do return
	enemy_data.knightCount += 1
	enemy_data.knights[index] = {}
	enemy_data.knights[index].pos = pos
	enemy_data.knights[index].health = 1.3 * ENEMY_HEALTH_MULTIPLIER
}



_enemy_updateDataAndRender :: proc() {
	assert(enemy_data.gruntCount  >= 0)
	assert(enemy_data.knightCount >= 0)
	assert(enemy_data.gruntCount  < ENEMY_GRUNT_MAX_COUNT)
	assert(enemy_data.knightCount < ENEMY_KNIGHT_MAX_COUNT)

	// remove dead grunts
	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		if enemy_data.grunts[i].health <= 0.0 {
			enemy_data.gruntCount -= 1
			lastindex :=  enemy_data.gruntCount
			if lastindex == i || lastindex == 0 do return
			enemy_data.grunts[i] = enemy_data.grunts[lastindex]
		}
	}

	// remove dead knights
	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		if enemy_data.knights[i].health <= 0.0 {
			enemy_data.knightCount -= 1
			lastindex :=  enemy_data.knightCount
			if lastindex == i || lastindex == 0 do return
			enemy_data.knights[i] = enemy_data.knights[lastindex]
		}
	}


	// update grunts
	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		EPS :: -1.0
		pos := enemy_data.grunts[i].pos + vec3{0, ENEMY_GRUNT_SIZE.y*0.5, 0}
		dir := linalg.normalize(player_position - pos)
		p_tn, p_hit := phy_boxCastPlayer(pos, dir, {0,0,0})
		t_tn, t_norm, t_hit := phy_boxCastTilemap(pos, pos + dir*1e6, {1,1,1})
		seeplayer := p_tn < t_tn && p_hit
		flatdir := linalg.normalize(dir * vec3{1,0,1})

		println("p_tn", p_tn, "p_hit", p_hit, "t_tn", t_tn, "t_hit", t_hit)
	
		if seeplayer {
			enemy_data.grunts[i].vel += flatdir * ENEMY_GRUNT_ACCELERATION * deltatime
		}

		if p_hit && p_tn < 3.0 { // push player back
			player_velocity = flatdir*10.0
		}
	
		enemy_data.grunts[i].vel = phy_applyFrictionToVelocity(enemy_data.grunts[i].vel, ENEMY_GRUNT_FRICTION)
		speed := linalg.length(enemy_data.grunts[i].vel)
		enemy_data.grunts[i].vel = speed < ENEMY_GRUNT_MAX_SPEED ? enemy_data.grunts[i].vel : (enemy_data.grunts[i].vel/speed)*ENEMY_GRUNT_MAX_SPEED
		enemy_data.grunts[i].pos += enemy_data.grunts[i].vel * deltatime
	}

	// update knights
	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		
	}


	// render grunts
	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		rl.DrawCube(enemy_data.grunts[i].pos, ENEMY_GRUNT_SIZE.x*2, ENEMY_GRUNT_SIZE.y*2, ENEMY_GRUNT_SIZE.z*2, rl.PINK)
	}

	// render knights
	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		rl.DrawCube(enemy_data.knights[i].pos, ENEMY_KNIGHT_SIZE.x*2, ENEMY_KNIGHT_SIZE.y*2, ENEMY_KNIGHT_SIZE.z*2, rl.PINK)
	}
}






//
// MENU UI
//

ui_drawText :: proc(pos : vec2, size : f32, color : rl.Color, text : string) {
	cstr := str.clone_to_cstring(text, context.temp_allocator)
	rl.DrawText(cstr, cast(c.int)pos.x, cast(c.int)pos.y, cast(c.int)size, color)
}





//
// PHYSICS
//
// for raycasting the map_data etc.
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


phy_getTileBox :: proc(coord : ivec2, pos : vec3) -> (phy_box_t, bool) {
	tileKind := map_data.tiles[coord[0]][coord[1]]
	posxz := vec2{cast(f32)coord[0]+0.5, cast(f32)coord[1]+0.5}*TILE_WIDTH

	#partial switch tileKind {
		case map_tileKind_t.WALL: return phy_box_t{vec3{posxz[0], 0.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}, true
		case map_tileKind_t.EMPTY:
			box : phy_box_t
			box.size = vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			box.pos = pos.y < 0.0 ? vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]} : vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}
			return box, true
	}
	return phy_box_t{}, false
}


// @returns: offset vector
phy_clipSphereWithBox :: proc(pos : vec3, rad : f32, boxSize : vec3) -> (vec3, vec3, f32, bool) {
	using math
	a := vec3{abs(pos.x), abs(pos.y), abs(pos.z)}
	q := a - boxSize
	au := a / boxSize
	possign := vec3{sign(pos.x), sign(pos.y), sign(pos.z)}
	outdir := vec3{max(0.0, q.x), max(0.0, q.y), max(0.0, q.z)}
	indir : vec3 = au.x > au.y ? (au.x > au.z ? {possign.x,0,0} : {0,0,possign.z}) : (au.y > au.z ? {0,possign.y,0} : {0,0,possign.z})
	outdir_len := linalg.length(outdir)
	sd := outdir_len + min(max(q.x, max(q.y, q.z)), 0.0)
	//isCenterInside := (q.x < 0 && q.y < 0 && q.z < 0)
	isCenterInside := sd < 0.0
	
	if sd < rad {
		//outdir /= sd == 0.0 ? 1.0 : sd
		outdir = outdir_len == 0.0 ? {} : outdir / outdir_len
		outdir *= possign
		// norm := isCenterInside ? indir : outdir
		norm := indir
		offs := isCenterInside ? indir*(-q+vec3{rad,rad,rad}) : outdir*(rad-sd)
		return offs, norm, sd, true
	}
	return {}, {}, sd, false
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

// NOTE: assumes small radius when iterating close tiles
// @returns: offset, normal, true if hit anything
phy_clipSphereWithTilemap :: proc(pos : vec3, rad : f32) -> (vec3, vec3, bool) {
	lowerleft := map_worldToTile(pos)

	res_offs := vec3{0,0,0}
	res_norm := vec3{-1,0,0}
	minsd : f32 = 1e10
	
	hit := false

	for x : i32 = 0; x <= 1; x += 1 {
		for z : i32 = 0; z <= 1; z += 1 {
			coord := lowerleft + ivec2{x, z}
			if !map_isTilePosValid(coord) do continue

			box, isfull := phy_getTileBox(coord, pos)
			if isfull {
				//rl.DrawCube(box.pos, box.size.x, box.size.y, box.size.z, rl.WHITE)
				offs, norm, sd, boxhit := phy_clipSphereWithBox(pos - box.pos, rad, box.size) // TODO: res - box.pos ?
				if boxhit {
					hit = true
					if sd < minsd {
						res_norm = norm
						sd = minsd
						res_offs = offs
					}
					// res_offs = res_offs + offs
				}
			}
		}
	}

	return res_offs, res_norm, hit
}



// "linecast" box through the map_data
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
	tileposw3 : vec3 = map_tileToWorld(lowerleft)
	tileposw : vec2 = vec2{tileposw3.x, tileposw3.z}

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

	maxdist := linelen / TILE_WIDTH

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
	
	ctx.tmin = clamp(ctx.tmin, -TILEMAP_MAX_WIDTH*TILE_WIDTH, TILEMAP_MAX_WIDTH*TILE_WIDTH)

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

	for i : i32 = 0; i < enemy_data.knightCount; i += 1 {
		tn, tf := phy_rayBoxNearFar(pos - enemy_data.knights[i].pos, dirinv, dirinvabs, ENEMY_KNIGHT_SIZE + boxsize)
		if phy_nearFarHit(tn, tf) && tn < tnear {
			tnear = tn
			res_hit = true
			res_enemykind = enemy_kind_t.KNIGHT
			res_enemyindex = i
		}
	}

	for i : i32 = 0; i < enemy_data.gruntCount; i += 1 {
		tn, tf := phy_rayBoxNearFar(pos - enemy_data.grunts[i].pos, dirinv, dirinvabs, ENEMY_GRUNT_SIZE + boxsize)
		if phy_nearFarHit(tn, tf) && tn < tnear {
			tnear = tn
			res_hit = true
			res_enemykind = enemy_kind_t.GRUNT
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
	tn, tf := phy_rayBoxNearFar(pos - player_position, dirinv, dirinvabs, PLAYER_SIZE + boxsize)
	return tn, phy_nearFarHit(tn, tf)
}


phy_boxCastWorldRes_t :: struct {
	newpos	: vec3,
	hit	: bool,
}

phy_boxCastWorld :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (res_tn : f32, res_hit : bool, res_enemykind : enemy_kind_t, res_enemyindex : i32) {
	e_tn, e_hit, e_enemykind, e_enemyindex := phy_boxCastEnemies(pos, wishpos, boxsize)
	t_tn, t_norm, t_hit := phy_boxCastTilemap(pos, wishpos, boxsize)

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
		args={loadpath, filepath.SEPARATOR_STRING, subdir, filepath.SEPARATOR_STRING, path},
		sep="",
	)
}

// temp alloc
appendToAssetPathCstr :: proc(subdir : string, path : string) -> cstring {
	return str.clone_to_cstring(appendToAssetPath(subdir, path), context.temp_allocator)
}

loadTexture :: proc(path : string) -> rl.Texture {
	fullpath := appendToAssetPathCstr("textures", path)
	println("! loading texture: ", fullpath)
	return rl.LoadTexture(fullpath)
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
