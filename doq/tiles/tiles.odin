package tiles



// tile kinds in a separate package



// 'translated' tiles are changed into different tiles when a map gets loaded
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
