package game

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"



PLAYER_MAX_HEALTH :: 10
PLAYER_HEAD_CENTER_OFFSET :: 0.9
PLAYER_LOOK_SENSITIVITY :: 0.001
PLAYER_FOV :: 110
PLAYER_VIEWMODEL_FOV :: 90
PLAYER_BOX_SIZE :: Vec3{1.2, 2.2, 1.2}
PLAYER_BOX_RAD :: 0.05
PLAYER_SIZE :: Vec3 {
    PLAYER_BOX_SIZE.x + PLAYER_BOX_RAD,
    PLAYER_BOX_SIZE.y + PLAYER_BOX_RAD,
    PLAYER_BOX_SIZE.z + PLAYER_BOX_RAD,
}
PLAYER_HEAD_SIN_TIME :: math.PI * 5.0

PLAYER_GRAVITY :: 220 // 800
PLAYER_SPEED :: 100 // 320
PLAYER_GROUND_ACCELERATION :: 8 // 10
PLAYER_GROUND_FRICTION :: 1 // 6
PLAYER_AIR_ACCELERATION :: 0.6 // 0.7
PLAYER_AIR_FRICTION :: 0.0 // 0
PLAYER_JUMP_SPEED :: 60 // 270
PLAYER_MIN_NORMAL_Y :: 0.25

PLAYER_FALL_DEATH_Y :: -TILE_HEIGHT * 1.8
PLAYER_FALL_DEATH_START_DARKEN :: PLAYER_FALL_DEATH_Y * 0.3

PLAYER_KEY_JUMP :: rl.KeyboardKey.SPACE

player_data: struct {
    rotImpulse:     Vec3,
    health:         f32,
    lookRotEuler:   Vec3,
    pos:            Vec3,
    isOnGround:     bool,
    vel:            Vec3,
    lookDir:        Vec3,
    lookRotMat3:    Mat3,
    stepTimer:      f32,
    lastValidPos:   Vec3,
    lastValidVel:   Vec3,
    slowness:       f32,
    onGroundTimer:  f32, // timer after onGround state has changed
    swooshStrength: f32, // just lerped velocity length
}



player_damage :: proc(damage: f32) {
    player_data.health -= damage
    playSoundMulti(g_state.assets.player.damageSound)
    screenTint = {1, 0.3, 0.2}
    player_data.slowness += damage * 0.25
}

