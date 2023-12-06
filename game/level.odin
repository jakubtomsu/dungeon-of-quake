package game

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

MAP_SIDE_TILE_COUNT :: 128
TILE_WIDTH :: 30.0
TILE_MIN_HEIGHT :: TILE_WIDTH
TILEMAP_Y_TILES :: 7
TILE_HEIGHT :: TILE_WIDTH * TILEMAP_Y_TILES
TILEMAP_MID :: 4
TILE_OUT_OF_BOUNDS_SIZE :: 4000.0

TILE_ELEVATOR_MOVE_FACTOR :: 0.55
TILE_ELEVATOR_Y0 :: cast(f32)-4.5 * TILE_WIDTH + 2.0
TILE_ELEVATOR_Y1 :: cast(f32)-1.5 * TILE_WIDTH - 2.0
TILE_ELEVATOR_SPEED :: (TILE_ELEVATOR_Y1 - TILE_ELEVATOR_Y0) * TILE_ELEVATOR_MOVE_FACTOR

MAP_THORNS_RAD_MULTIPLIER :: 1.0

MAP_GUN_PICKUP_MAX_COUNT :: 32
MAP_HEALTH_PICKUP_MAX_COUNT :: 32
MAP_HEALTH_PICKUP_SIZE :: Vec3{2, 1.5, 2}

MAP_TILE_FINISH_SIZE :: Vec3{8, 16, 8}

Level :: struct {
    using tile_map:         Tile_Map,
    startPos:               Vec3,
    finishPos:              Vec3,
    isMapFinished:          bool,
    elevatorHeights:        map[[2]u8]f32,
    gunPickupCount:         i32,
    gunPickupSpawnCount:    i32,
    gunPickups:             [MAP_GUN_PICKUP_MAX_COUNT]struct {
        pos:  Vec3,
        kind: Gun_Kind,
    },
    healthPickupCount:      i32,
    healthPickupSpawnCount: i32,
    healthPickups:          [MAP_HEALTH_PICKUP_MAX_COUNT]Vec3,
}



// @returns: 2d tile position from 3d worldspace 'p'
world_to_tile :: proc(p: Vec3) -> IVec2 {
    return IVec2{cast(i32)((p.x / TILE_WIDTH)), cast(i32)((p.z / TILE_WIDTH))}
}

// @returns: tile center position in worldspace
tile_to_world :: proc(p: IVec2) -> Vec3 {
    return Vec3{((cast(f32)p.x) + 0.5) * TILE_WIDTH, 0.0, ((cast(f32)p.y) + 0.5) * TILE_WIDTH}
}

tile_pos_valid :: proc(coord: IVec2) -> bool {
    using g_state
    return coord.x >= 0 && coord.y >= 0 && coord.x <= level.bounds.x && coord.y <= level.bounds.y
}

tile_pos_clamp :: proc(coord: IVec2) -> IVec2 {
    using g_state
    return IVec2{clamp(coord.x, 0, level.bounds.x), clamp(coord.y, 0, level.bounds.y)}
}



level_addGunPickup :: proc(pos: Vec3, kind: Gun_Kind) {
    if level.gunPickupCount + 1 >= MAP_GUN_PICKUP_MAX_COUNT do return
    level.gunPickups[level.gunPickupCount].pos = pos
    level.gunPickups[level.gunPickupCount].kind = kind
    level.gunPickupCount += 1
    level.gunPickupSpawnCount = level.gunPickupCount
}

level_addHealthPickup :: proc(pos: Vec3) {
    if level.healthPickupCount + 1 >= MAP_HEALTH_PICKUP_MAX_COUNT do return
    level.healthPickups[level.healthPickupCount] = pos
    level.healthPickupCount += 1
    level.healthPickupSpawnCount = level.healthPickupCount
}



