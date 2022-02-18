package doq

//
// MAP
//



import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:fmt"
import rl "vendor:raylib"
import "tiles"



MAP_SIDE_TILE_COUNT	:: 128
TILE_WIDTH	:: 30.0
TILE_MIN_HEIGHT	:: TILE_WIDTH
TILEMAP_Y_TILES	:: 7
TILE_HEIGHT	:: TILE_WIDTH * TILEMAP_Y_TILES
TILEMAP_MID	:: 4
TILE_OUT_OF_BOUNDS_SIZE :: 4000.0

TILE_ELEVATOR_MOVE_FACTOR	:: 0.55
TILE_ELEVATOR_Y0		:: cast(f32)-4.5*TILE_WIDTH + 2.0
TILE_ELEVATOR_Y1		:: cast(f32)-1.5*TILE_WIDTH - 2.0
TILE_ELEVATOR_SPEED		:: (TILE_ELEVATOR_Y1 - TILE_ELEVATOR_Y0) * TILE_ELEVATOR_MOVE_FACTOR

MAP_THORNS_RAD_MULTIPLIER :: 1.0

MAP_GUN_PICKUP_MAX_COUNT	:: 32
MAP_HEALTH_PICKUP_MAX_COUNT	:: 32
MAP_HEALTH_PICKUP_SIZE :: vec3{2,1.5,2}

MAP_TILE_FINISH_SIZE :: vec3{8, 16, 8}


map_data : struct {
	using mapdata : tiles.mapData_t,
	startPos	: vec3,
	finishPos	: vec3,
	isMapFinished	: bool,

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
	return coord.x >= 0 && coord.y >= 0 && coord.x < MAP_SIDE_TILE_COUNT && coord.y < MAP_SIDE_TILE_COUNT
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



map_floorTileBox :: proc(posxz : vec2) -> box_t {
	return {
		vec3{posxz[0],(-TILE_HEIGHT-TILE_OUT_OF_BOUNDS_SIZE)/2.0, posxz[1]},
		vec3{TILE_WIDTH, TILE_OUT_OF_BOUNDS_SIZE+TILE_WIDTH*2, TILE_WIDTH}/2.0,
	}
}

map_ceilTileBox :: proc(posxz : vec2) -> box_t {
	//return vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]},
	//	vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
	return {
		vec3{posxz[0],(+TILE_HEIGHT+TILE_OUT_OF_BOUNDS_SIZE)/2.0, posxz[1]},
		vec3{TILE_WIDTH, TILE_OUT_OF_BOUNDS_SIZE+TILE_WIDTH*2, TILE_WIDTH}/2.0,
	}
}

map_fullTileBox :: proc(posxz : vec2) -> box_t {
	return {vec3{posxz[0], TILE_WIDTH*0.5, posxz[1]}, vec3{TILE_WIDTH/2, TILE_OUT_OF_BOUNDS_SIZE/2, TILE_WIDTH/2}}
}


// fills input buffer `boxbuf` with axis-aligned boxes for a given tile
// @returns: number of boxes for the tile
map_getTileBoxes :: proc(coord : ivec2, boxbuf : []box_t) -> i32 {
	tileKind := map_data.tilemap[coord[0]][coord[1]]

	phy_calcBox :: proc(posxz : vec2, posy : f32, sizey : f32) -> box_t {
		return box_t{
			vec3{posxz.x, posy*TILE_WIDTH, posxz.y},
			vec3{TILE_WIDTH, sizey * TILE_WIDTH, TILE_WIDTH} / 2,
		}
	}

	posxz := vec2{cast(f32)coord[0]+0.5, cast(f32)coord[1]+0.5}*TILE_WIDTH

	#partial switch tileKind {
		case .NONE:
			return 0

		case .FULL, .THORNS_LOWER:
			boxbuf[0] = map_fullTileBox(posxz)
			return 1

		case .EMPTY:
			boxbuf[0] = map_floorTileBox(posxz)
			boxbuf[1] = map_ceilTileBox(posxz)
			return 2

		case .WALL_MID:
			boxbuf[0] = phy_calcBox(posxz, -2, 5)
			boxbuf[1] = map_ceilTileBox(posxz)
			return 2

		case .PLATFORM_SMALL:
			boxbuf[0] = map_floorTileBox(posxz)
			boxbuf[1] = map_ceilTileBox(posxz)
			boxbuf[2] = phy_calcBox(posxz, 0, 1)
			return 3
		case .PLATFORM_LARGE:
			boxbuf[0] = map_floorTileBox(posxz)
			boxbuf[1] = map_ceilTileBox(posxz)
			boxbuf[2] = phy_calcBox(posxz, 0, 3)
			return 3

		case .CEILING:
			boxbuf[0] = map_floorTileBox(posxz)
			boxbuf[1] = phy_calcBox(posxz, 2, 5)
			return 2

		case .ELEVATOR: // the actual moving elevator box is at index 0
			boxsize := vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
			height, ok := map_data.elevatorHeights[{cast(u8)coord.x, cast(u8)coord.y}]
			if !ok do height = 0.0
			boxbuf[0] = {
				vec3{posxz[0], math.lerp(TILE_ELEVATOR_Y0, TILE_ELEVATOR_Y1, height), posxz[1]},
				vec3{TILE_WIDTH, TILE_WIDTH*TILEMAP_MID, TILE_WIDTH}/2,
			}
			boxbuf[1] = map_ceilTileBox(posxz)
			boxbuf[2] = map_floorTileBox(posxz)
			return 3

		case .OBSTACLE_LOWER:
			boxbuf[0] = phy_calcBox(posxz, -3, 3)
			boxbuf[1] = map_ceilTileBox(posxz)
			return 2
		case .OBSTACLE_UPPER:
			boxbuf[0] = phy_calcBox(posxz, -2, 3)
			boxbuf[1] = map_ceilTileBox(posxz)
			return 2
	}

	return 0
}



