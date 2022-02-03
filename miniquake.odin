package miniquake



import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:c"
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
				player_update() // TODO: update player after _app_update() call. for now it's here since we need drawing for debug
				gun_update()
				_bullet_updateBufAndRender()
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
	tilemap.bounds = {TILEMAP_MAX_WIDTH, TILEMAP_MAX_WIDTH}
	map_loadFromFile("test.mqm")
	map_basetexture = loadTexture("test2.png")
	//map_debugPrint()
}

_app_update :: proc() {
	if rl.IsKeyPressed(rl.KeyboardKey.RIGHT_ALT) do debugIsEnabled = !debugIsEnabled
}

_debugtext_y : i32 = 0
_app_render2d :: proc() {
	rl.DrawFPS(0, 0)
	_debugtext_y = 2

	//rl.DrawRectangle(10, 10, 220, 70, rl.Fade(rl.SKYBLUE, 0.5))
	//rl.DrawRectangleLines(10, 10, 220, 70, rl.BLUE)
	//rl.DrawText("First person camera default controls:", 20, 20, 10, rl.BLACK)
	//rl.DrawText("- Move with keys: W, A, S, D",	40, 40, 10, rl.DARKGRAY)
	//rl.DrawText("- Mouse move to look around",	40, 60, 10, rl.DARKGRAY)

	rl.DrawRectangle(WINDOW_X/2 - 3, WINDOW_Y/2 - 3, 6, 6, rl.Fade(rl.BLACK, 0.5))
	rl.DrawRectangle(WINDOW_X/2 - 2, WINDOW_Y/2 - 2, 4, 4, rl.Fade(rl.WHITE, 0.5))

	gunindex := cast(i32)gun_equipped

	// draw ammo
	{
		ui_drawText({WINDOW_X - 150, WINDOW_Y - 50}, 20, rl.Color{255,200,50,255}, fmt.tprint("ammo: ", gun_ammoCounts[gunindex]))
	}

	if debugIsEnabled {
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
		debugtext("    bounds", tilemap.bounds)
		debugtext("gun")
		debugtext("    equipped", gun_equipped)
		debugtext("    timer", gun_timer)
		debugtext("    ammo counts", gun_ammoCounts)
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

TILE_ELEVATOR_SPEED	:: 0.7

map_basetexture : rl.Texture2D



map_tileKind_t :: enum u8 {
	EMPTY		= ' ',
	WALL		= '#',
	WALL_MID	= 'w',
	CEILING		= 'c',
	START_LOWER	= 's', // translated
	START_UPPER	= 'S', // translated
	FINISH_LOWER	= 'f', // translated
	FINISH_UPPER	= 'F', // translated
	PLATFORM	= 'p',
	ELEVATOR	= 'e',
}

tilemap : struct {
	tiles		: [TILEMAP_MAX_WIDTH][TILEMAP_MAX_WIDTH]map_tileKind_t,
	bounds		: ivec2,
	start		: ivec2,
	finish		: ivec2,
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

map_isTilePosValid :: proc(coord : ivec2) -> bool {
	return coord.x >= 0 && coord.y >= 0 && coord.x < TILEMAP_MAX_WIDTH && coord.y < TILEMAP_MAX_WIDTH && coord.x < tilemap.bounds.x && coord.y < tilemap.bounds.y
}

map_tilePosClamp :: proc(coord : ivec2) -> ivec2 {
	return ivec2{clamp(coord.x, 0, tilemap.bounds.x), clamp(coord.y, 0, tilemap.bounds.y)}
}



// fills input buffer with axis-aligned boxes for a given tile
// @returns: number of boxes for the tile
map_getTileBoxes :: proc(coord : ivec2, boxbuf : []phy_box_t) -> i32 {
	tileKind := tilemap.tiles[coord[0]][coord[1]]

	phy_calcBox :: proc(posxz : vec2, posy : f32, sizey : f32) -> phy_box_t {
		return phy_box_t{
			vec3{posxz.x, posy*TILE_WIDTH, posxz.y},
			vec3{TILE_WIDTH, sizey * TILE_WIDTH, TILE_WIDTH} / 2,
		}
	}

	posxz := vec2{cast(f32)coord[0]+0.5, cast(f32)coord[1]+0.5}*TILE_WIDTH

	#partial switch tileKind {
		case map_tileKind_t.WALL:
			boxbuf[0] = phy_box_t{vec3{posxz[0], 0.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_HEIGHT/2, TILE_WIDTH/2}}
			return 1

		case map_tileKind_t.EMPTY:
			boxsize := vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			return 2
		
		case map_tileKind_t.WALL_MID:
			boxbuf[0] = phy_calcBox(posxz, -1.5, 4)
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0}
			return 2

		case map_tileKind_t.PLATFORM:
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[2] = phy_calcBox(posxz, 0, 1)
			return 3
		
		case map_tileKind_t.CEILING:
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, vec3{TILE_WIDTH/2, TILE_MIN_HEIGHT/2, TILE_WIDTH/2}}
			boxbuf[1] = phy_calcBox(posxz, 1.5, 4)
			return 2
		
		case map_tileKind_t.ELEVATOR:
			boxsize := vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			height, ok := tilemap.elevatorHeights[{cast(u8)coord.x, cast(u8)coord.y}]
			if !ok do height = 0.0
			y0 : f32 = (-4.5)*TILE_WIDTH //-TILE_HEIGHT/2 - TILE_WIDTH
			y1 : f32 = (-1.5)*TILE_WIDTH
			boxbuf[0] = {vec3{posxz[0], math.lerp(y0, y1, height), posxz[1]}, vec3{TILE_WIDTH, TILE_WIDTH*TILEMAP_MID, TILE_WIDTH}/2}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			return 2
	}
	return 0
}



