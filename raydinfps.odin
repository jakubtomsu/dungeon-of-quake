package raydinfps



import "core:math"
import "core:math/linalg"
import glslmath "core:math/linalg/glsl"
import "core:fmt"
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



camera: rl.Camera = {}

framespassed : i64 = 0
deltatime : f32 = 0.0
timepassed : f32 = 0.0
shutdownNextFrame : bool = false
loadpath : string


// gameplay entity
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
	app_init_()

	for !rl.WindowShouldClose() && !shutdownNextFrame {
		println("frame =", framespassed, "deltatime =", deltatime)
		framespassed += 1


		app_update_()


		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{20, 20, 20, 255})

		rl.BeginMode3D(camera)
		app_render3d_()
		rl.EndMode3D()
		
		app_render2d_()
		
		rl.EndDrawing()


		deltatime = rl.GetFrameTime()
		timepassed += deltatime // not really accurate but whatever
	}

	app_onExitCleanup_()
}



//
// APP
//

app_init_ :: proc() {
	rl.InitWindow(WINDOW_X, WINDOW_Y, "odiquake")
	rl.SetTargetFPS(75)

	camera.position = {0, 3, 0}
	camera.target = {}
	camera.up = vec3{0.0, 1.0, 0.0}
	camera.fovy = 120.0
	camera.projection = rl.CameraProjection.PERSPECTIVE
	rl.SetCameraMode(camera, rl.CameraMode.CUSTOM)

	loadpath = filepath.clean(string(rl.GetWorkingDirectory()))
	println("loadpath", loadpath)

	entityBuf = make(type_of(entityBuf))

	level_clear()
	tilemap.bounds = {TILEMAP_MAX_WIDTH, TILEMAP_MAX_WIDTH}
	level_load("test.oql")
	//level_print()
}

app_update_ :: proc() {
	rl.UpdateCamera(&camera)

	rl.DisableCursor()

	player_update()
}

app_render2d_ :: proc() {
	rl.DrawFPS(0, 0)

	rl.DrawRectangle(10, 10, 220, 70, rl.Fade(rl.SKYBLUE, 0.5))
	rl.DrawRectangleLines(10, 10, 220, 70, rl.BLUE)
	rl.DrawText("First person camera default controls:", 20, 20, 10, rl.BLACK)
	rl.DrawText("- Move with keys: W, A, S, D",	40, 40, 10, rl.DARKGRAY)
	rl.DrawText("- Mouse move to look around",	40, 60, 10, rl.DARKGRAY)
}

app_render3d_ :: proc() {
	rl.DrawCube(vec3{1, 0, 0}, 1,0.1,0.1, rl.RED)
	rl.DrawCube(vec3{0, 1, 0}, 0.1,1,0.1, rl.GREEN)
	rl.DrawCube(vec3{0, 0, 1}, 0.1,0.1,1, rl.BLUE)
	rl.DrawCube(vec3{0, 0, 0}, 0.1,0.1,0.1, rl.RAYWHITE)
	//rl.DrawPlane(vec3{0.0, 0.0, 0.0}, vec2{32.0, 32.0}, rl.LIGHTGRAY) // Draw ground

	// draw tilemap
	{
		for x : u32 = 0; x < tilemap.bounds[0]; x += 1 {
			for y : u32 = 0; y < tilemap.bounds[1]; y += 1 {
				posxz : vec2 = {(cast(f32)x) * TILE_SIZE, (cast(f32)y) * TILE_SIZE} + vec2{TILE_SIZE/2.0, TILE_SIZE/2.0}
				//rl.DrawCubeWires(vec3{posxz[0], 0.0, posxz[1]}, TILE_SIZE, TILE_HEIGHT, TILE_SIZE, rl.GRAY)
				#partial switch tilemap.tiles[x][y] {
					case tileKind_t.WALL:
						rl.DrawCube(vec3{posxz[0], 0.0, posxz[1]}, TILE_SIZE, TILE_HEIGHT, TILE_SIZE, rl.Color{cast(u8)x*50, cast(u8)y*50, 255, 255})
						//println("draw wall")
				}
			}
		}
	}
}

