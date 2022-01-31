package qfps



import "core:math"
import "core:math/linalg"
//import glslmath "core:math/linalg/glsl"
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
app_shouldExitNextFrame : bool = false
loadpath : string

rendertextureMain : rl.RenderTexture2D
postprocessShader : rl.Shader
tileShader : rl.Shader

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
	app_init_()

	for !rl.WindowShouldClose() && !app_shouldExitNextFrame {
		println("frame =", framespassed, "deltatime =", deltatime)
		framespassed += 1


		app_update_()


		rl.BeginTextureMode(rendertextureMain)
			rl.ClearBackground(rl.DARKGRAY)

			rl.BeginMode3D(camera)
				app_render3d_()
				player_update()
			rl.EndMode3D()
		rl.EndTextureMode()
		
		rl.BeginDrawing()
			rl.ClearBackground(rl.PINK)
			rl.BeginShaderMode(postprocessShader)
				rl.DrawTextureRec(rendertextureMain.texture, rl.Rectangle{0, 0, cast(f32)rendertextureMain.texture.width, -cast(f32)rendertextureMain.texture.height}, {0, 0}, rl.WHITE)
			rl.EndShaderMode()

			app_render2d_()
		rl.EndDrawing()


		deltatime = rl.GetFrameTime()
		timepassed += deltatime // not really accurate but whatever
	}

	rl.CloseWindow()
}



//
// APP
//

app_init_ :: proc() {
	rl.InitWindow(WINDOW_X, WINDOW_Y, "qfps")
	rl.SetTargetFPS(75)
	loadpath = filepath.clean(string(rl.GetWorkingDirectory()))
	println("loadpath", loadpath)

	rendertextureMain = rl.LoadRenderTexture(WINDOW_X, WINDOW_Y)
	postprocessShader = loadFragShader("postprocess.glsl")
	tileShader = loadFragShader("tile.frag")

	camera.position = {0, 3, 0}
	camera.target = {}
	camera.up = vec3{0.0, 1.0, 0.0}
	camera.fovy = 120.0
	camera.projection = rl.CameraProjection.PERSPECTIVE
	rl.SetCameraMode(camera, rl.CameraMode.CUSTOM)

	entityBuf = make(type_of(entityBuf))

	map_clearAll()
	tilemap.bounds = {TILEMAP_MAX_WIDTH, TILEMAP_MAX_WIDTH}
	map_loadFromFile("test.qfmap")
	map_basetexture = loadTexture("test4.png")
	//map_debugPrint()
}

app_update_ :: proc() {
	rl.UpdateCamera(&camera)

	rl.DisableCursor()

	//player_update()
}

debugtext_y_ : i32 = 0
app_render2d_ :: proc() {
	rl.DrawFPS(0, 0)
	debugtext_y_ = 2

	//rl.DrawRectangle(10, 10, 220, 70, rl.Fade(rl.SKYBLUE, 0.5))
	//rl.DrawRectangleLines(10, 10, 220, 70, rl.BLUE)
	//rl.DrawText("First person camera default controls:", 20, 20, 10, rl.BLACK)
	//rl.DrawText("- Move with keys: W, A, S, D",	40, 40, 10, rl.DARKGRAY)
	//rl.DrawText("- Mouse move to look around",	40, 60, 10, rl.DARKGRAY)

	debugtext :: proc(args: ..any) {
		tstr := fmt.tprint(args=args)
		cstr := str.clone_to_cstring(tstr, context.temp_allocator)
		rl.DrawText(cstr, 6, debugtext_y_ * 12, 10, rl.Fade(rl.WHITE, 0.8))
		debugtext_y_ += 1
	}

	debugtext("player")
	debugtext("    pos", player_pos)
	debugtext("    vel", player_velocity)
	debugtext("    onground", player_isOnGround)
}

