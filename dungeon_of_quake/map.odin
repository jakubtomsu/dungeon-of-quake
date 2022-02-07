package dungeon_of_quake



import "core:os"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:strings"
import "core:fmt"
import "core:strconv"
import rl "vendor:raylib"



//
// MAP
//

MAP_MAX_WIDTH	:: 128
TILE_WIDTH	:: 30.0
TILE_MIN_HEIGHT	:: TILE_WIDTH
TILEMAP_Y_TILES	:: 7
TILE_HEIGHT	:: TILE_WIDTH * TILEMAP_Y_TILES
TILEMAP_MID	:: 4

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
	backgroundMusic		: rl.Music,
	ambientMusic		: rl.Music,
	elevatorSound		: rl.Sound,
	elevatorEndSound	: rl.Sound,

	tileModel		: rl.Model,
	elevatorModel		: rl.Model,
	healthPickupModel	: rl.Model,
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
			//rl.DrawCubeTexture(
			//	map_data.healthPickupTexture,
			//	map_data.healthPickups[i],
			//	MAP_HEALTH_PICKUP_SIZE.x*2.0,
			//	MAP_HEALTH_PICKUP_SIZE.y*2.0,
			//	MAP_HEALTH_PICKUP_SIZE.z*2.0,
			//	rl.WHITE,
			//)

			rl.DrawModel(map_data.healthPickupModel, map_data.healthPickups[i], MAP_HEALTH_PICKUP_SIZE.x, rl.WHITE)
	
			RAD :: 4.5
			if linalg.length2(player_data.pos - map_data.healthPickups[i]) < RAD*RAD {
				player_data.health += PLAYER_MAX_HEALTH*0.25
				screenTint = {1.0,0.8,0.0}
				playSound(player_data.healthPickupSound)

				temp := map_data.healthPickups[i]
				map_data.healthPickupCount -= 1
				map_data.healthPickups[i] = map_data.healthPickups[map_data.healthPickupCount]
				map_data.healthPickups[map_data.healthPickupCount] = temp
			}
		}
	}
}