app_onExitCleanup_ :: proc() {
	rl.CloseWindow()
}


//
// TILEMAP
//

tileKind_t :: enum u8 {
	START		= 'S',
	FINISH		= 'F',
	EMPTY		= ' ',
	WALL		= '#',
	ELEVATION	= '^',
	LOW_CEIL	= 'v',
	HOLE		= 'x',
	AMMO		= 'a',
	HEALTH		= 'h',
	ENEMY_WALK	= 'w',
	ENEMY_TURRET	= 't',
}

TILEMAP_MAX_WIDTH	:: 128
TILE_SIZE		:: 2.0
TILE_HEIGHT		:: 3.0
TILE_LOW_CEIL_FACTOR	:: 0.5
TILE_ELEVATION_FACTOR	:: 0.5
TILE_LOW_CEIL_Y		:: ( TILE_HEIGHT*(1.0 - TILE_LOW_CEIL_FACTOR) ) + (-TILE_HEIGHT*TILE_LOW_CEIL_FACTOR )
TILE_ELEVATION_Y	:: (-TILE_HEIGHT*(1.0 - TILE_ELEVATION_FACTOR)) + ( TILE_HEIGHT*TILE_ELEVATION_FACTOR)
tilemap : struct {
	tiles  : [TILEMAP_MAX_WIDTH][TILEMAP_MAX_WIDTH]tileKind_t,
	bounds : [2]u32,
	start  : [2]u32,
	finish : [2]u32,
}

TMAP_toGridPos :: proc(p : vec3) -> ivec2 {
	return ivec2{cast(i32)((p.x / TILE_SIZE) - 0.5), cast(i32)((p.z / TILE_SIZE) - 0.5)}
}

TMAP_isCoordValid :: proc(coord : ivec2) -> bool {
	return coord[0] >= 0 && coord[1] >= 0 && coord[0] < TILEMAP_MAX_WIDTH && coord[1] < TILEMAP_MAX_WIDTH
}



//
// LEVEL
//

level_clear :: proc() {
	tilemap.bounds[0] = 0
	tilemap.bounds[1] = 0

	for x : u32 = 0; x < TILEMAP_MAX_WIDTH; x += 1 {
		for y : u32 = 0; y < TILEMAP_MAX_WIDTH; y += 1 {
			tilemap.tiles[x][y] = tileKind_t.WALL
		}
	}
}

level_load :: proc(name: string) {
	fullpath := filepath.clean(str.concatenate({loadpath, filepath.SEPARATOR_STRING, "level", filepath.SEPARATOR_STRING, name}))
	println("level_load fullpath", fullpath)
	data, success := os.read_entire_file_from_filename(fullpath)

	if !success {
		//shutdownNextFrame = true
		println("error: level file not found!")
		return
	}


	level_clear()


	index : i32 = 0
	x : u32 = 0
	y : u32 = 0
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
	
		tilemap.tiles[x][y] = cast(tileKind_t)ch
		x += 1

		//println(cast(tileKind_t)ch)

	}

	tilemap.bounds[1] += 1
	println("end")

	println("bounds[0]", tilemap.bounds[0], "bounds[1]", tilemap.bounds[1])

	free(&data[0])
}

level_print :: proc() {
	for x : u32 = 0; x < tilemap.bounds[0]; x += 1 {
		for y : u32 = 0; y < tilemap.bounds[1]; y += 1 {
			fmt.print(tilemap.tiles[x][y] == tileKind_t.WALL ? "#" : " ")
		}
		println("")
	}
}



//
// PHYSICS
//

phy_box_t :: struct {
	pos  : vec3,
	size : vec3,
}

//phy_sdBox :: proc(point : vec3, boxSize : vec3) -> f32 {
//	using math
//	q := vec3{abs(point.x), abs(point.y), abs(point.z)} - boxSize
//	return linalg.vector_length(vec3{max(0.0, q.x), max(0.0, q.y), max(0.0, q.z)}) + min(max(q.x, max(q.y, q.z)), 0.0)
//}