app_render3d_ :: proc() {
	rl.DrawCube(vec3{1, 0, 0}, 1,0.1,0.1, rl.RED)
	rl.DrawCube(vec3{0, 1, 0}, 0.1,1,0.1, rl.GREEN)
	rl.DrawCube(vec3{0, 0, 1}, 0.1,0.1,1, rl.BLUE)
	rl.DrawCube(vec3{0, 0, 0}, 0.1,0.1,0.1, rl.RAYWHITE)
	//rl.DrawPlane(vec3{0.0, 0.0, 0.0}, vec2{32.0, 32.0}, rl.LIGHTGRAY) // Draw ground

	// draw tilemap
	{
		for x : i32 = 0; x < tilemap.bounds[0]; x += 1 {
			for y : i32 = 0; y < tilemap.bounds[1]; y += 1 {
				posxz : vec2 = {(cast(f32)x) * TILE_SIZE, (cast(f32)y) * TILE_SIZE} + vec2{TILE_SIZE/2.0, TILE_SIZE/2.0}
				//rl.DrawCubeWires(vec3{posxz[0], 0.0, posxz[1]}, TILE_SIZE, TILE_HEIGHT, TILE_SIZE, rl.GRAY)
				
				rl.BeginShaderMode(tileShader)
				checker := cast(bool)((x%2) ~ (y%2))
				#partial switch tilemap.tiles[x][y] {
					case map_tileKind_t.WALL:
						pos := vec3{posxz[0], 0.0, posxz[1]}
						//rl.DrawCube(pos, TILE_SIZE, TILE_HEIGHT, TILE_SIZE, rl.Color{cast(u8)x*50, cast(u8)y*50, 255, 255})
						rl.DrawCubeTexture(map_basetexture, pos, TILE_SIZE, TILE_HEIGHT, TILE_SIZE, rl.WHITE)
					case map_tileKind_t.EMPTY:
						pos0 := vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}
						pos1 := vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}
						size := vec3{TILE_SIZE, TILE_MIN_HEIGHT, TILE_SIZE}
						//rl.DrawCube(pos0, size.x, size.y, size.z, checker ? rl.RED : rl.PINK)
						//rl.DrawCube(pos1, size.x, size.y, size.z, checker ? rl.GREEN : rl.BLUE)
						rl.DrawCubeTexture(map_basetexture, pos0, size.x, size.y, size.z, rl.WHITE)
						rl.DrawCubeTexture(map_basetexture, pos1, size.x, size.y, size.z, rl.WHITE)
				}
				rl.EndShaderMode()
			}
		}
	}
}



// temp alloc
assetPathCstr :: proc(subdir : string, path : string) -> cstring {
	return str.clone_to_cstring(fmt.tprint(args = {loadpath, filepath.SEPARATOR_STRING, subdir, filepath.SEPARATOR_STRING, path}, sep=""), context.temp_allocator)
}

loadTexture :: proc(path : string) -> rl.Texture {
	fullpath := assetPathCstr("textures", path)
	println("! loading texture: ", fullpath)
	return rl.LoadTexture(fullpath)
}

//loadShader :: proc(vertpath : string, fragpath : string) -> rl.Shader {
//	vertfullpath := assetPathCstr("shaders", vertpath)
//	fragfullpath := assetPathCstr("shaders", fragpath)
//	println("! loading shader: vert: ", vertfullpath, "frag:", fragfullpath)
//	return rl.LoadShader(vertfullpath, fragfullpath)
//}

// uses default vertex shader
loadFragShader :: proc(path : string) -> rl.Shader {
	fullpath := assetPathCstr("shaders", path)
	println("! loading shader: ", fullpath)
	return rl.LoadShader(nil, fullpath)
}



//
// MAP
//