map_clearAll :: proc() {
	tiles.resetMap(&map_data)

	map_data.gunPickupSpawnCount = 0
	map_data.gunPickupCount = 0
	map_data.healthPickupSpawnCount = 0
	map_data.healthPickupCount = 0
	enemy_data.gruntCount = 0
	enemy_data.knightCount = 0

	delete(map_data.elevatorHeights)

	map_setDefaultValues()
}

map_setDefaultValues :: proc() {
	map_data.skyColor = {0.6, 0.5, 0.8} * 0.6
	map_data.fogStrength = 1.0
}

map_loadFromFile :: proc(name: string) -> bool {
	fullpath := appendToAssetPath("maps", name)
	return map_loadFromFileAbs(fullpath)
}

map_loadFromFileAbs :: proc(fullpath: string) -> bool {
	println("! loading map: ", fullpath)

	map_clearAll()

	if !tiles.loadFromFile(fullpath, &map_data) {
		println("! error: map couldn't be loaded")
		return false
	}

	map_setDefaultValues()

	map_data.elevatorHeights = make(type_of(map_data.elevatorHeights))


	/*
	index : i32 = 0
	x : i32 = 0
	y : i32 = 0
	dataloop : for index < cast(i32)len(data) {
		ch : u8 = data[index]
		index += 1

		switch ch {
			case '\x00':
				println("null")
				return false
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
					if !attrib.skipWhitespace(data, &index) do index += 1
					println("index", index, "ch", cast(rune)data[index])
					if attrib.match(data, &index, "nextMapName")	do map_data.nextMapName = attrib.readString(data, &index)
					
					if attrib.match(data, &index, "startPlayerDir") {
						map_data.startPlayerDir.x = attrib.readF32(data, &index)
						map_data.startPlayerDir.y = attrib.readF32(data, &index)
						map_data.startPlayerDir = linalg.normalize(map_data.startPlayerDir)
					}
					
					if attrib.match(data, &index, "skyColor") {
						map_data.skyColor.r = attrib.readF32(data, &index)
						map_data.skyColor.g = attrib.readF32(data, &index)
						map_data.skyColor.b = attrib.readF32(data, &index)
					}
					
					if attrib.match(data, &index, "fogStrength")	do map_data.fogStrength = attrib.readF32(data, &index)
				}
		}

		tile := cast(tiles.kind_t)ch
		
		if map_isTilePosInBufferBounds({x, y}) {
			//println("pre ", tile)
			lowpos :=  map_tileToWorld({x, y}) - vec3{0, TILE_WIDTH*TILEMAP_Y_TILES/2 - TILE_WIDTH, 0}
			highpos := map_tileToWorld({x, y}) + vec3{0, TILE_WIDTH*0.5, 0}
		
			#partial switch tile {
				case .START_LOWER:		map_data.startPos = lowpos + vec3{0, PLAYER_SIZE.y*2, 0}
				case .START_UPPER:		map_data.startPos = highpos + vec3{0, PLAYER_SIZE.y*2, 0}
				case .FINISH_LOWER:		map_data.finishPos = lowpos + vec3{0, MAP_TILE_FINISH_SIZE.y, 0}
				case .FINISH_UPPER:		map_data.finishPos = highpos + vec3{0, MAP_TILE_FINISH_SIZE.y, 0}
				case .ELEVATOR:			map_data.elevatorHeights[{cast(u8)x, cast(u8)y}] = 0.0
				case .ENEMY_GRUNT_LOWER:	enemy_spawnGrunt (lowpos  + vec3{0,ENEMY_GRUNT_SIZE.y*1.2 , 0})
				case .ENEMY_GRUNT_UPPER:	enemy_spawnGrunt (highpos + vec3{0,ENEMY_GRUNT_SIZE.y*1.2 , 0})
				case .ENEMY_KNIGHT_LOWER:	enemy_spawnKnight(lowpos  + vec3{0,ENEMY_KNIGHT_SIZE.y*2.0, 0})
				case .ENEMY_KNIGHT_UPPER:	enemy_spawnKnight(highpos + vec3{0,ENEMY_KNIGHT_SIZE.y*2.0, 0})
				case .GUN_SHOTGUN_LOWER:	map_addGunPickup(lowpos  + vec3{0,PLAYER_SIZE.y,0}, .SHOTGUN)
				case .GUN_SHOTGUN_UPPER:	map_addGunPickup(highpos + vec3{0,PLAYER_SIZE.y,0}, .SHOTGUN)
				case .GUN_MACHINEGUN_LOWER:	map_addGunPickup(lowpos  + vec3{0,PLAYER_SIZE.y,0}, .MACHINEGUN)
				case .GUN_MACHINEGUN_UPPER:	map_addGunPickup(highpos + vec3{0,PLAYER_SIZE.y,0}, .MACHINEGUN)
				case .GUN_LASERRIFLE_LOWER:	map_addGunPickup(lowpos  + vec3{0,PLAYER_SIZE.y,0}, .LASERRIFLE)
				case .GUN_LASERRIFLE_UPPER:	map_addGunPickup(highpos + vec3{0,PLAYER_SIZE.y,0}, .LASERRIFLE)
				case .PICKUP_HEALTH_LOWER:
					rnd := vec2{
						rand.float32_range(-1.0, 1.0, &randData),
						rand.float32_range(-1.0, 1.0, &randData),
					} * TILE_WIDTH * 0.3
					map_addHealthPickup(lowpos + vec3{rnd.x, MAP_HEALTH_PICKUP_SIZE.y, rnd.y})
				case .PICKUP_HEALTH_UPPER:
					rnd := vec2{
						rand.float32_range(-1.0, 1.0, &randData),
						rand.float32_range(-1.0, 1.0, &randData),
					} * TILE_WIDTH * 0.3
					map_addHealthPickup(highpos + vec3{rnd.x, MAP_HEALTH_PICKUP_SIZE.y, rnd.y})
					tile = tiles.kind_t.WALL_MID
			}

			map_data.tilemap[x][y] = tiles.translate(tile)
			//println("post", tile)
		}

		x += 1
	}
	*/

	for x : i32 = 0; x < map_data.bounds.x; x += 1 {
		for y : i32 = 0; y < map_data.bounds.y; y += 1 {
			lowpos :=  map_tileToWorld({x, y}) - vec3{0, TILE_WIDTH*TILEMAP_Y_TILES/2 - TILE_WIDTH, 0}
			highpos := map_tileToWorld({x, y}) + vec3{0, TILE_WIDTH*0.5, 0}
			tile := map_data.tilemap[x][y]

			#partial switch tile {
				case .START_LOWER:		map_data.startPos = lowpos + vec3{0, PLAYER_SIZE.y*2, 0}
				case .START_UPPER:		map_data.startPos = highpos + vec3{0, PLAYER_SIZE.y*2, 0}
				case .FINISH_LOWER:		map_data.finishPos = lowpos + vec3{0, MAP_TILE_FINISH_SIZE.y, 0}
				case .FINISH_UPPER:		map_data.finishPos = highpos + vec3{0, MAP_TILE_FINISH_SIZE.y, 0}
				case .ELEVATOR:			map_data.elevatorHeights[{cast(u8)x, cast(u8)y}] = 0.0
				case .ENEMY_GRUNT_LOWER:	enemy_spawnGrunt (lowpos  + vec3{0,ENEMY_GRUNT_SIZE.y*1.2 , 0})
				case .ENEMY_GRUNT_UPPER:	enemy_spawnGrunt (highpos + vec3{0,ENEMY_GRUNT_SIZE.y*1.2 , 0})
				case .ENEMY_KNIGHT_LOWER:	enemy_spawnKnight(lowpos  + vec3{0,ENEMY_KNIGHT_SIZE.y*2.0, 0})
				case .ENEMY_KNIGHT_UPPER:	enemy_spawnKnight(highpos + vec3{0,ENEMY_KNIGHT_SIZE.y*2.0, 0})
				case .GUN_SHOTGUN_LOWER:	map_addGunPickup(lowpos  + vec3{0,PLAYER_SIZE.y,0}, .SHOTGUN)
				case .GUN_SHOTGUN_UPPER:	map_addGunPickup(highpos + vec3{0,PLAYER_SIZE.y,0}, .SHOTGUN)
				case .GUN_MACHINEGUN_LOWER:	map_addGunPickup(lowpos  + vec3{0,PLAYER_SIZE.y,0}, .MACHINEGUN)
				case .GUN_MACHINEGUN_UPPER:	map_addGunPickup(highpos + vec3{0,PLAYER_SIZE.y,0}, .MACHINEGUN)
				case .GUN_LASERRIFLE_LOWER:	map_addGunPickup(lowpos  + vec3{0,PLAYER_SIZE.y,0}, .LASERRIFLE)
				case .GUN_LASERRIFLE_UPPER:	map_addGunPickup(highpos + vec3{0,PLAYER_SIZE.y,0}, .LASERRIFLE)
				case .PICKUP_HEALTH_LOWER:
					rnd := vec2{
						rand.float32_range(-1.0, 1.0, &randData),
						rand.float32_range(-1.0, 1.0, &randData),
					} * TILE_WIDTH * 0.3
					map_addHealthPickup(lowpos + vec3{rnd.x, MAP_HEALTH_PICKUP_SIZE.y, rnd.y})
				case .PICKUP_HEALTH_UPPER:
					rnd := vec2{
						rand.float32_range(-1.0, 1.0, &randData),
						rand.float32_range(-1.0, 1.0, &randData),
					} * TILE_WIDTH * 0.3
					map_addHealthPickup(highpos + vec3{rnd.x, MAP_HEALTH_PICKUP_SIZE.y, rnd.y})
					tile = tiles.kind_t.WALL_MID
			}

			map_data.tilemap[x][y] = tiles.translate(tile)
		}
	}



	println("end")

	println("bounds[0]", map_data.bounds[0], "bounds[1]", map_data.bounds[1])
	println("nextMapName", map_data.nextMapName)

	player_startMap()

	rl.SetShaderValue(
		asset_data.portalShader,
		cast(rl.ShaderLocationIndex)rl.GetShaderLocation(asset_data.portalShader, "portalPos"),
		&map_data.finishPos,
		rl.ShaderUniformDataType.VEC3,
	)


	return true

}

