package qfps



import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
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
	_init()

	for !rl.WindowShouldClose() && !app_shouldExitNextFrame {
		println("frame =", framespassed, "deltatime =", deltatime)
		framespassed += 1

		rl.UpdateCamera(&camera)
		rl.UpdateCamera(&viewmodelCamera)
		rl.DisableCursor()

		_update()

		rl.BeginTextureMode(rendertextureMain)
			rl.ClearBackground(rl.BLACK)

			rl.BeginMode3D(camera)
				_render3d()
				player_update()
			rl.EndMode3D()

			rl.BeginMode3D(viewmodelCamera)
				// gun
				{
					pos := vec3{-GUN_POS_X + player_lookRotEuler.z*0.5,-0.2, 0.2}
					rl.DrawCube(pos, 0.1*GUN_SCALE, 0.15*GUN_SCALE,0.3*GUN_SCALE, rl.DARKGRAY)
					rl.DrawCube(pos + {0,0,0.1}, 0.04*GUN_SCALE, 0.04*GUN_SCALE,0.4*GUN_SCALE, rl.Color{30,30,30,255})
					rl.DrawCube(pos, 0.2*GUN_SCALE,0.1*GUN_SCALE,0.15*GUN_SCALE, rl.GRAY)
					rl.DrawCube(pos + {0,0,0.1}, 0.05*GUN_SCALE,0.2*GUN_SCALE,0.15*GUN_SCALE, rl.GRAY)
				}
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

			_render2d()
		rl.EndDrawing()


		deltatime = rl.GetFrameTime()
		timepassed += deltatime // not really accurate but whatever
	}

	rl.CloseWindow()
}



//
// APP
//

_init :: proc() {
	rl.InitWindow(WINDOW_X, WINDOW_Y, "qfps")
	rl.SetTargetFPS(75)
	loadpath = filepath.clean(string(rl.GetWorkingDirectory()))
	println("loadpath", loadpath)

	rendertextureMain = rl.LoadRenderTexture(WINDOW_X, WINDOW_Y)
	postprocessShader = loadFragShader("postprocess.frag")
	tileShader = loadShader("tile.vert", "tile.frag")
	tileShaderCamPosUniformIndex = cast(rl.ShaderLocationIndex)rl.GetShaderLocation(tileShader, "camPos")

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
	map_loadFromFile("test.qfmap")
	map_basetexture = loadTexture("test4.png")
	//map_debugPrint()
}

_update :: proc() {
	if rl.IsKeyPressed(rl.KeyboardKey.RIGHT_ALT) do _debugtext_enabled = !_debugtext_enabled
	rl.SetShaderValue(tileShader, tileShaderCamPosUniformIndex, &camera.position, rl.ShaderUniformDataType.VEC3)
}

_debugtext_y : i32 = 0
_debugtext_enabled : bool = true
_render2d :: proc() {
	rl.DrawFPS(0, 0)
	_debugtext_y = 2

	//rl.DrawRectangle(10, 10, 220, 70, rl.Fade(rl.SKYBLUE, 0.5))
	//rl.DrawRectangleLines(10, 10, 220, 70, rl.BLUE)
	//rl.DrawText("First person camera default controls:", 20, 20, 10, rl.BLACK)
	//rl.DrawText("- Move with keys: W, A, S, D",	40, 40, 10, rl.DARKGRAY)
	//rl.DrawText("- Mouse move to look around",	40, 60, 10, rl.DARKGRAY)

	rl.DrawRectangle(WINDOW_X/2 - 3, WINDOW_Y/2 - 3, 6, 6, rl.Fade(rl.BLACK, 0.5))
	rl.DrawRectangle(WINDOW_X/2 - 2, WINDOW_Y/2 - 2, 4, 4, rl.Fade(rl.WHITE, 0.5))

	if _debugtext_enabled {
		debugtext :: proc(args: ..any) {
			tstr := fmt.tprint(args=args)
			cstr := str.clone_to_cstring(tstr, context.temp_allocator)
			rl.DrawText(cstr, 6, _debugtext_y * 12, 10, rl.Fade(rl.WHITE, 0.8))
			_debugtext_y += 1
		}

		debugtext("player")
		debugtext("    pos", player_pos)
		debugtext("    vel", player_velocity)
		debugtext("    onground", player_isOnGround)
	}
}