map_tileKind_t :: enum u8 {
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
TILE_SIZE		:: 30.0
TILE_MIN_HEIGHT		:: TILE_SIZE
TILE_HEIGHT		:: TILE_SIZE * 7
TILE_LOW_CEIL_FACTOR	:: 0.5
TILE_ELEVATION_FACTOR	:: 0.5
TILE_LOW_CEIL_Y		:: ( TILE_HEIGHT*(1.0 - TILE_LOW_CEIL_FACTOR) ) + (-TILE_HEIGHT*TILE_LOW_CEIL_FACTOR )
TILE_ELEVATION_Y	:: (-TILE_HEIGHT*(1.0 - TILE_ELEVATION_FACTOR)) + ( TILE_HEIGHT*TILE_ELEVATION_FACTOR)
tilemap : struct {
	tiles  : [TILEMAP_MAX_WIDTH][TILEMAP_MAX_WIDTH]map_tileKind_t,
	bounds : [2]i32,
	start  : [2]i32,
	finish : [2]i32,
}

map_basetexture : rl.Texture2D

map_worldToTile :: proc(p : vec3) -> ivec2 {
	return ivec2{cast(i32)((p.x / TILE_SIZE) - 0.5), cast(i32)((p.z / TILE_SIZE) - 0.5)}
}

// @returns: tile center position in worldspace
map_tileToWorld :: proc(p : ivec2) -> vec3 {
	return vec3{((cast(f32)p[0]) + 0.5) * TILE_SIZE, 0.0, ((cast(f32)p[1]) + 0.5) * TILE_SIZE}
}

map_isTilePosValid :: proc(coord : ivec2) -> bool {
	return coord[0] >= 0 && coord[1] >= 0 && coord[0] < TILEMAP_MAX_WIDTH && coord[1] < TILEMAP_MAX_WIDTH
}



map_clearAll :: proc() {
	tilemap.bounds[0] = 0
	tilemap.bounds[1] = 0

	for x : u32 = 0; x < TILEMAP_MAX_WIDTH; x += 1 {
		for y : u32 = 0; y < TILEMAP_MAX_WIDTH; y += 1 {
			tilemap.tiles[x][y] = map_tileKind_t.EMPTY
		}
	}
}

map_loadFromFile :: proc(name: string) {
	fullpath := filepath.clean(str.concatenate({loadpath, filepath.SEPARATOR_STRING, "levels", filepath.SEPARATOR_STRING, name}))
	println("! loading map: ", fullpath)
	data, success := os.read_entire_file_from_filename(fullpath)

	if !success {
		//app_shouldExitNextFrame = true
		println("! error: level file not found!")
		return
	}


	map_clearAll()


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
		
		#partial switch tile {
			case map_tileKind_t.START:
				player_pos = map_tileToWorld({x, y})
				tile = map_tileKind_t.EMPTY
		}

		tilemap.tiles[x][y] = tile

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






//
// PHYSICS
//

phy_box_t :: struct {
	pos  : vec3,
	size : vec3,
}

phy_getTileBox :: proc(coord : ivec2, pos : vec3) -> (phy_box_t, bool) {
	tileKind := tilemap.tiles[coord[0]][coord[1]]

	//tileMin := vec3{cast(f32)coord[0] * TILE_SIZE, -TILE_HEIGHT, cast(f32)coord[1] * TILE_SIZE}
	//tileMax := vec3{cast(f32)(coord[0] + 1) * TILE_SIZE, TILE_HEIGHT, cast(f32)(coord[1] + 1) * TILE_SIZE}

	posxz := vec2{cast(f32)coord[0]+0.5, cast(f32)coord[1]+0.5}*TILE_SIZE

	#partial switch tileKind {
		case map_tileKind_t.WALL: return phy_box_t{vec3{posxz[0], 0.0, posxz[1]}, vec3{TILE_SIZE, TILE_HEIGHT, TILE_SIZE}/2}, true
		case map_tileKind_t.EMPTY:
			box : phy_box_t
			box.size = vec3{TILE_SIZE, TILE_MIN_HEIGHT, TILE_SIZE}/2.0
			box.pos = pos.y < 0.0 ? vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]} : vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}
			return box, true
	}
	return phy_box_t{}, false
}