map_clearAll :: proc() {
	tilemap.bounds[0] = 0
	tilemap.bounds[1] = 0

	delete(tilemap.elevatorHeights)

	for x : u32 = 0; x < TILEMAP_MAX_WIDTH; x += 1 {
		for y : u32 = 0; y < TILEMAP_MAX_WIDTH; y += 1 {
			tilemap.tiles[x][y] = map_tileKind_t.EMPTY
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


	map_clearAll()

	tilemap.elevatorHeights = make(type_of(tilemap.elevatorHeights))


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
				tilemap.bounds[0] = max(tilemap.bounds[0], x)
				tilemap.bounds[1] = max(tilemap.bounds[1], y)
				x = 0
				continue dataloop
			case '\r':
				println("\\r")
				continue dataloop
		}
	
		tile := cast(map_tileKind_t)ch
		
		println("pre ", tile)
		#partial switch tile {
			case map_tileKind_t.START_LOWER:
				player_position = map_tileToWorld({x, y})
				tile = map_tileKind_t.EMPTY
			case map_tileKind_t.START_UPPER:
				player_position = map_tileToWorld({x, y}) + vec3{0, TILE_WIDTH, 0}
				tile = map_tileKind_t.WALL_MID

			case map_tileKind_t.FINISH_LOWER: tile = map_tileKind_t.EMPTY
			case map_tileKind_t.FINISH_UPPER: tile = map_tileKind_t.WALL_MID

			case map_tileKind_t.ELEVATOR: tilemap.elevatorHeights[{cast(u8)x, cast(u8)y}] = 0.0
		}

		tilemap.tiles[x][y] = tile
		println("post", tile)

		x += 1

		//println(cast(map_tileKind_t)ch)
	}

	tilemap.bounds[1] += 1
	println("end")

	println("bounds[0]", tilemap.bounds[0], "bounds[1]", tilemap.bounds[1])

	free(&data[0])
}

map_debugPrint :: proc() {
	for x : i32 = 0; x < tilemap.bounds[0]; x += 1 {
		for y : i32 = 0; y < tilemap.bounds[1]; y += 1 {
			fmt.print(tilemap.tiles[x][y] == map_tileKind_t.WALL ? "#" : " ")
		}
		println("")
	}
}