_render3d :: proc() {
	rl.DrawCube(vec3{1, 0, 0}, 1,0.1,0.1, rl.RED)
	rl.DrawCube(vec3{0, 1, 0}, 0.1,1,0.1, rl.GREEN)
	rl.DrawCube(vec3{0, 0, 1}, 0.1,0.1,1, rl.BLUE)
	rl.DrawCube(vec3{0, 0, 0}, 0.1,0.1,0.1, rl.RAYWHITE)
	//rl.DrawPlane(vec3{0.0, 0.0, 0.0}, vec2{32.0, 32.0}, rl.LIGHTGRAY) // Draw ground

	// draw tilemap
	{
		for x : i32 = 0; x < tilemap.bounds[0]; x += 1 {
			for y : i32 = 0; y < tilemap.bounds[1]; y += 1 {
				posxz : vec2 = {(cast(f32)x) * TILE_WIDTH, (cast(f32)y) * TILE_WIDTH} + vec2{TILE_WIDTH/2.0, TILE_WIDTH/2.0}
				//rl.DrawCubeWires(vec3{posxz[0], 0.0, posxz[1]}, TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.GRAY)
				
				rl.BeginShaderMode(tileShader)
				checker := cast(bool)((x%2) ~ (y%2))
				#partial switch tilemap.tiles[x][y] {
					case map_tileKind_t.WALL:
						pos := vec3{posxz[0], 0.0, posxz[1]}
						//rl.DrawCube(pos, TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.Color{cast(u8)x*50, cast(u8)y*50, 255, 255})
						rl.DrawCubeTexture(map_basetexture, pos, TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.WHITE)
					case map_tileKind_t.EMPTY:
						pos0 := vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}
						pos1 := vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}
						size := vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}
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
	return str.clone_to_cstring(
		fmt.tprint(
			args = {loadpath, filepath.SEPARATOR_STRING, subdir, filepath.SEPARATOR_STRING, path},
			sep="",
		),
		context.temp_allocator)
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
TILE_WIDTH		:: 30.0
TILE_MIN_HEIGHT		:: TILE_WIDTH
TILE_HEIGHT		:: TILE_WIDTH * 3
TILE_LOW_CEIL_FACTOR	:: 0.5
TILE_ELEVATION_FACTOR	:: 0.5
TILE_LOW_CEIL_Y		:: ( TILE_HEIGHT*(1.0 - TILE_LOW_CEIL_FACTOR) ) + (-TILE_HEIGHT*TILE_LOW_CEIL_FACTOR )
TILE_ELEVATION_Y	:: (-TILE_HEIGHT*(1.0 - TILE_ELEVATION_FACTOR)) + ( TILE_HEIGHT*TILE_ELEVATION_FACTOR)
tilemap : struct {
	tiles  : [TILEMAP_MAX_WIDTH][TILEMAP_MAX_WIDTH]map_tileKind_t,
	bounds : ivec2,
	start  : ivec2,
	finish : ivec2,
}

map_basetexture : rl.Texture2D

map_worldToTile :: proc(p : vec3) -> ivec2 {
	return ivec2{cast(i32)((p.x / TILE_WIDTH) - 0.5), cast(i32)((p.z / TILE_WIDTH) - 0.5)}
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

PHY_MAX_TILE_BOXES :: 4
PHY_BOXCAST_EPS :: 1e-2



phy_box_t :: struct {
	pos  : vec3,
	size : vec3,
}



	//tileMin := vec3{cast(f32)coord[0] * TILE_WIDTH, -TILE_HEIGHT, cast(f32)coord[1] * TILE_WIDTH}
	//tileMax := vec3{cast(f32)(coord[0] + 1) * TILE_WIDTH, TILE_HEIGHT, cast(f32)(coord[1] + 1) * TILE_WIDTH}

phy_getTileBox :: proc(coord : ivec2, pos : vec3) -> (phy_box_t, bool) {
	tileKind := tilemap.tiles[coord[0]][coord[1]]
	posxz := vec2{cast(f32)coord[0]+0.5, cast(f32)coord[1]+0.5}*TILE_WIDTH

	#partial switch tileKind {
		case map_tileKind_t.WALL: return phy_box_t{vec3{posxz[0], 0.0, posxz[1]}, vec3{TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH}/2}, true
		case map_tileKind_t.EMPTY:
			box : phy_box_t
			box.size = vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			box.pos = pos.y < 0.0 ? vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]} : vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}
			return box, true
	}
	return phy_box_t{}, false
}

