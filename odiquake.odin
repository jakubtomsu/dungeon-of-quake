package odiquake



import math "core:math"
import linalg "core:math/linalg"
import fmt "core:fmt"
RAYLIB_USE_LINALG :: true
import rl "vendor:raylib"
import os "core:os"
import filepath "core:path/filepath"
import str "core:strings"
//import win32 "core:sys/win32"



println :: fmt.println
vec2 :: rl.Vector2
vec3 :: rl.Vector3
vec4 :: rl.Vector4



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

TILEMAP_MAX_WIDTH :: 128
TILE_SIZE :: 1.0
TILE_HEIGHT :: 1.0
tilemap : struct {
	tiles : [TILEMAP_MAX_WIDTH][TILEMAP_MAX_WIDTH]tileKind_t,
	bounds : [2]u32,
	start  : [2]u32,
	finish : [2]u32,
}


PLAYER_LOOK_SENSITIVITY :: 0.005
player_lookRotEuler : vec3 = {}
player_pos : vec3 = {}



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



app_init_ :: proc() {
	rl.InitWindow(WINDOW_X, WINDOW_Y, "minifps")
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

mouseLastX : i32
mouseLastY : i32

app_update_ :: proc() {
	rl.UpdateCamera(&camera)

	rl.DisableCursor()

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
	if rl.IsKeyDown(rl.KeyboardKey.A) do movedir.x -= 1.0
	if rl.IsKeyDown(rl.KeyboardKey.S) do movedir.y -= 1.0
	if rl.IsKeyDown(rl.KeyboardKey.D) do movedir.x += 1.0

	forw  := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1}) * vec3{1, 0, 1})
	right := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{1, 0, 0}) * vec3{1, 0, 1})

	player_pos += forw * movedir.y * deltatime
	player_pos += right * -movedir.x * deltatime
	if rl.IsKeyDown(rl.KeyboardKey.SPACE) do player_pos.y += 1.0 * deltatime
	camera.target = player_pos + linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1})
	camera.position = player_pos
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
				posxz : vec2 = {(cast(f32)x) * TILE_SIZE, (cast(f32)y) * TILE_SIZE}
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


	// NOTE: the level gets spawned as we read the level
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
	
		tilemap.tiles[x][y] = cast(tileKind_t)ch;
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