map_drawTilemap :: proc() {
	map_drawTileBox :: proc(pos : vec3, size : vec3) {
		rl.DrawCubeTexture(map_basetexture, pos, size.x, size.y, size.z, rl.WHITE)
	}
	
	rl.BeginShaderMode(tileShader)
	for x : i32 = 0; x < tilemap.bounds[0]; x += 1 {
		for y : i32 = 0; y < tilemap.bounds[1]; y += 1 {
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

PLAYER_RADIUS			:: 1.0
PLAYER_HEAD_CENTER_OFFSET	:: 0.8
PLAYER_LOOK_SENSITIVITY		:: 0.004
PLAYER_FOV			:: 120
PLAYER_VIEWMODEL_FOV		:: 120
PLAYER_SIZE			:: vec3{1,1,1}

PLAYER_GRAVITY			:: 200 // 800
PLAYER_SPEED			:: 100 // 320
PLAYER_GROUND_ACCELERATION	:: 10 // 10
PLAYER_GROUND_FRICTION		:: 6 // 6
PLAYER_AIR_ACCELERATION		:: 0.7 // 0.7
PLAYER_AIR_FRICTION		:: 0 // 0
PLAYER_JUMP_SPEED		:: 70 // 270
PLAYER_MIN_NORMAL_Y		:: 0.25



player_update :: proc() {
	oldpos := player_position

	player_lookRotMatrix3 := linalg.matrix3_from_yaw_pitch_roll(player_lookRotEuler.y, player_lookRotEuler.x, player_lookRotEuler.z)

	forw  := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1}) * vec3{1, 0, 1})
	right := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{1, 0, 0}) * vec3{1, 0, 1})

	movedir : vec2 = {}
	if rl.IsKeyDown(rl.KeyboardKey.W)	do movedir.y += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.A)	do movedir.x += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.S)	do movedir.y -= 1.0
	if rl.IsKeyDown(rl.KeyboardKey.D)	do movedir.x -= 1.0
	if rl.IsKeyPressed(rl.KeyboardKey.C)do player_position.y -= 2.0

	tilepos := map_worldToTile(player_position)
	c := [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
	isInElevatorTile := c in tilemap.elevatorHeights

	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) && (player_isOnGround || isInElevatorTile) {
		player_velocity.y = PLAYER_JUMP_SPEED
		if isInElevatorTile do player_position.y += 0.01
	}

	player_velocity.y -= PLAYER_GRAVITY * deltatime // * (player_isOnGround ? 0.25 : 1.0)

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
	
	phy_vec, phy_norm, phy_hit := phy_boxCastTilemap(player_position, wishpos, PLAYER_SIZE)
	
	println("pos", player_position, "vel", player_velocity)
	//println("phy vec", phy_vec, "norm", phy_norm, "hit", phy_hit)
	
	player_position = phy_vec
	if phy_hit do player_position += phy_norm*PHY_BOXCAST_EPS*2.0

	player_isOnGround = phy_hit && phy_norm.y > PLAYER_MIN_NORMAL_Y


	if phy_hit do player_velocity = player_clipVelocity(player_velocity, phy_norm, !player_isOnGround && phy_hit ? 1.5 : 0.98)

	player_velocity = player_friction(player_velocity, player_isOnGround ? PLAYER_GROUND_FRICTION : PLAYER_AIR_FRICTION)



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

	tilepos = map_worldToTile(player_position)
	c = [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
	isInElevatorTile = c in tilemap.elevatorHeights

	if isInElevatorTile {
		height := tilemap.elevatorHeights[c]
		moving := true
		height += TILE_ELEVATOR_SPEED * deltatime
		if height > 1.0 {
			height = 1.0
			moving = false
		} else if height < 0.0 {
			height = 0.0
			moving = false
		}
		
		tilemap.elevatorHeights[c] = height
	
		y0 : f32 = (-4.5)*TILE_WIDTH
		y1 : f32 = (-1.5)*TILE_WIDTH
		y := math.lerp(y0, y1, height) + TILE_WIDTH*TILEMAP_MID/2.0 + PLAYER_SIZE.y+0.01
		if player_position.y - 0.01 < y && moving {
			player_position.y = y
			//if !player_isOnGround do player_velocity = player_friction(player_velocity, PLAYER_GROUND_FRICTION * 0.3)
			player_velocity.y = PLAYER_GRAVITY * deltatime
		}
	}

	{
		size := vec3{1,1,1}
		pos, normal, tmin := phy_boxCastTilemap(
			camera.position, camera.position + cam_forw*1000.0, size*0.5)
		rl.DrawCube(pos, size.x, size.y, size.z, rl.YELLOW)
		rl.DrawLine3D(pos, pos + normal*4, rl.ORANGE)
	}


	if debugIsEnabled {
		rl.DrawCubeWires(map_tileToWorld(tilepos), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, {0,255,0,100})
	}

	player_clipVelocity :: proc(vel : vec3, normal : vec3, overbounce : f32) -> vec3 {
		backoff := linalg.vector_dot(vel, normal) * overbounce
		change := normal*backoff
		return vel - change
	}

	player_friction :: proc(vel : vec3, friction : f32) -> vec3 {
		len := linalg.vector_length(vel)
		drop := len * friction * deltatime
		return (len == 0.0 ? {} : vel / len) * (len - drop)
	}

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
	ROCKETLAUNCHER	= 2,
}