phy_getTileBoxes :: proc(coord : ivec2, boxbuf : []phy_box_t) -> i32 {
	tileKind := tilemap.tiles[coord[0]][coord[1]]

	posxz := vec2{cast(f32)coord[0]+0.5, cast(f32)coord[1]+0.5}*TILE_WIDTH

	#partial switch tileKind {
		case map_tileKind_t.WALL:
			boxbuf[0] = phy_box_t{vec3{posxz[0], 0.0, posxz[1]}, vec3{TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH}/2}
			return 1
		case map_tileKind_t.EMPTY:
			boxsize := vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			boxbuf[0] = {vec3{posxz[0],(-TILE_HEIGHT+TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			boxbuf[1] = {vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]}, boxsize}
			return 2
	}
	return 0
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
// boxsize < TILE_WIDTH
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
	dir = linelen == 0.0 ? {0,1,0} : dir / linelen
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
	ctx.dirinv	= vec3{1,1,1}/dir
	ctx.dirinvabs	= vec3{abs(ctx.dirinv.x), abs(ctx.dirinv.y), abs(ctx.dirinv.z)}
	ctx.boxoffs	= boxsize
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
		boxcount := phy_getTileBoxes(coord, boxbuf[0:])

		for i : i32 = 0; i < boxcount; i += 1 {
			box := boxbuf[i]

			//rl.DrawCube(box.pos, box.size.x*2, box.size.y*2, box.size.z*2, rl.Fade(rl.GREEN, 0.5))

			n := ctx.dirinv * (ctx.pos - box.pos)
			k := ctx.dirinvabs * (box.size + ctx.boxoffs)
			t1 := -n - k
			t2 := -n + k
			tn := max(max(t1.x, t1.y), t1.z)
			tf := min(min(t2.x, t2.y), t2.z)
			isinside := tn<-0.001 && tn<tf && tf>-0.0001
			if isinside do ctx.hit = true
			if tn>tf || tf<0.0 || tn>ctx.tmin || tn<-ctx.linelen || isinside {
				continue // no intersection or we have closer hit
			}
			ctx.tmin = tn
			ctx.normal = -ctx.dirsign * cast(vec3)(glsl.step(glsl.vec3{t1.y,t1.z,t1.x}, glsl.vec3{t1.x,t1.y,t1.z}) * glsl.step(glsl.vec3{t1.z,t1.x,t1.y}, glsl.vec3{t1.x,t1.y,t1.z}))
			ctx.hit = true
		}
	}

	return pos + dir*ctx.tmin, ctx.normal, ctx.hit
}






//
// PLAYER
//

player_lookRotEuler : vec3 = {}
player_pos : vec3 = {TILE_WIDTH/2, 0, TILE_WIDTH/2}
player_isOnGround : bool
player_velocity : vec3 = {0,0.1,0}

PLAYER_RADIUS			:: 1.0
PLAYER_HEAD_CENTER_OFFSET	:: 0.8
PLAYER_LOOK_SENSITIVITY		:: 0.004
PLAYER_FOV			:: 120
PLAYER_VIEWMODEL_FOV		:: 120

PLAYER_GRAVITY			:: 100 // 800
PLAYER_SPEED			:: 100 // 320
PLAYER_GROUND_ACCELERATION	:: 10 // 10
PLAYER_GROUND_FRICTION		:: 4 // 6
PLAYER_AIR_ACCELERATION		:: 5.7 // 0.7
PLAYER_AIR_FRICTION		:: 0 // 0
PLAYER_JUMP_SPEED		:: 37 // 270
PLAYER_MIN_NORMAL_Y		:: 0.25

GUN_SCALE :: 0.7
GUN_POS_X :: 0.1

mouseLastX : i32
mouseLastY : i32
mouseDeltaX : f32
mouseDeltaY : f32