level_floorTileBox :: proc(posxz: Vec2) -> box_t {
    return(
         {
            Vec3{posxz[0], (-TILE_HEIGHT - TILE_OUT_OF_BOUNDS_SIZE) / 2.0, posxz[1]},
            Vec3{TILE_WIDTH, TILE_OUT_OF_BOUNDS_SIZE + TILE_WIDTH * 2, TILE_WIDTH} / 2.0,
        } \
    )
}

level_ceilTileBox :: proc(posxz: Vec2) -> box_t {
    //return Vec3{posxz[0],( TILE_HEIGHT-TILE_MIN_HEIGHT)/2.0, posxz[1]},
    //	Vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH}/2.0
    return(
         {
            Vec3{posxz[0], (+TILE_HEIGHT + TILE_OUT_OF_BOUNDS_SIZE) / 2.0, posxz[1]},
            Vec3{TILE_WIDTH, TILE_OUT_OF_BOUNDS_SIZE + TILE_WIDTH * 2, TILE_WIDTH} / 2.0,
        } \
    )
}

level_fullTileBox :: proc(posxz: Vec2) -> box_t {
    return(
         {
            Vec3{posxz[0], TILE_WIDTH * 0.5, posxz[1]},
            Vec3{TILE_WIDTH / 2, TILE_OUT_OF_BOUNDS_SIZE / 2, TILE_WIDTH / 2},
        } \
    )
}


// fills input buffer `boxbuf` with axis-aligned boxes for a given tile
// @returns: number of boxes for the tile
level_getTileBoxes :: proc(coord: IVec2, boxbuf: []box_t) -> i32 {
    if !tile_pos_valid(coord) do return 0
    tileKind := level.tilemap[coord[0]][coord[1]]

    phy_calcBox :: proc(posxz: Vec2, posy: f32, sizey: f32) -> box_t {
        return(
            box_t {
                Vec3{posxz.x, posy * TILE_WIDTH, posxz.y},
                Vec3{TILE_WIDTH, sizey * TILE_WIDTH, TILE_WIDTH} / 2,
            } \
        )
    }

    posxz := Vec2{cast(f32)coord[0] + 0.5, cast(f32)coord[1] + 0.5} * TILE_WIDTH

    #partial switch tileKind {
    case .NONE:
        return 0

    case .FULL, .THORNS_LOWER:
        boxbuf[0] = level_fullTileBox(posxz)
        return 1

    case .EMPTY:
        boxbuf[0] = level_floorTileBox(posxz)
        boxbuf[1] = level_ceilTileBox(posxz)
        return 2

    case .WALL_MID:
        boxbuf[0] = phy_calcBox(posxz, -2, 5)
        boxbuf[1] = level_ceilTileBox(posxz)
        return 2

    case .PLATFORM_SMALL:
        boxbuf[0] = level_floorTileBox(posxz)
        boxbuf[1] = level_ceilTileBox(posxz)
        boxbuf[2] = phy_calcBox(posxz, 0, 1)
        return 3
    case .PLATFORM_LARGE:
        boxbuf[0] = level_floorTileBox(posxz)
        boxbuf[1] = level_ceilTileBox(posxz)
        boxbuf[2] = phy_calcBox(posxz, 0, 3)
        return 3

    case .CEILING:
        boxbuf[0] = level_floorTileBox(posxz)
        boxbuf[1] = phy_calcBox(posxz, 2, 5)
        return 2

    case .ELEVATOR:
        // the actual moving elevator box is at index 0
        boxsize := Vec3{TILE_WIDTH, TILE_MIN_HEIGHT, TILE_WIDTH} / 2.0
        height, ok := level.elevatorHeights[{cast(u8)coord.x, cast(u8)coord.y}]
        if !ok do height = 0.0
        boxbuf[0] =  {
            Vec3{posxz[0], math.lerp(TILE_ELEVATOR_Y0, TILE_ELEVATOR_Y1, height), posxz[1]},
            Vec3{TILE_WIDTH, TILE_WIDTH * TILEMAP_MID, TILE_WIDTH} / 2,
        }
        boxbuf[1] = level_ceilTileBox(posxz)
        boxbuf[2] = level_floorTileBox(posxz)
        return 3

    case .OBSTACLE_LOWER:
        boxbuf[0] = phy_calcBox(posxz, -3, 3)
        boxbuf[1] = level_ceilTileBox(posxz)
        return 2
    case .OBSTACLE_UPPER:
        boxbuf[0] = phy_calcBox(posxz, -2, 3)
        boxbuf[1] = level_ceilTileBox(posxz)
        return 2
    }

    return 0
}