_player_update :: proc() {
    // fall death
    if player_data.pos.y < PLAYER_FALL_DEATH_Y {
        //player_die()
        player_damage(1.0)
        dir := -linalg.normalize(player_data.lastValidVel)
        player_data.vel = dir * 100.0
        player_data.pos = player_data.lastValidPos + dir
        player_data.slowness = 1.0
        return
    } else if player_data.pos.y < PLAYER_FALL_DEATH_START_DARKEN {
        LEN :: abs(PLAYER_FALL_DEATH_Y - PLAYER_FALL_DEATH_START_DARKEN)
        screenTint =
            {1, 1, 1} *
            (1.0 - clamp(abs(PLAYER_FALL_DEATH_START_DARKEN - player_data.pos.y) / LEN, 0.0, 0.99))
    }

    // portal finish
    if phy_boxVsBox(player_data.pos, PLAYER_SIZE * 0.5, map_data.finishPos, MAP_TILE_FINISH_SIZE) {
        player_finishMap()
        return
    }

    if player_data.health <= 0.0 {
        player_die()
        return
    }

    vellen := linalg.length(player_data.vel)

    player_data.swooshStrength = math.lerp(
        player_data.swooshStrength,
        vellen,
        clamp(deltatime * 4.0, 0.0, 1.0),
    )
    rl.SetSoundVolume(
        g_state.assets.player.swooshSound,
        clamp(math.pow(0.001 + player_data.swooshStrength * 0.008, 2.0), 0.0, 1.0) * 0.75,
    )
    rl.SetSoundPitch(
        g_state.assets.player.swooshSound,
        clamp(player_data.swooshStrength * 0.003, 0.0, 2.0) + 0.5,
    )
    if !rl.IsSoundPlaying(g_state.assets.player.swooshSound) do playSound(g_state.assets.player.swooshSound)

    if player_data.isOnGround && linalg.length(player_data.vel * Vec3{1, 0, 1}) > 5.0 {
        player_data.stepTimer += deltatime * PLAYER_HEAD_SIN_TIME
        if player_data.stepTimer > math.PI * 2.0 {
            player_data.stepTimer = 0.0
            playSoundMulti(g_state.assets.player.footstepSound)
        }
    } else {
        player_data.stepTimer = -0.01
    }

    player_data.slowness = linalg.lerp(player_data.slowness, 0.0, clamp(deltatime * 10.0, 0.0, 1.0))
    player_data.rotImpulse = linalg.lerp(
        player_data.rotImpulse,
        Vec3{0, 0, 0},
        clamp(deltatime * 6.0, 0.0, 1.0),
    )

    player_data.lookRotMat3 = linalg.matrix3_from_yaw_pitch_roll(
        player_data.lookRotEuler.y + player_data.rotImpulse.y,
        clamp(
            player_data.lookRotEuler.x + player_data.rotImpulse.x,
            -math.PI * 0.5 * 0.95,
            math.PI * 0.5 * 0.95,
        ),
        player_data.lookRotEuler.z + player_data.rotImpulse.z,
    )

    forw := linalg.vector_normalize(
        linalg.matrix_mul_vector(player_data.lookRotMat3, Vec3{0, 0, 1}) * Vec3{1, 0, 1},
    )
    right := linalg.vector_normalize(
        linalg.matrix_mul_vector(player_data.lookRotMat3, Vec3{1, 0, 0}) * Vec3{1, 0, 1},
    )

    movedir: Vec2 = {}
    if rl.IsKeyDown(rl.KeyboardKey.W) do movedir.y += 1.0
    if rl.IsKeyDown(rl.KeyboardKey.A) do movedir.x += 1.0
    if rl.IsKeyDown(rl.KeyboardKey.S) do movedir.y -= 1.0
    if rl.IsKeyDown(rl.KeyboardKey.D) do movedir.x -= 1.0
    //if rl.IsKeyPressed(rl.KeyboardKey.C)do player_data.pos.y -= 2.0

    tilepos := map_worldToTile(player_data.pos)
    c := [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
    isInElevatorTile := c in map_data.elevatorHeights

    player_data.vel.y -= (player_data.isOnGround ? PLAYER_GRAVITY * 0.001 : PLAYER_GRAVITY * deltatime)

    isJumpInputOn :: proc() -> bool {return rl.IsKeyDown(PLAYER_KEY_JUMP)}

    jumped := isJumpInputOn() && player_data.isOnGround
    if jumped {
        player_data.vel = phy_applyFrictionToVelocity(
            player_data.vel,
            (clamp(player_data.onGroundTimer * 10.0, 0.0, 1.0)) * 31.0,
        )
        player_data.vel.y = PLAYER_JUMP_SPEED
        player_data.pos.y += PHY_BOXCAST_EPS * 1.1
        if isInElevatorTile do player_data.pos.y += 0.05 * PLAYER_SIZE.y
        //player_data.isOnGround = false
        if player_data.onGroundTimer > 0.05 do playSound(g_state.assets.player.jumpSound)
        player_data.rotImpulse.x -= 0.05
    }



    // frame-rate independent
    player_accelerate :: proc(dir: Vec3, wishspeed: f32, accel: f32) {
        currentspeed := linalg.dot(player_data.vel, dir)
        addspeed := wishspeed - currentspeed
        if addspeed < 0.0 do return

        accelspeed := accel * wishspeed * deltatime
        if accelspeed > addspeed do accelspeed = addspeed

        player_data.vel += dir * accelspeed
    }

    wishdir := forw * movedir.y + right * movedir.x
    player_accelerate(
        wishdir,
        PLAYER_SPEED,
        player_data.isOnGround \
        ? PLAYER_GROUND_ACCELERATION \
        : (linalg.dot(player_data.vel, wishdir) > 0.0 \
            ? PLAYER_AIR_ACCELERATION \
            : PLAYER_AIR_ACCELERATION * 2.0),
    )



    // elevator update
    elevatorIsMoving := false
    {
        tilepos = map_worldToTile(player_data.pos)
        c = [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
        isInElevatorTile = c in map_data.elevatorHeights

        if isInElevatorTile {
            height := map_data.elevatorHeights[c]
            elevatorIsMoving = false

            y :=
                math.lerp(TILE_ELEVATOR_Y0, TILE_ELEVATOR_Y1, height) +
                TILE_WIDTH * TILEMAP_MID / 2.0 +
                PLAYER_SIZE.y +
                0.01

            if player_data.pos.y - PLAYER_SIZE.y - 0.02 < y {
                height += TILE_ELEVATOR_MOVE_FACTOR * deltatime
                elevatorIsMoving = true
            }

            if height > 1.0 {
                height = 1.0
                elevatorIsMoving = false
            } else if height < 0.0 {
                height = 0.0
                elevatorIsMoving = false
            }

            if player_data.pos.y - 0.005 < y && elevatorIsMoving {
                player_data.pos.y = y + TILE_ELEVATOR_SPEED * deltatime
                player_data.vel = phy_applyFrictionToVelocity(player_data.vel, 12)
                //player_data.vel.y -= TILE_ELEVATOR_SPEED*deltatime
                player_data.vel.y = 0.0
                //player_data.vel.y = PLAYER_GRAVITY*deltatime
            }

            if rl.IsKeyPressed(PLAYER_KEY_JUMP) && elevatorIsMoving {
                player_data.vel.y = PLAYER_JUMP_SPEED + TILE_ELEVATOR_SPEED
                player_data.pos.y += 0.02
                height -= 0.02
                elevatorIsMoving = false
                player_data.isOnGround = false
            }

            map_data.elevatorHeights[c] = height
        }

        if elevatorIsMoving && !gameIsPaused {
            if !rl.IsSoundPlaying(g_state.assets.elevatorSound) do playSound(g_state.assets.elevatorSound)
        } else {
            rl.StopSound(g_state.assets.elevatorSound)
        }
    }

    if hitthorns, dir := calcThornsCollision(player_data.pos, PLAYER_SIZE.x); hitthorns {
        player_data.vel = dir * 100.0
        player_damage(5.0)
    }

    prevvel := player_data.vel
    phy_pos, phy_vel, phy_hit, phy_norm := phy_simulateMovingBox(
        player_data.pos,
        player_data.vel,
        0.0,
        PLAYER_BOX_SIZE,
        PLAYER_BOX_RAD,
    )
    player_data.pos = phy_pos
    player_data.vel = phy_vel

    //phy_tn, phy_norm, phy_hit := phy_boxcastTilemap(player_data.pos, wishpos, PLAYER_SIZE)
    prevIsOnGround := player_data.isOnGround
    player_data.isOnGround = phy_hit && phy_norm.y > PLAYER_MIN_NORMAL_Y



    if phy_hit {
        //player_data.pos += phy_norm*PHY_BOXCAST_EPS*0.98
        if !player_data.isOnGround && player_data.onGroundTimer > deltatime * 5.0 {
            //player_data.vel -= phy_norm * linalg.dot(player_data.vel, phy_norm) // project onto the wall plane
            player_data.vel += phy_norm * 25.0
            //player_data.vel = phy_clipVelocity(player_data.vel, phy_norm, 1.2) // bounce off of a wall if player has been in air for some time
        } else {
            //player_data.vel = phy_clipVelocity(player_data.vel, phy_norm, clamp(math.sqrt(deltatime*0.5)*1.5, 0.05, 0.99))
            //player_data.vel = phy_clipVelocity(
            //	player_data.vel,
            //	phy_norm,
            //	clamp(deltatime*144.0*0.07, 0.002,0.98),
            //)
        }
        //player_data.vel = phy_slideVelocityOnSurf(player_data.vel, phy_norm)
        //player_data.vel.y -= (phy_norm.y + 0.1)*0.2*(wishspeed/PLAYER_SPEED + 1.0)/2.0
    }

    println("pos", player_data.pos, "vel", player_data.vel, "vellen", linalg.length(player_data.vel))
    println("isOnGround", player_data.isOnGround)


    if !prevIsOnGround && player_data.isOnGround {     // just landed
        if !rl.IsSoundPlaying(g_state.assets.player.landSound) {
            playSound(g_state.assets.player.landSound)
            playSoundMulti(g_state.assets.player.footstepSound)
        }
        if player_data.onGroundTimer > 0.1 {
            player_data.rotImpulse.x += 0.03
        }

        if player_data.onGroundTimer < 0.1 do player_data.vel.y = 15.0 // this is just to prevent a weird physics bug

        player_data.vel += phy_slideVelocityOnSurf(prevvel, phy_norm) * 0.35
    }

    if prevIsOnGround != player_data.isOnGround do player_data.onGroundTimer = 0.0

    if player_data.isOnGround && !isInElevatorTile {
        player_data.lastValidPos = player_data.pos
        player_data.lastValidVel = player_data.vel
    }

    player_data.isOnGround |= elevatorIsMoving


    // friction when walking off of edge
    if prevIsOnGround && !player_data.isOnGround && !jumped && player_data.onGroundTimer > 0.1 {
        player_data.vel = phy_applyFrictionToVelocity(player_data.vel, elevatorIsMoving ? 100.0 : 42.0, true)
    }



    // apply main friction
    {
        START_FRICT_ADD :: 0.01
        frictadd: f32 = START_FRICT_ADD
        forwdepth := phy_raycastDepth(
            player_data.pos + player_data.vel * Vec3{1, 0, 1} * deltatime * 6.0 * PLAYER_SIZE.x * 2.0,
        )
        println("forwdepth", forwdepth)
        if forwdepth > PLAYER_SIZE.y * 2.0 && movedir == {} && player_data.isOnGround {
            frictadd += 5.0
        }

        player_data.vel = phy_applyFrictionToVelocity(
            player_data.vel,
            (f32(
                    player_data.isOnGround \
                    ? PLAYER_GROUND_FRICTION + (frictadd - START_FRICT_ADD) \
                    : PLAYER_AIR_FRICTION,
                ) +
                player_data.slowness * 10.0),
        )

        // this should fixe some weird jittering when friction is increased
        // (just a garbage formula)
        //player_data.vel -= phy_norm*frictadd*0.1

        //if player_data.isOnGround do player_data.vel.y = -PLAYER_GRAVITY * deltatime
    }


    cam_forw := linalg.matrix_mul_vector(player_data.lookRotMat3, Vec3{0, 0, 1})
    player_data.lookDir = cam_forw // TODO: update after the new rotation has been set

    // camera
    {
        if frame_index > 5 {     // mouse input seems to have weird spike first frame
            player_data.lookRotEuler.y +=
                -rl.GetMouseDelta().x * settings.mouseSensitivity * PLAYER_LOOK_SENSITIVITY
            player_data.lookRotEuler.x +=
                rl.GetMouseDelta().y * settings.mouseSensitivity * PLAYER_LOOK_SENSITIVITY
            player_data.lookRotEuler.x = clamp(
                player_data.lookRotEuler.x,
                -math.PI * 0.5 * 0.95,
                math.PI * 0.5 * 0.95,
            )
        }

        player_data.lookRotEuler.z = math.lerp(
            player_data.lookRotEuler.z,
            0.0,
            clamp(deltatime * 7.5, 0.0, 1.0),
        )
        player_data.lookRotEuler.z -= movedir.x * deltatime * 0.75
        player_data.lookRotEuler.z = clamp(player_data.lookRotEuler.z, -math.PI * 0.3, math.PI * 0.3)

        cam_y: f32 = PLAYER_HEAD_CENTER_OFFSET
        camera.position = player_data.pos + camera.up * cam_y
        camera.target = camera.position + cam_forw
        camera.up = linalg.normalize(
            linalg.quaternion_mul_vector3(
                linalg.quaternion_angle_axis(player_data.lookRotEuler.z * 1.3, cam_forw),
                Vec3{0, 1.0, 0},
            ),
        )
    }

    if settings.debugIsEnabled {
        size := Vec3{1, 1, 1}
        tn, normal, hit := phy_boxcastTilemap(
            camera.position,
            camera.position + cam_forw * 1000.0,
            size * 0.5,
        )
        hitpos := camera.position + cam_forw * tn
        rl.DrawCube(hitpos, size.x, size.y, size.z, rl.YELLOW)
        rl.DrawLine3D(hitpos, hitpos + normal * 4, rl.ORANGE)
    }

    if settings.debugIsEnabled {
        depth := phy_raycastDepth(player_data.pos)
        rl.DrawCube(player_data.pos + Vec3{0, -depth, 0}, 1, 1, 1, rl.GREEN)
        println("depth", depth)
    }



    player_data.onGroundTimer += deltatime
}



player_startMap :: proc() {
    println("player started game")
    player_data.pos = map_data.startPos
    player_data.lookRotEuler.x = 0.0
    player_data.lookRotEuler.z = 0.0
    player_data.lookRotEuler.y =
        math.PI * 2 -
        (math.atan2(-map_data.startPlayerDir.x, -map_data.startPlayerDir.y) *
                math.sign(-map_data.startPlayerDir.x))
    player_initData()
    screenTint = {}
    map_data.isMapFinished = false
}

player_initData :: proc() {
    player_data.rotImpulse = {}
    gun_data.timer = 0
    player_data.health = PLAYER_MAX_HEALTH
    player_data.vel = {0, 0.1, 0.5}
    player_data.lookDir = {0, 0, 1}

    gun_data.ammoCounts = gun_startAmmoCounts
    gun_data.equipped = .SHOTGUN
}

player_die :: proc() {
    println("player died")
    player_damage(1.0)
    world_reset()
}

player_finishMap :: proc() {
    println("player finished game")
    map_data.isMapFinished = true
    gameIsPaused = true
}



//
// GUNS
//
// (guns for the player, not for the enemies)
//

GUN_SCALE :: 1.1
GUN_POS_X :: 0.1

GUN_COUNT :: 3
gun_kind_t :: enum {
    SHOTGUN    = 0,
    MACHINEGUN = 1,
    LASERRIFLE = 2,
}

GUN_SHOTGUN_SPREAD :: 0.14
GUN_SHOTGUN_DAMAGE :: 0.05
GUN_MACHINEGUN_SPREAD :: 0.03
GUN_MACHINEGUN_DAMAGE :: 0.2
GUN_LASERRIFLE_DAMAGE :: 1.0

gun_startAmmoCounts: [GUN_COUNT]i32 = {32, 0, 0}
gun_maxAmmoCounts: [GUN_COUNT]i32 = {64, 128, 18}
gun_shootTimes: [GUN_COUNT]f32 = {0.5, 0.15, 1.0}

gun_data: struct {
    equipped:     gun_kind_t,
    lastEquipped: gun_kind_t,
    timer:        f32,
    ammoCounts:   [GUN_COUNT]i32,
}



gun_calcViewportPos :: proc() -> Vec3 {
    s :=
        math.sin(
            player_data.stepTimer < 0.0 \
            ? g_state.time_passed * PLAYER_HEAD_SIN_TIME * 0.5 \
            : player_data.stepTimer * 0.5,
        ) *
        clamp(linalg.length(player_data.vel) * 0.01, 0.1, 1.0) *
        0.04 *
        (player_data.isOnGround ? 1.0 : 0.05)
    kick := clamp(gun_data.timer * 0.5, 0.0, 1.0) * 0.8
    return Vec3{-settings.gunXOffset + player_data.lookRotEuler.z * 0.5, -0.2 + s + kick * 0.15, 0.48 - kick}
}

gun_getMuzzleOffset :: proc() -> Vec3 {
    offs := Vec3{}
    switch gun_data.equipped {
    case gun_kind_t.SHOTGUN:
        offs = {0, 0, 0.7}
    case gun_kind_t.MACHINEGUN:
        offs = {0, 0, 0.9}
    case gun_kind_t.LASERRIFLE:
        offs = {0, 0, 0.7}
    }
    return offs
}

gun_calcMuzzlePos :: proc() -> Vec3 {
    offs := gun_getMuzzleOffset()
    return camera.position + linalg.matrix_mul_vector(player_data.lookRotMat3, gun_calcViewportPos() + offs)
}

gun_drawModel :: proc(pos: Vec3) {
    if gun_data.ammoCounts[cast(i32)gun_data.equipped] <= 0 do return

    gunindex := cast(i32)gun_data.equipped
    rl.DrawModel(g_state.assets.gun.gunModels[gunindex], pos, GUN_SCALE, rl.WHITE)

    // flare
    FADETIME :: 0.07
    fade := math.pow((gun_data.timer - gun_shootTimes[gunindex] + FADETIME) / FADETIME, 1.0)
    if fade > 0.0 {
        rnd := randVec3() * f32(gameIsPaused ? 0.0 : 1.0)
        muzzleoffs := gun_getMuzzleOffset() + rnd * 0.02
        rl.DrawModel(
            g_state.assets.gun.flareModel,
            pos + muzzleoffs,
            0.4 - fade * fade * 0.2,
            rl.Fade(rl.WHITE, clamp(fade, 0.0, 1.0) * 0.9),
        )
    }
}

_gun_update :: proc() {
    prevgun := gun_data.equipped
    gunindex := cast(i32)gun_data.equipped

    // scroll wheel gun switching
    if rl.GetMouseWheelMove() > 0.5 do gunindex += 1
    else if rl.GetMouseWheelMove() < -0.5 do gunindex -= 1
    else if rl.IsKeyPressed(rl.KeyboardKey.ONE) do gunindex = 0
    else if rl.IsKeyPressed(rl.KeyboardKey.TWO) do gunindex = 1
    else if rl.IsKeyPressed(rl.KeyboardKey.THREE) do gunindex = 2
    gunindex %%= GUN_COUNT
    gun_data.equipped = cast(gun_kind_t)gunindex
    gunindex = cast(i32)gun_data.equipped

    if rl.IsKeyPressed(rl.KeyboardKey.Q) {
        gun_data.equipped = gun_data.lastEquipped
        gun_data.lastEquipped = prevgun
    }


    if gun_data.equipped != prevgun {
        gun_data.timer = 0.12
        playSound(g_state.assets.gun.gunSwitchSound)
        if gun_data.ammoCounts[gunindex] <= 0 {
            playSoundMulti(g_state.assets.gun.emptyMagSound)
        }
    }

    gun_data.timer -= deltatime



    if rl.IsMouseButtonDown(rl.MouseButton.LEFT) && gun_data.timer < 0.0 {
        if gun_data.ammoCounts[gunindex] > 0 {
            muzzlepos := gun_calcMuzzlePos()
            switch gun_data.equipped {
            case gun_kind_t.SHOTGUN:
                right := linalg.cross(player_data.lookDir, camera.up)
                up := camera.up
                RAD :: 0.5
                COL :: Vec4{1, 0.7, 0.2, 0.9}
                DUR :: 0.7
                SHOT_COUNT :: 9
                tn: [SHOT_COUNT]f32
                enemykind: [SHOT_COUNT]Enemy_Kind
                enemyindex: [SHOT_COUNT]i32
                tn[0], enemykind[0], enemyindex[0] = bullet_shootRaycast(
                    muzzlepos,
                    player_data.lookDir,
                    GUN_SHOTGUN_DAMAGE,
                    DUR,
                    COL,
                    DUR,
                )
                tn[1], enemykind[1], enemyindex[1] = bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD * right),
                    GUN_SHOTGUN_DAMAGE,
                    RAD,
                    COL,
                    DUR,
                )
                tn[2], enemykind[2], enemyindex[2] = bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD * up),
                    GUN_SHOTGUN_DAMAGE,
                    RAD,
                    COL,
                    DUR,
                )
                tn[3], enemykind[3], enemyindex[3] = bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir - GUN_SHOTGUN_SPREAD * right),
                    GUN_SHOTGUN_DAMAGE,
                    RAD,
                    COL,
                    DUR,
                )
                tn[4], enemykind[4], enemyindex[4] = bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir - GUN_SHOTGUN_SPREAD * up),
                    GUN_SHOTGUN_DAMAGE,
                    RAD,
                    COL,
                    DUR,
                )
                tn[5], enemykind[5], enemyindex[5] = bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD * 0.7 * (+up + right)),
                    GUN_SHOTGUN_DAMAGE,
                    RAD,
                    COL,
                    DUR,
                )
                tn[6], enemykind[6], enemyindex[6] = bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD * 0.7 * (+up - right)),
                    GUN_SHOTGUN_DAMAGE,
                    RAD,
                    COL,
                    DUR,
                )
                tn[7], enemykind[7], enemyindex[7] = bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD * 0.7 * (-up + right)),
                    GUN_SHOTGUN_DAMAGE,
                    RAD,
                    COL,
                    DUR,
                )
                tn[8], enemykind[8], enemyindex[8] = bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD * 0.7 * (-up - right)),
                    GUN_SHOTGUN_DAMAGE,
                    RAD,
                    COL,
                    DUR,
                )

                player_data.vel -= player_data.lookDir * 77.0
                player_data.rotImpulse.x -= 0.15
                playSound(g_state.assets.gun.shotgunSound)
                pushdir := linalg.normalize(player_data.lookDir + Vec3{0, 0.5, 0}) * 5.0
                for kind, i in enemykind {
                    switch kind {
                    case .NONE:
                    case .GRUNT:
                        enemy_data.grunts[enemyindex[i]].vel += pushdir
                    case .KNIGHT:
                        enemy_data.knights[enemyindex[i]].pos.y += 0.2
                        enemy_data.knights[enemyindex[i]].vel += pushdir
                    }
                }

            case gun_kind_t.MACHINEGUN:
                rnd := randVec3()
                bullet_shootRaycast(
                    muzzlepos,
                    linalg.normalize(player_data.lookDir + rnd * GUN_MACHINEGUN_SPREAD),
                    GUN_MACHINEGUN_DAMAGE,
                    1.1,
                    {0.6, 0.7, 0.8, 1.0},
                    0.7,
                )
                if !player_data.isOnGround do player_data.vel -= player_data.lookDir * 2.0
                player_data.rotImpulse.x -= 0.035
                player_data.rotImpulse -= rnd * 0.01
                playSoundMulti(g_state.assets.gun.machinegunSound)

            case gun_kind_t.LASERRIFLE:
                _, enemykind, _ := bullet_shootRaycast(
                    muzzlepos,
                    player_data.lookDir,
                    GUN_LASERRIFLE_DAMAGE,
                    2.5,
                    {1, 0.3, 0.2, 1.0},
                    1.6,
                )
                player_data.vel /= 1.25
                player_data.vel -= player_data.lookDir * 40
                if enemykind != .NONE && !player_data.isOnGround {
                    player_data.vel -= player_data.lookDir * 90
                    player_data.vel.y += 50
                }
                player_data.rotImpulse.x -= 0.2
                player_data.rotImpulse.y += 0.04
                playSound(g_state.assets.gun.laserrifleSound)

            }

            gun_data.ammoCounts[gunindex] -= 1

            switch gun_data.equipped {
            case gun_kind_t.SHOTGUN:
                gun_data.timer = gun_shootTimes[gunindex]
            case gun_kind_t.MACHINEGUN:
                gun_data.timer = gun_shootTimes[gunindex]
            case gun_kind_t.LASERRIFLE:
                gun_data.timer = gun_shootTimes[gunindex]
            }
        } else if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
            playSoundMulti(g_state.assets.gun.emptyMagSound)
        }
    }
}