gun_equipped : gun_kind_t = gun_kind_t.SHOTGUN
gun_timer : f32 = 0.0
gun_ammoCounts : [GUN_COUNT]i32 = {24, 86, 12}

gun_calcViewportPos :: proc() -> vec3 {
	s := math.sin(timepassed * math.PI * 3.0) * clamp(linalg.length(player_velocity) * 0.01, 0.0, 1.0) *
		0.04 * (player_isOnGround ? 1.0 : 0.05)
	return vec3{-GUN_POS_X + player_lookRotEuler.z*0.5,-0.2 + s, 0.2}
}

gun_calcMuzzlePos :: proc() {

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
		case gun_kind_t.ROCKETLAUNCHER:
			rl.DrawCube(pos, 0.2*GUN_SCALE, 0.2*GUN_SCALE,0.4*GUN_SCALE, rl.Color{120, 50, 16, 255})
	}
}

gun_update :: proc() {
	// scrool wheel gun switching
	if rl.GetMouseWheelMove() > 0.5 {
		gun_equipped = cast(gun_kind_t)((cast(u32)gun_equipped + 1) % GUN_COUNT)
	} else if rl.GetMouseWheelMove() < -0.5 {
		gun_equipped = cast(gun_kind_t)((cast(u32)gun_equipped - 1) % GUN_COUNT)
	} // keyboard gun switching
	else if rl.IsKeyPressed(rl.KeyboardKey.ONE)	do gun_equipped = gun_kind_t.SHOTGUN
	else if rl.IsKeyPressed(rl.KeyboardKey.TWO)	do gun_equipped = gun_kind_t.MACHINEGUN
	else if rl.IsKeyPressed(rl.KeyboardKey.THREE)	do gun_equipped = gun_kind_t.ROCKETLAUNCHER

	gun_timer -= deltatime

	gunindex := cast(i32)gun_equipped

	if rl.IsMouseButtonDown(rl.MouseButton.LEFT) && gun_timer < 0.0 && gun_ammoCounts[gunindex] > 0 {
		switch gun_equipped {
			case gun_kind_t.SHOTGUN:
				bullet_shootRaycast(player_position, player_lookdir, 1.0, 0.6, {1,0.5,0,0.5}, 1.2)
			case gun_kind_t.MACHINEGUN:
				bullet_shootRaycast(player_position, player_lookdir, 1.0, 0.5, {0.6,0.7,0.8, 0.5}, 1.0)
			case gun_kind_t.ROCKETLAUNCHER:
				bullet_shootRaycast(player_position, player_lookdir, 1.0, 1.0, {1,0.5,0, 0.5}, 2.0)
		}
		gun_ammoCounts[gunindex] -= 1

		switch gun_equipped {
			case gun_kind_t.SHOTGUN:	gun_timer = 0.6
			case gun_kind_t.MACHINEGUN:	gun_timer = 0.15
			case gun_kind_t.ROCKETLAUNCHER:	gun_timer = 1.0
		}
	}
}