phy_isSphereIntersectingTilemap :: proc(pos : vec3, rad : f32) -> bool {
	return false
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
				rl.DrawCube(box.pos, box.size.x, box.size.y, box.size.z, rl.WHITE)
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





//
// PLAYER
//

player_lookRotEuler : vec3 = {}
player_pos : vec3 = {TILE_SIZE/2, 0, TILE_SIZE/2}
player_isOnGround : bool
player_velocity : vec3

PLAYER_RADIUS			:: 1.0
PLAYER_HEAD_CENTER_OFFSET	:: 0.8
PLAYER_LOOK_SENSITIVITY		:: 0.004

PLAYER_GRAVITY			:: 100 // 800
PLAYER_SPEED			:: 100 // 320
PLAYER_GROUND_ACCELERATION	:: 10
PLAYER_GROUND_FRICTION		:: 4 // 6
PLAYER_AIR_ACCELERATION		:: 0.7
PLAYER_AIR_FRICTION		:: 0
PLAYER_JUMP_SPEED		:: 37 // 270
PLAYER_MIN_NORMAL_Y		:: 0.25



mouseLastX : i32
mouseLastY : i32

player_update :: proc() {
	oldpos := player_pos

	rl.DrawSphere(player_pos, PLAYER_RADIUS, rl.PINK)

	//{
	//	bpos := vec3{TILE_SIZE*2,0,TILE_SIZE*2}
	//	bsize := vec3{15, 5, 15}
	//	spos := vec3{math.sin(timepassed), math.cos(timepassed), 0.0}*6.0 + bpos
	//	srad : f32 = 1.0
	//	rl.DrawSphereWires(spos, srad, 10, 10, rl.DARKGRAY)
	//	offs, norm, sd, hit := phy_clipSphereWithBox(spos - bpos, srad, bsize * 0.5)
	//	if hit {
	//		rl.DrawSphereWires(spos + offs, srad, 10, 10, rl.YELLOW)
	//	}
	//	println("sd",sd)
	//	rl.DrawCubeWires(bpos, bsize.x, bsize.y, bsize.z,         rl.ORANGE      )
	//	rl.DrawCube     (bpos, bsize.x, bsize.y, bsize.z, rl.Fade(rl.ORANGE, 0.5))
	//}

	mouseDeltaX := cast(f32)(rl.GetMouseX() - mouseLastX)
	mouseDeltaY := cast(f32)(rl.GetMouseY() - mouseLastY)
	mouseLastX = rl.GetMouseX()
	mouseLastY = rl.GetMouseY()


	player_lookRotMatrix3 := linalg.matrix3_from_yaw_pitch_roll(player_lookRotEuler.y, player_lookRotEuler.x, player_lookRotEuler.z)

	forw  := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1}) * vec3{1, 0, 1})
	right := linalg.vector_normalize(linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{1, 0, 0}) * vec3{1, 0, 1})

	movedir : vec2 = {}
	if rl.IsKeyDown(rl.KeyboardKey.W)	do movedir.y += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.A)	do movedir.x += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.S)	do movedir.y -= 1.0
	if rl.IsKeyDown(rl.KeyboardKey.D)	do movedir.x -= 1.0
	//if rl.IsKeyPressed(rl.KeyboardKey.C)	do player_pos.y -= 1.0


	if rl.IsKeyPressed(rl.KeyboardKey.SPACE) && player_isOnGround {
		player_velocity.y = PLAYER_JUMP_SPEED
	}

	player_velocity.y -= PLAYER_GRAVITY * deltatime * (player_isOnGround ? 0.25 : 1.0)

	player_accelerate :: proc(dir : vec3, wishspeed : f32, accel : f32) {
		currentspeed := linalg.dot(player_velocity, dir)
		addspeed := wishspeed - currentspeed
		if addspeed < 0.0 do return

		accelspeed := accel * wishspeed * deltatime
		if accelspeed > addspeed do accelspeed = addspeed

		player_velocity += dir * accelspeed
	}

	//player_velocity += forw  * movedir.y * deltatime * cast(f32)(player_isOnGround ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)
	//player_velocity += right * movedir.x * deltatime * cast(f32)(player_isOnGround ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)

	player_accelerate(forw*movedir.y + right*movedir.x, PLAYER_SPEED, player_isOnGround ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)

	player_pos += player_velocity * deltatime
	
	phy_vec, phy_norm, phy_hit := phy_clipSphereWithTilemap(player_pos, PLAYER_RADIUS)
	
	println("pos", player_pos, "vel", player_velocity)
	println("phy offs", phy_vec, "norm", phy_norm, "hit", phy_hit)
	
	if phy_hit do player_pos = player_pos + phy_vec
	
	player_isOnGround = phy_hit && phy_norm.y > PLAYER_MIN_NORMAL_Y

	// friction
	{
		len := linalg.vector_length(player_velocity)
		friction : f32 = player_isOnGround ? PLAYER_GROUND_FRICTION : PLAYER_AIR_FRICTION
		drop := len * friction * deltatime
		player_velocity = (len == 0.0 ? {} : player_velocity / len) * (len - drop)
	}


	player_clipVelocity :: proc(vel : vec3, normal : vec3, overbounce : f32) -> vec3 {
		backoff := linalg.vector_dot(vel, normal) * overbounce
		change := normal*backoff
		return vel - change
	}


	if phy_hit do player_velocity = player_clipVelocity(player_velocity, phy_norm, 1.0)



	// camera
	{
		player_lookRotEuler.y += -mouseDeltaX * PLAYER_LOOK_SENSITIVITY
		player_lookRotEuler.x += mouseDeltaY * PLAYER_LOOK_SENSITIVITY
		player_lookRotEuler.x = clamp(player_lookRotEuler.x, -0.48 * math.PI, 0.48 * math.PI)
		player_lookRotEuler.z = math.lerp(player_lookRotEuler.z, 0.0, clamp(deltatime * 7.5, 0.0, 1.0))
		player_lookRotEuler.z -= movedir.x * deltatime * 0.75

		cam_forw := linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1})
		cam_y : f32 = PLAYER_HEAD_CENTER_OFFSET // + math.sin(timepassed*math.PI*4.0)*clamp(linalg.length(player_velocity), 0.1, 1.0)*0.1*(player_isOnGround ? 1.0 : 0.0)
		camera.position = player_pos + camera.up * cam_y
		camera.target = camera.position + cam_forw
		camera.up = linalg.normalize(linalg.quaternion_mul_vector3(linalg.quaternion_angle_axis(player_lookRotEuler.z, cam_forw), vec3{0,1.0,0}))
	}
}