player_update :: proc() {
	oldpos := player_pos

	//{
	//	bpos := vec3{TILE_WIDTH*2,0,TILE_WIDTH*2}
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

	mouseDeltaX = cast(f32)(rl.GetMouseX() - mouseLastX)
	mouseDeltaY = cast(f32)(rl.GetMouseY() - mouseLastY)
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

	player_accelerate(forw*movedir.y + right*movedir.x, PLAYER_SPEED,
		player_isOnGround ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)

	wishpos := player_pos + player_velocity * deltatime
	
	//phy_vec, phy_norm, phy_hit := phy_clipSphereWithTilemap(player_pos, PLAYER_RADIUS)
	phy_vec, phy_norm, phy_hit := phy_boxCastTilemap(player_pos, wishpos, vec3{1,1,1})
	
	println("pos", player_pos, "vel", player_velocity)
	println("phy vec", phy_vec, "norm", phy_norm, "hit", phy_hit)
	
	//if phy_hit do player_pos = player_pos + phy_vec
	player_pos = phy_vec + phy_norm*1e-2

	//rl.DrawCube(phy_vec, 1,1,1, rl.PINK)

	player_isOnGround = phy_hit && phy_norm.y > PLAYER_MIN_NORMAL_Y

	player_clipVelocity :: proc(vel : vec3, normal : vec3, overbounce : f32) -> vec3 {
		backoff := linalg.vector_dot(vel, normal) * overbounce
		change := normal*backoff
		return vel - change
	}

	if phy_hit do player_velocity = player_clipVelocity(player_velocity, phy_norm, 1.0)

	// friction
	{
		len := linalg.vector_length(player_velocity)
		friction : f32 = player_isOnGround ? PLAYER_GROUND_FRICTION : PLAYER_AIR_FRICTION
		drop := len * friction * deltatime
		player_velocity = (len == 0.0 ? {} : player_velocity / len) * (len - drop)
	}



	cam_forw := linalg.matrix_mul_vector(player_lookRotMatrix3, vec3{0, 0, 1})

	// camera
	{
		player_lookRotEuler.y += -mouseDeltaX * PLAYER_LOOK_SENSITIVITY
		player_lookRotEuler.x += mouseDeltaY * PLAYER_LOOK_SENSITIVITY
		player_lookRotEuler.x = clamp(player_lookRotEuler.x, -0.48 * math.PI, 0.48 * math.PI)
		player_lookRotEuler.z = math.lerp(player_lookRotEuler.z, 0.0, clamp(deltatime * 7.5, 0.0, 1.0))
		player_lookRotEuler.z -= movedir.x * deltatime * 0.75 - mouseDeltaX*0.0001
		player_lookRotEuler.z = clamp(player_lookRotEuler.z, -math.PI*0.2, math.PI*0.2)

		cam_y : f32 = PLAYER_HEAD_CENTER_OFFSET // + math.sin(timepassed*math.PI*4.0)*clamp(linalg.length(player_velocity), 0.1, 1.0)*0.1*(player_isOnGround ? 1.0 : 0.0)
		camera.position = player_pos + camera.up * cam_y
		camera.target = camera.position + cam_forw
		camera.up = linalg.normalize(linalg.quaternion_mul_vector3(linalg.quaternion_angle_axis(player_lookRotEuler.z, cam_forw), vec3{0,1.0,0}))
	}


	//phy_boxCastTilemap({300, 0, 300}, {200, 50, 50}*10.0, {1,1,1})
	//phy_boxCastTilemap({}, {1,0,1}, {3,1000,3})
	//phy_boxCastTilemap({}, {math.sin(timepassed)*30, 0, 30}, {3,1000,3})
	//phy_boxCastTilemap({}, {200,0,0}, {3,10,3})
	//phy_boxCastTilemap({}, {100,0,100}, {3,10,3})

	{
		size := vec3{1,1,1}
		pos, normal, tmin := phy_boxCastTilemap(
			camera.position, camera.position + cam_forw*1000.0, size*0.5)
		rl.DrawCube(pos, size.x, size.y, size.z, rl.YELLOW)
		rl.DrawLine3D(pos, pos + normal*4, rl.ORANGE)
	}
}