//
// BULLETS
//

BULLET_LINEAR_EFFECT_MAX_COUNT :: 64
BULLET_LINEAR_EFFECT_MESH_QUALITY :: 4 // equal to cylinder slices

bullet_ammoInfo_t :: struct {
	damage : f32,
	knockback : f32,
}

bulletBuf : struct {
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
	if bulletBuf.linearEffectsCount >= BULLET_LINEAR_EFFECT_MAX_COUNT do return
	if duration <= 0.0 do return
	index := bulletBuf.linearEffectsCount
	bulletBuf.linearEffectsCount += 1
	bulletBuf.linearEffects[index].start		= start
	bulletBuf.linearEffects[index].timeToLive	= duration
	bulletBuf.linearEffects[index].end		= end
	bulletBuf.linearEffects[index].radius		= rad
	bulletBuf.linearEffects[index].color		= col
	bulletBuf.linearEffects[index].duration		= duration
}

bullet_shootRaycast :: proc(start : vec3, dir : vec3, damage : f32, rad : f32, col : vec4, effectDuration : f32) {
	phy_vec, phy_norm, phy_hit := phy_boxCastTilemap(start, start + dir*1e6, vec3{rad,rad,rad})
	bullet_createLinearEffect(start, phy_vec, rad, col, effectDuration)
}

bullet_shootProjectile :: proc(start : vec3, dir : vec3, damage : f32, rad : f32, col : vec4) {

}