level_clearAll :: proc() {
    tiles.resetMap(&level)

    level.gunPickupSpawnCount = 0
    level.gunPickupCount = 0
    level.healthPickupSpawnCount = 0
    level.healthPickupCount = 0
    enemy_data.gruntCount = 0
    enemy_data.knightCount = 0

    delete(level.elevatorHeights)

    level_setDefaultValues()
}

level_setDefaultValues :: proc() {
    level.skyColor = {0.6, 0.5, 0.8} * 0.6
    level.fogStrength = 1.0
}

level_loadFromFile :: proc(name: string) -> bool {
    fullpath := asset_path("maps", name)
    return level_loadFromFileAbs(fullpath)
}

level_loadFromFileAbs :: proc(fullpath: string) -> bool {
    println("! loading map: ", fullpath)

    level_clearAll()

    if !tiles.loadFromFile(fullpath, &level) {
        println("! error: map couldn't be loaded")
        return false
    }

    level.elevatorHeights = make(type_of(level.elevatorHeights))

    for x: i32 = 0; x < level.bounds.x; x += 1 {
        for y: i32 = 0; y < level.bounds.y; y += 1 {
            lowpos := tile_to_world({x, y}) - Vec3{0, TILE_WIDTH * TILEMAP_Y_TILES / 2 - TILE_WIDTH, 0}
            highpos := tile_to_world({x, y}) + Vec3{0, TILE_WIDTH * 0.5, 0}
            tile := level.tilemap[x][y]

            #partial switch tile {
            case .START_LOWER:
                level.startPos = lowpos + Vec3{0, PLAYER_SIZE.y * 2, 0}
            case .START_UPPER:
                level.startPos = highpos + Vec3{0, PLAYER_SIZE.y * 2, 0}
            case .FINISH_LOWER:
                level.finishPos = lowpos + Vec3{0, MAP_TILE_FINISH_SIZE.y, 0}
            case .FINISH_UPPER:
                level.finishPos = highpos + Vec3{0, MAP_TILE_FINISH_SIZE.y, 0}
            case .ELEVATOR:
                level.elevatorHeights[{cast(u8)x, cast(u8)y}] = 0.0
            case .ENEMY_GRUNT_LOWER:
                enemy_spawnGrunt(lowpos + Vec3{0, ENEMY_GRUNT_SIZE.y * 1.2, 0})
            case .ENEMY_GRUNT_UPPER:
                enemy_spawnGrunt(highpos + Vec3{0, ENEMY_GRUNT_SIZE.y * 1.2, 0})
            case .ENEMY_KNIGHT_LOWER:
                enemy_spawnKnight(lowpos + Vec3{0, ENEMY_KNIGHT_SIZE.y * 2.0, 0})
            case .ENEMY_KNIGHT_UPPER:
                enemy_spawnKnight(highpos + Vec3{0, ENEMY_KNIGHT_SIZE.y * 2.0, 0})
            case .GUN_SHOTGUN_LOWER:
                level_addGunPickup(lowpos + Vec3{0, PLAYER_SIZE.y, 0}, .SHOTGUN)
            case .GUN_SHOTGUN_UPPER:
                level_addGunPickup(highpos + Vec3{0, PLAYER_SIZE.y, 0}, .SHOTGUN)
            case .GUN_MACHINEGUN_LOWER:
                level_addGunPickup(lowpos + Vec3{0, PLAYER_SIZE.y, 0}, .MACHINEGUN)
            case .GUN_MACHINEGUN_UPPER:
                level_addGunPickup(highpos + Vec3{0, PLAYER_SIZE.y, 0}, .MACHINEGUN)
            case .GUN_LASERRIFLE_LOWER:
                level_addGunPickup(lowpos + Vec3{0, PLAYER_SIZE.y, 0}, .LASERRIFLE)
            case .GUN_LASERRIFLE_UPPER:
                level_addGunPickup(highpos + Vec3{0, PLAYER_SIZE.y, 0}, .LASERRIFLE)
            case .PICKUP_HEALTH_LOWER:
                rnd :=
                    Vec2 {
                        rand.float32_range(-1.0, 1.0, &randData),
                        rand.float32_range(-1.0, 1.0, &randData),
                    } *
                    TILE_WIDTH *
                    0.3
                level_addHealthPickup(lowpos + Vec3{rnd.x, MAP_HEALTH_PICKUP_SIZE.y, rnd.y})
            case .PICKUP_HEALTH_UPPER:
                rnd :=
                    Vec2 {
                        rand.float32_range(-1.0, 1.0, &randData),
                        rand.float32_range(-1.0, 1.0, &randData),
                    } *
                    TILE_WIDTH *
                    0.3
                level_addHealthPickup(highpos + Vec3{rnd.x, MAP_HEALTH_PICKUP_SIZE.y, rnd.y})
                tile = tiles.Tile.WALL_MID
            }

            level.tilemap[x][y] = tiles.translate(tile)
        }
    }



    println("end")

    println("bounds[0]", level.bounds[0], "bounds[1]", level.bounds[1])
    println("nextMapName", level.nextMapName)

    player_startMap()

    rl.SetShaderValue(
        g_state.assets.portalShader,
        cast(rl.ShaderLocationIndex)rl.GetShaderLocation(g_state.assets.portalShader, "portalPos"),
        &level.finishPos,
        rl.ShaderUniformDataType.VEC3,
    )


    return true

}

