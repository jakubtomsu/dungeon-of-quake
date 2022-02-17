package tiles



import "core:os"
import "core:math/linalg"
import "core:fmt"
import rl "vendor:raylib"
import "../attrib"



// `translated` tiles are changed into different tiles when a map gets loaded
kind_t :: enum u8 {
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

	THORNS_LOWER		= 't',

	GUN_SHOTGUN_LOWER	= 'd', // translated // as `default` weapon
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

MAP_MAX_SIZE :: 256 // u8 max

mapData_t :: struct {
	fullpath	: string,
	nextMapName	: string,
	startPlayerDir	: rl.Vector2,
	skyColor	: rl.Vector3, // normalized rgb
	fogStrength	: f32,
	bounds		: [2]i32,
	tilemap		: [MAP_MAX_SIZE][MAP_MAX_SIZE]kind_t, // TODO: allocate exact-size buffer on loadtime
}



translate :: proc(srctile : kind_t) -> kind_t {
	#partial switch srctile {
		case .START_LOWER:		return .EMPTY
		case .START_UPPER:		return .WALL_MID
		case .FINISH_LOWER:		return .EMPTY
		case .FINISH_UPPER:		return .WALL_MID
		case .ENEMY_GRUNT_LOWER:	return .EMPTY
		case .ENEMY_GRUNT_UPPER:	return .WALL_MID
		case .ENEMY_KNIGHT_LOWER:	return .EMPTY
		case .ENEMY_KNIGHT_UPPER:	return .WALL_MID
		case .GUN_SHOTGUN_LOWER:	return .EMPTY
		case .GUN_SHOTGUN_UPPER:	return .WALL_MID
		case .GUN_MACHINEGUN_LOWER:	return .EMPTY
		case .GUN_MACHINEGUN_UPPER:	return .WALL_MID
		case .GUN_LASERRIFLE_LOWER:	return .EMPTY
		case .GUN_LASERRIFLE_UPPER:	return .WALL_MID
		case .PICKUP_HEALTH_LOWER:	return .EMPTY
		case .PICKUP_HEALTH_UPPER:	return .WALL_MID
	}

	return srctile
}

resetMap :: proc(mapdata : ^mapData_t) {
	using mapdata
	fullpath	= {}
	nextMapName	= {}
	startPlayerDir	= {}
	skyColor	= {}
	fogStrength	= {}
	bounds		= {}

	for x : i32 = 0; x < MAP_MAX_SIZE; x += 1 {
		for y : i32 = 0; y < MAP_MAX_SIZE; y += 1 {
			tilemap[x][y] = .NONE
		}
	}
}

loadFromFile :: proc(fullpath : string, mapdata : ^mapData_t) -> bool {
	data, success := os.read_entire_file_from_filename(fullpath)
	mapdata.fullpath = fullpath

	if !success do return false

	defer free(&data[0])

	resetMap(mapdata)

	index : i32 = 0
	x : i32 = 0
	y : i32 = 0
	dataloop : for index < cast(i32)len(data) {
		ch : u8 = data[index]
		index += 1

		switch ch {
			case '\x00': break dataloop
			case '\r': continue dataloop
			case '\n':
				y += 1
				mapdata.bounds.x = max(mapdata.bounds.x, x)
				mapdata.bounds.y = max(mapdata.bounds.y, y)
				x = 0
				continue dataloop
			case '{':
				for data[index] != '}' {
					if !attrib.skipWhitespace(data, &index) do index += 1
					if attrib.match(data, &index, "nextMapName")	do mapdata.nextMapName = attrib.readString(data, &index)
					
					if attrib.match(data, &index, "startPlayerDir") {
						mapdata.startPlayerDir.x = attrib.readF32(data, &index)
						mapdata.startPlayerDir.y = attrib.readF32(data, &index)
						mapdata.startPlayerDir = linalg.normalize(mapdata.startPlayerDir)
					}
					
					if attrib.match(data, &index, "skyColor") {
						mapdata.skyColor.r = attrib.readF32(data, &index)
						mapdata.skyColor.g = attrib.readF32(data, &index)
						mapdata.skyColor.b = attrib.readF32(data, &index)
					}
					
					if attrib.match(data, &index, "fogStrength")	do mapdata.fogStrength = attrib.readF32(data, &index)
				}
				index += 1
				attrib.skipWhitespace(data, &index)
				continue dataloop
		}

		
		mapdata.tilemap[x][y] = kind_t(ch)
		fmt.println("mapdata.tilemap[x][y]", x, y, mapdata.tilemap[x][y])

		x += 1
	}

	mapdata.bounds.y += 1

	fmt.println("mapdata.bounds.x", mapdata.bounds.x)
	fmt.println("mapdata.bounds.y", mapdata.bounds.y)

	return true
}



saveToFile :: proc(mapdata : ^mapData_t) {
	using mapdata

	buf := make([]u8, 1024 + MAP_MAX_SIZE*MAP_MAX_SIZE)
	offs : int = 0

	offs += len(fmt.bprint(
		buf=buf,
		args={
			"{\n",
			"\tnextMapName: \"", nextMapName, "\"\n",
			"\tstartPlayerDir: ", startPlayerDir.x, " ", startPlayerDir.y, "\n",
			"\tskyColor: ", skyColor.r, " ", skyColor.g, " ", skyColor.b, "\n",
			"\tfogStrength: ", fogStrength, "\n",
			"}\n\n",
		},
		sep="",
	))


	// all these fprint calls don't look good...
	for x : i32 = 0; x < bounds.x; x += 1 {
		for y : i32 = 0; y < bounds.y; y += 1 {
			buf[offs] = u8(rune(tilemap[x][y]))
			offs += 1
		}
		buf[offs] = '\n'
		offs += 1
	}

	os.write_entire_file(fullpath, buf[:offs])
}