_bullet_updateBufAndRender :: proc() {
	assert(bulletBuf.linearEffectsCount >= 0)
	assert(bulletBuf.linearEffectsCount < BULLET_LINEAR_EFFECT_MAX_COUNT)

	// remove old
	loopremove : for i : i32 = 0; i < bulletBuf.linearEffectsCount; i += 1 {
		bulletBuf.linearEffects[i].timeToLive -= deltatime
		if bulletBuf.linearEffects[i].timeToLive <= 0.0 { // needs to be removed
			if i + 1 >= bulletBuf.linearEffectsCount { // we're on the last one
				bulletBuf.linearEffectsCount -= 1
				break loopremove
			}
			lastindex := bulletBuf.linearEffectsCount - 1
			bulletBuf.linearEffects[i] = bulletBuf.linearEffects[lastindex]
		}
	}

	// draw
	for i : i32 = 0; i < bulletBuf.linearEffectsCount; i += 1 {
		fade := bulletBuf.linearEffects[i].timeToLive / bulletBuf.linearEffects[i].duration
		col := bulletBuf.linearEffects[i].color
		rl.DrawCylinderEx(
			bulletBuf.linearEffects[i].start,
			bulletBuf.linearEffects[i].end,
			fade * bulletBuf.linearEffects[i].radius * bulletBuf.linearEffects[i].radius * 0.5,
			fade * bulletBuf.linearEffects[i].radius,
			BULLET_LINEAR_EFFECT_MESH_QUALITY,
			rl.ColorFromNormalized(vec4{col.r, col.g, col.b, col.a * fade}),
		)
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
// for raycasting the tilemap etc.
//

PHY_MAX_TILE_BOXES :: 4
PHY_BOXCAST_EPS :: 1e-2



phy_box_t :: struct {
	pos  : vec3,
	size : vec3,
}



phy_getTileBox :: proc(coord : ivec2, pos : vec3) -> (phy_box_t, bool) {
	tileKind := tilemap.tiles[coord[0]][coord[1]]
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



// "linecast" box through the tilemap
// ! boxsize < TILE_WIDTH
// @returns: newpos, normal, tmin
phy_boxCastTilemap :: proc(pos : vec3, wishpos : vec3, boxsize : vec3) -> (vec3, vec3, bool) {
	using math
	posxz := vec2{pos.x, pos.z}
	dir := wishpos - pos
	if !map_isTilePosValid(map_worldToTile(pos)) do return wishpos, {0,0.1,0}, false
	lowerleft := map_tilePosClamp(map_worldToTile(pos - vec3{dir.x>0.0 ? 1.0:-1.0, 0.0, dir.z>0.0 ? 1.0:-1.0}*TILE_WIDTH))
	tilepos := lowerleft
	tileposw3 : vec3 = map_tileToWorld(lowerleft)
	tileposw : vec2 = vec2{tileposw3.x, tileposw3.z}

	linelen := linalg.length(dir)
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

			//rl.DrawCube(box.pos, box.size.x*2, box.size.y*2, box.size.z*2, rl.Fade(rl.GREEN, 0.1))

			n := ctx.dirinv * (ctx.pos - box.pos)
			k := ctx.dirinvabs * (box.size + ctx.boxoffs)
			t1 := -n - k
			t2 := -n + k
			tn := max(max(t1.x, t1.y), t1.z)
			tf := min(min(t2.x, t2.y), t2.z)

			println("tn", tn, "tf", tf)

			if tn>tf || tf<0.0 do continue // no intersection (inside counts as intersection)
			if tn>ctx.tmin do continue // this hit is worse than the one we already have
			//if tn>ctx.tmin || tf<PHY_BOXCAST_EPS || (tn<-PHY_BOXCAST_EPS && tf<PHY_BOXCAST_EPS) {
			//	continue
			//}

			if math.is_nan(tn) || math.is_nan(tf) || math.is_inf(tn) || math.is_inf(tf) do continue

			println("ok")
		
			ctx.tmin = tn
			ctx.normal = -ctx.dirsign * cast(vec3)(glsl.step(glsl.vec3{t1.y,t1.z,t1.x}, glsl.vec3{t1.x,t1.y,t1.z}) * glsl.step(glsl.vec3{t1.z,t1.x,t1.y}, glsl.vec3{t1.x,t1.y,t1.z}))
			ctx.hit = true

		}
	}
	
	ctx.tmin = clamp(ctx.tmin, -TILEMAP_MAX_WIDTH*TILE_WIDTH, TILEMAP_MAX_WIDTH*TILE_WIDTH)

	return pos + dir*ctx.tmin, ctx.normal, ctx.hit
}






//
// HELPER PROCEDURES
//

// temp alloc
assetPathCstr :: proc(subdir : string, path : string) -> cstring {
	return str.clone_to_cstring(
		fmt.tprint(
			args = {loadpath, filepath.SEPARATOR_STRING, subdir, filepath.SEPARATOR_STRING, path},
			sep="",
		),
		context.temp_allocator,
	)
}

loadTexture :: proc(path : string) -> rl.Texture {
	fullpath := assetPathCstr("textures", path)
	println("! loading texture: ", fullpath)
	return rl.LoadTexture(fullpath)
}

loadShader :: proc(vertpath : string, fragpath : string) -> rl.Shader {
	vertfullpath := assetPathCstr("shaders", vertpath)
	fragfullpath := assetPathCstr("shaders", fragpath)
	println("! loading shader: vert: ", vertfullpath, "frag:", fragfullpath)
	return rl.LoadShader(vertfullpath, fragfullpath)
}

// uses default vertex shader
loadFragShader :: proc(path : string) -> rl.Shader {
	fullpath := assetPathCstr("shaders", path)
	println("! loading shader: ", fullpath)
	return rl.LoadShader(nil, fullpath)
}