map_debugPrint :: proc() {
	for x : i32 = 0; x < map_data.bounds[0]; x += 1 {
		for y : i32 = 0; y < map_data.bounds[1]; y += 1 {
			fmt.print(map_data.tilemap[x][y] == tiles.kind_t.FULL ? "#" : " ")
		}
		println("")
	}
}

// draw tilemap, pickups, etc.
map_drawTilemap :: proc() {
	rl.BeginShaderMode(asset_data.tileShader)
	for x : i32 = 0; x < map_data.bounds[0]; x += 1 {
		for y : i32 = 0; y < map_data.bounds[1]; y += 1 {
			//rl.DrawCubeWires(vec3{posxz[0], 0.0, posxz[1]}, TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.GRAY)
			tilekind := map_data.tilemap[x][y]

			boxbuf : [PHY_MAX_TILE_BOXES]box_t = {}
			boxcount := map_getTileBoxes({x, y}, boxbuf[0:])
			//checker := cast(bool)((x%2) ~ (y%2))
			#partial switch tilekind {
				case:
					for i : i32 = 0; i < boxcount; i += 1 {
						rl.DrawModelEx(asset_data.tileModel, boxbuf[i].pos, {0,1,0}, 0.0, boxbuf[i].size*2.0, rl.WHITE)
					}
				case .ELEVATOR:
					rl.DrawModelEx(asset_data.elevatorModel, boxbuf[0].pos, {0,1,0}, 0.0, boxbuf[0].size*2.0, rl.WHITE)
					for i : i32 = 1; i < boxcount; i += 1 {
						rl.DrawModelEx(asset_data.tileModel, boxbuf[i].pos, {0,1,0}, 0.0, boxbuf[i].size*2.0, rl.WHITE)
					}
				case .OBSTACLE_LOWER:
					rl.DrawModelEx(asset_data.boxModel,
						boxbuf[0].pos+{0,TILE_WIDTH,0}, {0,1,0}, 0.0, {TILE_WIDTH,TILE_WIDTH,TILE_WIDTH}, rl.WHITE,
					)
					rl.DrawModelEx(asset_data.tileModel,
						boxbuf[0].pos-{0,TILE_WIDTH,0}, {0,1,0}, 0.0, {TILE_WIDTH,TILE_WIDTH,TILE_WIDTH}, rl.WHITE,
					)
					for i : i32 = 1; i < boxcount; i += 1 {
						rl.DrawModelEx(asset_data.tileModel, boxbuf[i].pos, {0,1,0}, 0.0, boxbuf[i].size*2.0, rl.WHITE)
					}
				case .OBSTACLE_UPPER:
					rl.DrawModelEx(asset_data.boxModel,
						boxbuf[0].pos+{0,TILE_WIDTH,0}, {0,1,0}, 0.0, {TILE_WIDTH,TILE_WIDTH,TILE_WIDTH}, rl.WHITE,
					)
					rl.DrawModelEx(asset_data.boxModel,
						boxbuf[0].pos, {0,1,0}, 0.0, {TILE_WIDTH,TILE_WIDTH,TILE_WIDTH}, rl.WHITE,
					)
					rl.DrawModelEx(asset_data.tileModel,
						boxbuf[0].pos-{0,TILE_WIDTH,0}, {0,1,0}, 0.0, {TILE_WIDTH,TILE_WIDTH,TILE_WIDTH}, rl.WHITE,
					)
					for i : i32 = 1; i < boxcount; i += 1 {
						rl.DrawModelEx(asset_data.tileModel, boxbuf[i].pos, {0,1,0}, 0.0, boxbuf[i].size*2.0, rl.WHITE)
					}

				case .THORNS_LOWER:
					yoffs := math.floor(player_data.pos.y / TILE_WIDTH) * TILE_WIDTH
					p := map_tileToWorld({x, y})
					floorbox := map_floorTileBox({p.x, p.z})
					ceilbox  := map_ceilTileBox ({p.x, p.z})
					THORN_DRAW_COUNT :: 32

					rl.DrawModelEx(asset_data.tileModel, floorbox.pos, {0,1,0}, 0.0, floorbox.size*2.0, rl.WHITE)
					rl.DrawModelEx(asset_data.tileModel, ceilbox.pos , {0,1,0}, 0.0, ceilbox.size *2.0, rl.WHITE)
				
					for i : i32 = 0; i < TILEMAP_Y_TILES-2; i += 1 {
						rl.DrawModelEx(asset_data.thornsModel, p + vec3{0, (f32(i) - f32(TILEMAP_Y_TILES-2)*0.5 + 0.5)*TILE_WIDTH, 0}, {0,1,0}, 0, {TILE_WIDTH,TILE_WIDTH,TILE_WIDTH}, rl.WHITE)
					}
				

			}
		}
	}
	rl.EndShaderMode()

	if settings.debugIsEnabled {
		for x : i32 = 0; x < map_data.bounds[0]; x += 1 {
			for y : i32 = 0; y < map_data.bounds[1]; y += 1 {
				tilekind := map_data.tilemap[x][y]
				boxbuf : [PHY_MAX_TILE_BOXES]box_t = {}
				boxcount := map_getTileBoxes({x, y}, boxbuf[0:])
				for i : i32 = 0; i < boxcount; i += 1 {
					rl.DrawCubeWiresV(boxbuf[i].pos, boxbuf[i].size*2.0 + vec3{0.1,0.1,0.1}, rl.Fade(rl.GREEN, 0.25))
				}
			}
		}

		rl.DrawGrid(MAP_SIDE_TILE_COUNT, TILE_WIDTH)
	}

	rl.BeginShaderMode(asset_data.portalShader)
	// draw finish
	rl.DrawCubeTexture(asset_data.portalTexture, map_data.finishPos, MAP_TILE_FINISH_SIZE.x*2, MAP_TILE_FINISH_SIZE.y*2, MAP_TILE_FINISH_SIZE.z*2, rl.WHITE)
	rl.EndShaderMode()
	rl.DrawCube(map_data.finishPos,-MAP_TILE_FINISH_SIZE.x*2-4,-MAP_TILE_FINISH_SIZE.y*2-4,-MAP_TILE_FINISH_SIZE.z*2-4, {0,0,0,40})
	rl.DrawCube(map_data.finishPos,-MAP_TILE_FINISH_SIZE.x*2-2,-MAP_TILE_FINISH_SIZE.y*2-2,-MAP_TILE_FINISH_SIZE.z*2-2, {0,0,0,60})
	rl.DrawCube(map_data.finishPos,-MAP_TILE_FINISH_SIZE.x*2-1,-MAP_TILE_FINISH_SIZE.y*2-1,-MAP_TILE_FINISH_SIZE.z*2-1, {0,0,0,90})

	// draw pickups and update them
	{
		ROTSPEED :: 180
		SCALE :: 5.0

		// update gun pickups
		// draw gun pickups
		for i : i32 = 0; i < map_data.gunPickupCount; i += 1 {
			pos := map_data.gunPickups[i].pos + vec3{0, math.sin(timepassed*8.0)*0.2, 0}
			gunindex := cast(i32)map_data.gunPickups[i].kind
			rl.DrawModelEx(asset_data.gun.gunModels[gunindex], pos, {0,1,0}, timepassed*ROTSPEED, SCALE, rl.WHITE)
			rl.DrawSphere(pos, -2.0, {255,230,180,40})
		
			RAD :: 6.5
			if linalg.length2(player_data.pos - pos) < RAD*RAD &&
				gun_data.ammoCounts[gunindex] < gun_maxAmmoCounts[gunindex] {
				gun_data.equipped = map_data.gunPickups[i].kind
				gun_data.ammoCounts[gunindex] = gun_maxAmmoCounts[gunindex]
				playSoundMulti(asset_data.gun.ammoPickupSound)

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

			rl.DrawModel(asset_data.healthPickupModel, map_data.healthPickups[i], MAP_HEALTH_PICKUP_SIZE.x, rl.WHITE)
			
			RAD :: 6.5
			if linalg.length2(player_data.pos - map_data.healthPickups[i]) < RAD*RAD && player_data.health < PLAYER_MAX_HEALTH {
				player_data.health += PLAYER_MAX_HEALTH*0.25
				player_data.health = clamp(player_data.health, 0.0, PLAYER_MAX_HEALTH)
				screenTint = {1.0,0.8,0.0}
				playSound(asset_data.player.healthPickupSound)
				temp := map_data.healthPickups[i]
				map_data.healthPickupCount -= 1
				map_data.healthPickups[i] = map_data.healthPickups[map_data.healthPickupCount]
				map_data.healthPickups[map_data.healthPickupCount] = temp
			}
		}
	}

	//rl.DrawCylinderEx(circpos-vec3{0,TILE_WIDTH*2,0}, circpos-vec3{0,2000,0}, 1000, 1000, 32, {200,220,220,40})
	//rl.DrawCylinderEx(circpos-vec3{0,TILE_WIDTH*1,0}, circpos-vec3{0,2000,0}, 1000, 1000, 32, {200,220,220,40})
	//rl.DrawCylinderEx(circpos-vec3{0,TILE_WIDTH*0,0}, circpos-vec3{0,2000,0}, 1000, 1000, 32, {200,220,220,40})

	{
		W :: 2048
		c : vec3 = player_data.pos
		rl.BeginShaderMode(asset_data.cloudShader)
		rl.DrawCubeTexture(asset_data.cloudTexture, vec3{c.x,+TILE_HEIGHT*1.6,c.z}, W,1,W, {255,255,255,50})
		rl.DrawCubeTexture(asset_data.cloudTexture, vec3{c.x,+TILE_HEIGHT*1.0,c.z}, W,1,W, {255,255,255,40})
		rl.DrawCubeTexture(asset_data.cloudTexture, vec3{c.x,+TILE_HEIGHT*0.6,c.z}, W,1,W, {255,255,255,20})
		rl.DrawCubeTexture(asset_data.cloudTexture, vec3{c.x,-TILE_HEIGHT*1.6,c.z}, W,1,W, {200,200,200,60})
		rl.DrawCubeTexture(asset_data.cloudTexture, vec3{c.x,-TILE_HEIGHT*1.0,c.z}, W,1,W, {200,200,200,40})
		rl.DrawCubeTexture(asset_data.cloudTexture, vec3{c.x,-TILE_HEIGHT*0.6,c.z}, W,1,W, {255,255,255,20})
		rl.EndShaderMode()
	}
}