level_debugPrint :: proc() {
    for x: i32 = 0; x < level.bounds[0]; x += 1 {
        for y: i32 = 0; y < level.bounds[1]; y += 1 {
            fmt.print(level.tilemap[x][y] == tiles.Tile.FULL ? "#" : " ")
        }
        println("")
    }
}

// draw tilemap, pickups, etc.
level_drawTilemap :: proc() {
    rl.BeginShaderMode(g_state.assets.tileShader)
    for x: i32 = 0; x < level.bounds[0]; x += 1 {
        for y: i32 = 0; y < level.bounds[1]; y += 1 {
            //rl.DrawCubeWires(Vec3{posxz[0], 0.0, posxz[1]}, TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, rl.GRAY)
            tilekind := level.tilemap[x][y]

            boxbuf: [PHY_MAX_TILE_BOXES]box_t = {}
            boxcount := level_getTileBoxes({x, y}, boxbuf[0:])
            //checker := cast(bool)((x%2) ~ (y%2))
            #partial switch tilekind {
            case:
                for i: i32 = 0; i < boxcount; i += 1 {
                    rl.DrawModelEx(
                        g_state.assets.tileModel,
                        boxbuf[i].pos,
                        {0, 1, 0},
                        0.0,
                        boxbuf[i].size * 2.0,
                        rl.WHITE,
                    )
                }
            case .ELEVATOR:
                rl.DrawModelEx(
                    g_state.assets.elevatorModel,
                    boxbuf[0].pos,
                    {0, 1, 0},
                    0.0,
                    boxbuf[0].size * 2.0,
                    rl.WHITE,
                )
                for i: i32 = 1; i < boxcount; i += 1 {
                    rl.DrawModelEx(
                        g_state.assets.tileModel,
                        boxbuf[i].pos,
                        {0, 1, 0},
                        0.0,
                        boxbuf[i].size * 2.0,
                        rl.WHITE,
                    )
                }
            case .OBSTACLE_LOWER:
                rl.DrawModelEx(
                    g_state.assets.boxModel,
                    boxbuf[0].pos + {0, TILE_WIDTH, 0},
                    {0, 1, 0},
                    0.0,
                    {TILE_WIDTH, TILE_WIDTH, TILE_WIDTH},
                    rl.WHITE,
                )
                rl.DrawModelEx(
                    g_state.assets.tileModel,
                    boxbuf[0].pos - {0, TILE_WIDTH, 0},
                    {0, 1, 0},
                    0.0,
                    {TILE_WIDTH, TILE_WIDTH, TILE_WIDTH},
                    rl.WHITE,
                )
                for i: i32 = 1; i < boxcount; i += 1 {
                    rl.DrawModelEx(
                        g_state.assets.tileModel,
                        boxbuf[i].pos,
                        {0, 1, 0},
                        0.0,
                        boxbuf[i].size * 2.0,
                        rl.WHITE,
                    )
                }
            case .OBSTACLE_UPPER:
                rl.DrawModelEx(
                    g_state.assets.boxModel,
                    boxbuf[0].pos + {0, TILE_WIDTH, 0},
                    {0, 1, 0},
                    0.0,
                    {TILE_WIDTH, TILE_WIDTH, TILE_WIDTH},
                    rl.WHITE,
                )
                rl.DrawModelEx(
                    g_state.assets.boxModel,
                    boxbuf[0].pos,
                    {0, 1, 0},
                    0.0,
                    {TILE_WIDTH, TILE_WIDTH, TILE_WIDTH},
                    rl.WHITE,
                )
                rl.DrawModelEx(
                    g_state.assets.tileModel,
                    boxbuf[0].pos - {0, TILE_WIDTH, 0},
                    {0, 1, 0},
                    0.0,
                    {TILE_WIDTH, TILE_WIDTH, TILE_WIDTH},
                    rl.WHITE,
                )
                for i: i32 = 1; i < boxcount; i += 1 {
                    rl.DrawModelEx(
                        g_state.assets.tileModel,
                        boxbuf[i].pos,
                        {0, 1, 0},
                        0.0,
                        boxbuf[i].size * 2.0,
                        rl.WHITE,
                    )
                }

            case .THORNS_LOWER:
                yoffs := math.floor(player_data.pos.y / TILE_WIDTH) * TILE_WIDTH
                p := tile_to_world({x, y})
                floorbox := level_floorTileBox({p.x, p.z})
                ceilbox := level_ceilTileBox({p.x, p.z})
                THORN_DRAW_COUNT :: 32

                rl.DrawModelEx(
                    g_state.assets.tileModel,
                    floorbox.pos,
                    {0, 1, 0},
                    0.0,
                    floorbox.size * 2.0,
                    rl.WHITE,
                )
                rl.DrawModelEx(
                    g_state.assets.tileModel,
                    ceilbox.pos,
                    {0, 1, 0},
                    0.0,
                    ceilbox.size * 2.0,
                    rl.WHITE,
                )

                for i: i32 = 0; i < TILEMAP_Y_TILES - 2; i += 1 {
                    rl.DrawModelEx(
                        g_state.assets.thornsModel,
                        p + Vec3{0, (f32(i) - f32(TILEMAP_Y_TILES - 2) * 0.5 + 0.5) * TILE_WIDTH, 0},
                        {0, 1, 0},
                        0,
                        {TILE_WIDTH, TILE_WIDTH, TILE_WIDTH},
                        rl.WHITE,
                    )
                }


            }
        }
    }
    rl.EndShaderMode()

    if settings.debug {
        for x: i32 = 0; x < level.bounds[0]; x += 1 {
            for y: i32 = 0; y < level.bounds[1]; y += 1 {
                tilekind := level.tilemap[x][y]
                boxbuf: [PHY_MAX_TILE_BOXES]box_t = {}
                boxcount := level_getTileBoxes({x, y}, boxbuf[0:])
                for i: i32 = 0; i < boxcount; i += 1 {
                    rl.DrawCubeWiresV(
                        boxbuf[i].pos,
                        boxbuf[i].size * 2.0 + Vec3{0.1, 0.1, 0.1},
                        rl.Fade(rl.GREEN, 0.25),
                    )
                }
            }
        }

        rl.DrawGrid(MAP_SIDE_TILE_COUNT, TILE_WIDTH)
    }

    rl.BeginShaderMode(g_state.assets.portalShader)
    // draw finish
    doqDrawCubeTexture(
        g_state.assets.portalTexture,
        level.finishPos,
        MAP_TILE_FINISH_SIZE.x * 2,
        MAP_TILE_FINISH_SIZE.y * 2,
        MAP_TILE_FINISH_SIZE.z * 2,
        rl.WHITE,
    )
    rl.EndShaderMode()
    rl.DrawCube(
        level.finishPos,
        -MAP_TILE_FINISH_SIZE.x * 2 - 4,
        -MAP_TILE_FINISH_SIZE.y * 2 - 4,
        -MAP_TILE_FINISH_SIZE.z * 2 - 4,
        {0, 0, 0, 40},
    )
    rl.DrawCube(
        level.finishPos,
        -MAP_TILE_FINISH_SIZE.x * 2 - 2,
        -MAP_TILE_FINISH_SIZE.y * 2 - 2,
        -MAP_TILE_FINISH_SIZE.z * 2 - 2,
        {0, 0, 0, 60},
    )
    rl.DrawCube(
        level.finishPos,
        -MAP_TILE_FINISH_SIZE.x * 2 - 1,
        -MAP_TILE_FINISH_SIZE.y * 2 - 1,
        -MAP_TILE_FINISH_SIZE.z * 2 - 1,
        {0, 0, 0, 90},
    )

    // draw pickups and update them
    {
        ROTSPEED :: 180
        SCALE :: 5.0

        // update gun pickups
        // draw gun pickups
        for i: i32 = 0; i < level.gunPickupCount; i += 1 {
            pos := level.gunPickups[i].pos + Vec3{0, math.sin(g_state.time_passed * 8.0) * 0.2, 0}
            gunindex := cast(i32)level.gunPickups[i].kind
            rl.DrawModelEx(
                g_state.assets.gun.gunModels[gunindex],
                pos,
                {0, 1, 0},
                g_state.time_passed * ROTSPEED,
                SCALE,
                rl.WHITE,
            )
            rl.DrawSphere(pos, -2.0, {255, 230, 180, 40})

            RAD :: 6.5
            if linalg.length2(player_data.pos - pos) < RAD * RAD &&
               gun_data.ammoCounts[gunindex] < gun_maxAmmoCounts[gunindex] {
                gun_data.equipped = level.gunPickups[i].kind
                gun_data.ammoCounts[gunindex] = gun_maxAmmoCounts[gunindex]
                playSoundMulti(g_state.assets.gun.ammoPickupSound)

                temp := level.gunPickups[i]
                level.gunPickupCount -= 1
                level.gunPickups[i] = level.gunPickups[level.gunPickupCount]
                level.gunPickups[level.gunPickupCount] = temp
            }
        }

        // update health pickups
        // draw health pickups
        for i: i32 = 0; i < level.healthPickupCount; i += 1 {
            //rl.DrawCubeTexture(
            //	level.healthPickupTexture,
            //	level.healthPickups[i],
            //	MAP_HEALTH_PICKUP_SIZE.x*2.0,
            //	MAP_HEALTH_PICKUP_SIZE.y*2.0,
            //	MAP_HEALTH_PICKUP_SIZE.z*2.0,
            //	rl.WHITE,
            //)

            rl.DrawModel(
                g_state.assets.healthPickupModel,
                level.healthPickups[i],
                MAP_HEALTH_PICKUP_SIZE.x,
                rl.WHITE,
            )

            RAD :: 6.5
            if linalg.length2(player_data.pos - level.healthPickups[i]) < RAD * RAD &&
               player_data.health < PLAYER_MAX_HEALTH {
                player_data.health += PLAYER_MAX_HEALTH * 0.25
                player_data.health = clamp(player_data.health, 0.0, PLAYER_MAX_HEALTH)
                screen_tint = {1.0, 0.8, 0.0}
                playSound(g_state.assets.player.healthPickupSound)
                temp := level.healthPickups[i]
                level.healthPickupCount -= 1
                level.healthPickups[i] = level.healthPickups[level.healthPickupCount]
                level.healthPickups[level.healthPickupCount] = temp
            }
        }
    }

    //rl.DrawCylinderEx(circpos-Vec3{0,TILE_WIDTH*2,0}, circpos-Vec3{0,2000,0}, 1000, 1000, 32, {200,220,220,40})
    //rl.DrawCylinderEx(circpos-Vec3{0,TILE_WIDTH*1,0}, circpos-Vec3{0,2000,0}, 1000, 1000, 32, {200,220,220,40})
    //rl.DrawCylinderEx(circpos-Vec3{0,TILE_WIDTH*0,0}, circpos-Vec3{0,2000,0}, 1000, 1000, 32, {200,220,220,40})

    // draw clouds
    {
        W :: 2048
        c: Vec3 = player_data.pos
        rl.BeginShaderMode(g_state.assets.cloudShader)
        doqDrawCubeTexture(
            g_state.assets.cloudTexture,
            Vec3{c.x, +TILE_HEIGHT * 1.6, c.z},
            W,
            1,
            W,
            {255, 255, 255, 50},
        )
        doqDrawCubeTexture(
            g_state.assets.cloudTexture,
            Vec3{c.x, +TILE_HEIGHT * 1.0, c.z},
            W,
            1,
            W,
            {255, 255, 255, 40},
        )
        doqDrawCubeTexture(
            g_state.assets.cloudTexture,
            Vec3{c.x, +TILE_HEIGHT * 0.6, c.z},
            W,
            1,
            W,
            {255, 255, 255, 20},
        )
        doqDrawCubeTexture(
            g_state.assets.cloudTexture,
            Vec3{c.x, -TILE_HEIGHT * 1.6, c.z},
            W,
            1,
            W,
            {200, 200, 200, 60},
        )
        doqDrawCubeTexture(
            g_state.assets.cloudTexture,
            Vec3{c.x, -TILE_HEIGHT * 1.0, c.z},
            W,
            1,
            W,
            {200, 200, 200, 40},
        )
        doqDrawCubeTexture(
            g_state.assets.cloudTexture,
            Vec3{c.x, -TILE_HEIGHT * 0.6, c.z},
            W,
            1,
            W,
            {255, 255, 255, 20},
        )
        rl.EndShaderMode()
    }
}


calcThornsCollision :: proc(pos: Vec3, rad: f32) -> (isColliding: bool, pushdir: Vec3) {
    if abs(pos.y) > (TILEMAP_Y_TILES - 2) * TILE_WIDTH * 0.5 {
        isColliding = false
        pushdir = {}
        return isColliding, pushdir
    }
    tilepos := world_to_tile(pos)
    rad2 := rad * rad

    for x: i32 = -1; x <= 1; x += 1 {
        for y: i32 = -1; y <= 1; y += 1 {
            p := tilepos + {x, y}

            if !tile_pos_valid(p) do continue
            if level.tilemap[p.x][p.y] == .THORNS_LOWER {
                posxz := Vec2{f32(p.x) + 0.5, f32(p.y) + 0.5} * TILE_WIDTH
                dir := Vec2{pos.x - posxz.x, pos.z - posxz.y}
                length2 := linalg.length2(dir)
                sd := length2 - (TILE_WIDTH * TILE_WIDTH * 0.5 * MAP_THORNS_RAD_MULTIPLIER) // subtract tile radius
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