//phy_boxNormal :: proc(point : vec3, boxSize : vec3) -> (vec3, bool) {
//	using math
//	a := vec3{abs(point.x), abs(point.y), abs(point.z)}
//	q := a - boxSize
//	outside := vec3{max(0.0, q.x), max(0.0, q.y), max(0.0, q.z)}
//	inside : vec3 = a.x > a.y ? (a.x > a.z ? {a.x,0,0} : {0,0,a.z}) : (a.y > a.z ? {0,a.y,0} : {0,0,a.z})
//	isInside := (q.x < 0 && q.y < 0 && q.z < 0)
//	return linalg.vector_normalize(isInside ? inside : outside), isInside
//}

phy_getTileBox :: proc(coord : ivec2, pos : vec3) -> (phy_box_t, bool) {
	tileKind := tilemap.tiles[coord[0]][coord[1]]

	//tileMin := vec3{cast(f32)coord[0] * TILE_SIZE, -TILE_HEIGHT, cast(f32)coord[1] * TILE_SIZE}
	//tileMax := vec3{cast(f32)(coord[0] + 1) * TILE_SIZE, TILE_HEIGHT, cast(f32)(coord[1] + 1) * TILE_SIZE}

	centerxz := vec2{cast(f32)coord[0]+0.5, cast(f32)coord[1]+0.5}*TILE_SIZE

	#partial switch tileKind {
		case tileKind_t.WALL: return phy_box_t{vec3{centerxz[0], 0.0, centerxz[1]}, vec3{TILE_SIZE, TILE_HEIGHT, TILE_SIZE}/2}, true
	}
	return phy_box_t{}, false
}

phy_isSphereIntersectingTilemap :: proc(pos : vec3, rad : f32) -> bool {
	return false
}

// @returns: offset vector
phy_clipSphereWithBox :: proc(pos : vec3, rad : f32, boxSize : vec3) -> (vec3, bool) {
	using math
	a := vec3{abs(pos.x), abs(pos.y), abs(pos.z)}
	q := a - boxSize
	au := a / boxSize
	possign := vec3{sign(pos.x), sign(pos.y), sign(pos.z)}
	outdir := vec3{max(0.0, q.x), max(0.0, q.y), max(0.0, q.z)}
	indir : vec3 = au.x > au.y ? (au.x > au.z ? {possign.x,0,0} : {0,0,possign.z}) : (au.y > au.z ? {0,possign.y,0} : {0,0,possign.z})
	isCenterInside := (au.x < 1.0 && au.y < 1.0 && au.z < 1.0)//(q.x < 0 && q.y < 0 && q.z < 0)
	dist := linalg.vector_length(outdir) // positive part of SDF
	//return dist < rad ? (isCenterInside ? indir*(boxSize+vec3{rad,rad,rad}) : possign*linalg.vector_normalize(-outdir)*rad) : vec3{}
	//return dist < rad ? indir*boxSize : vec3{}
	if dist < rad {
		return isCenterInside ? indir*(boxSize + vec3{rad,rad,rad}*0.5) : possign*(outdir/dist)*(rad-dist)*rad, true
	}
	return {}, false
}

// NOTE: assumes small radius when iterating close tiles
// @returns: new pos
phy_clipSphereWithTilemap :: proc(pos : vec3, rad : f32) -> (vec3, bool) {
	lowerleft := TMAP_toGridPos(pos)

	//rl.DrawSphereWires(pos, PLAYER_RADIUS, 8, 8, rl.GREEN)
	//rl.DrawSphereWires({},  PLAYER_RADIUS, 8, 8, rl.GREEN)

	res : vec3 = pos
	hit := false

	for x : i32 = 0; x <= 1; x += 1 {
		for z : i32 = 0; z <= 1; z += 1 {
			coord := lowerleft + ivec2{x, z}
			if !TMAP_isCoordValid(coord) do continue
		
			box, isfull := phy_getTileBox(coord, pos)
			if isfull {
				println(box)
				offs, boxhit := phy_clipSphereWithBox(res - box.pos, rad, box.size) // TODO: res - box.pos ?
				res = res + offs
				hit |= boxhit

				//rl.DrawCubeWires(box.pos, box.size.x*2, box.size.y*2, box.size.z*2, rl.Fade(rl.GREEN, 1.0))
				//rl.DrawCubeWires(pos + offs, 0.1,0.1,0.1, rl.RED)
				//rl.DrawLine3D(box.pos, box.pos + offs, rl.RED)
			}
			//println("coord", coord)
			//res += phy_boxNormal(center - // TODO
		}
	}

	return res, hit
}