calcThornsCollision :: proc(pos : vec3, rad : f32) -> (isColliding : bool, pushdir : vec3) {
	if abs(pos.y) > (TILEMAP_Y_TILES-2)*TILE_WIDTH*0.5 {
		isColliding = false
		pushdir = {}
		return isColliding, pushdir
	}
	tilepos := map_worldToTile(pos)
	rad2 := rad*rad

	for x : i32 = -1; x <= 1; x += 1 {
		for y : i32 = -1; y <= 1; y += 1 {
			p := tilepos + {x, y}
			
			if !map_isTilePosValid(p) do continue
			if map_data.tilemap[p.x][p.y] == .THORNS_LOWER {
				posxz := vec2{f32(p.x)+0.5, f32(p.y)+0.5}*TILE_WIDTH
				dir := vec2{pos.x - posxz.x, pos.z - posxz.y}
				length2 := linalg.length2(dir)
				sd := length2 - (TILE_WIDTH*TILE_WIDTH*0.5*MAP_THORNS_RAD_MULTIPLIER) // subtract tile radius
				if sd < rad2 {
					isColliding = true
					pushdir += {dir.x, 0.0, dir.y}
				}
			}
		}
	}

	if isColliding do pushdir = linalg.normalize(pushdir)

	return isColliding, pushdir
}