//
// PLAYER
//

PLAYER_RADIUS :: 0.4

PLAYER_LOOK_SENSITIVITY :: 0.005
player_lookRotEuler : vec3 = {}
player_pos : vec3 = {1,10,1}

PLAYER_GRAVITY			:: 10
PLAYER_SPEED			:: 320
PLAYER_GROUND_ACCELERATION	:: 30
PLAYER_AIR_ACCELERATION		:: 15
PLAYER_FRICTION			:: 6
PLAYER_JUMP_SPEED		:: 10

player_isGrounded : bool
player_velocity : vec3



player_clipVelocity :: proc(vel : vec3, normal : vec3, overbounce : f32) -> vec3 {
	backoff := linalg.vector_dot(vel, normal) * overbounce
	change := normal*backoff
	return vel - change
}


mouseLastX : i32
mouseLastY : i32

player_update :: proc() {
	oldpos := player_pos

	movedir : vec2 = {}

	mouseDeltaX := cast(f32)(rl.GetMouseX() - mouseLastX)
	mouseDeltaY := cast(f32)(rl.GetMouseY() - mouseLastY)
	mouseLastX = rl.GetMouseX()
	mouseLastY = rl.GetMouseY()


	player_lookRotEuler.y += -mouseDeltaX * PLAYER_LOOK_SENSITIVITY
	player_lookRotEuler.x += mouseDeltaY * PLAYER_LOOK_SENSITIVITY

	player_lookRotEuler.x = clamp(player_lookRotEuler.x, -0.48 * math.PI, 0.48 * math.PI)

	player_lookRotMatrix3 := linalg.matrix3_from_yaw_pitch_roll(player_lookRotEuler.y, player_lookRotEuler.x, player_lookRotEuler.z)


	if rl.IsKeyDown(rl.KeyboardKey.W) do movedir.y += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.A) do movedir.x += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.S) do movedir.y -= 1.0
	if rl.IsKeyDown(rl.KeyboardKey.D) do movedir.x -= 1.0

	forw  := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1}) * vec3{1, 0, 1})
	right := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{1, 0, 0}) * vec3{1, 0, 1})

	//player_pos += forw * movedir.y * deltatime
	//player_pos += right * -movedir.x * deltatime
	if rl.IsKeyDown(rl.KeyboardKey.SPACE) do player_pos.y += 1.0 * deltatime
	if rl.IsKeyDown(rl.KeyboardKey.C)     do player_pos.y -= 1.0 * deltatime
	camera.target = player_pos + linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1})
	camera.position = player_pos

	if rl.IsKeyDown(rl.KeyboardKey.SPACE) && player_isGrounded {
		player_velocity.y = PLAYER_JUMP_SPEED
	}

	if !player_isGrounded {
		player_velocity.y -= PLAYER_GRAVITY * deltatime
	}

	player_velocity += forw  * movedir.y * deltatime * cast(f32)(player_isGrounded ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)
	player_velocity += right * movedir.x * deltatime * cast(f32)(player_isGrounded ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)

	deltapos := player_velocity * deltatime
	player_pos += deltapos
	wishpos := player_pos

	player_pos, player_isGrounded = phy_clipSphereWithTilemap(player_pos, PLAYER_RADIUS)

	player_velocity *= clamp(linalg.vector_length(player_pos - oldpos) / linalg.vector_length(deltapos), 0.0, 1.0)

	//player_velocity = player_pos - oldpos
}