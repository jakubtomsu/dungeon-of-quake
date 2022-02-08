package doq



import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"



//
// PLAYER
//
// player movement code
// also handles elevators, death, etc.
//



PLAYER_MAX_HEALTH		:: 10
PLAYER_HEAD_CENTER_OFFSET	:: 0.8
PLAYER_LOOK_SENSITIVITY		:: 0.004
PLAYER_FOV			:: 110
PLAYER_VIEWMODEL_FOV		:: 90
PLAYER_SIZE			:: vec3{1,2,1}
PLAYER_HEAD_SIN_TIME		:: math.PI * 5.0

PLAYER_GRAVITY			:: 210 // 800
PLAYER_SPEED			:: 105 // 320
PLAYER_GROUND_ACCELERATION	:: 10 // 10
PLAYER_GROUND_FRICTION		:: 6 // 6
PLAYER_AIR_ACCELERATION		:: 1.3 // 0.7
PLAYER_AIR_FRICTION		:: 0.0 // 0
PLAYER_JUMP_SPEED		:: 70 // 270
PLAYER_MIN_NORMAL_Y		:: 0.25

PLAYER_FALL_DEATH_Y :: -TILE_HEIGHT*1.2

PLAYER_KEY_JUMP :: rl.KeyboardKey.SPACE

player_data : struct {
	rotImpulse	: vec3,
	health		: f32,
	lookRotEuler	: vec3,
	pos		: vec3,
	isOnGround	: bool,
	vel		: vec3,
	lookDir		: vec3,
	lookRotMat3	: mat3,
	stepTimer	: f32,
	lastValidPos	: vec3,
	lastValidVel	: vec3,
	slowness	: f32,

	jumpSound		: rl.Sound,
	footstepSound		: rl.Sound,
	landSound		: rl.Sound,
	damageSound		: rl.Sound,
	swooshSound		: rl.Sound,
	healthPickupSound	: rl.Sound,

	swooshStrength	: f32, // just lerped velocity length
}



player_damage :: proc(damage : f32) {
	player_data.health -= damage
	playSoundMulti(player_data.damageSound)
	screenTint = {1,0.6,0.5}
	player_data.slowness += damage * 0.5
}

_player_update :: proc() {
	if player_data.pos.y < PLAYER_FALL_DEATH_Y {
		//player_die()
		player_damage(1.0)
		player_data.pos = player_data.lastValidPos
		player_data.vel = -player_data.lastValidVel * 0.5
		player_data.slowness = 1.0
		return
	} else if player_data.pos.y < PLAYER_FALL_DEATH_Y*0.4 {
		screenTint = {1,1,1} * (1.0 - clamp(abs(player_data.pos.y - PLAYER_FALL_DEATH_Y*0.4) * 0.02, 0.0, 0.98))
	}

	if phy_boxVsBox(player_data.pos, PLAYER_SIZE * 0.5, map_data.finishPos, MAP_TILE_FINISH_SIZE) {
		player_finishMap()
		return
	}

	if player_data.health <= 0.0 {
		player_die()
		return
	}

	vellen := linalg.length(player_data.vel)

	player_data.swooshStrength = math.lerp(player_data.swooshStrength, vellen, clamp(deltatime * 3.0, 0.0, 1.0))
	rl.SetSoundVolume(player_data.swooshSound, clamp(math.pow(0.001 + player_data.swooshStrength*0.003, 2.0), 0.0, 1.0) * 0.8)
	if !rl.IsSoundPlaying(player_data.swooshSound) do playSound(player_data.swooshSound)

	if player_data.isOnGround && linalg.length(player_data.vel * vec3{1,0,1}) > 5.0 {
		player_data.stepTimer += deltatime * PLAYER_HEAD_SIN_TIME
		if player_data.stepTimer > math.PI*2.0 {
			player_data.stepTimer = 0.0
			playSoundMulti(player_data.footstepSound)
		}
	} else {
		player_data.stepTimer = -0.01
	}

	player_data.slowness = linalg.lerp(player_data.slowness, 0.0, clamp(deltatime * 10.0, 0.0, 1.0))
	player_data.rotImpulse = linalg.lerp(player_data.rotImpulse, vec3{0,0,0}, clamp(deltatime * 6.0, 0.0, 1.0))

	player_data.lookRotMat3 = linalg.matrix3_from_yaw_pitch_roll(
		player_data.lookRotEuler.y + player_data.rotImpulse.y,
		clamp(player_data.lookRotEuler.x + player_data.rotImpulse.x, -math.PI*0.5*0.95, math.PI*0.5*0.95),
		player_data.lookRotEuler.z + player_data.rotImpulse.z,
	)

	forw  := linalg.vector_normalize(linalg.matrix_mul_vector(player_data.lookRotMat3, vec3{0, 0, 1}) * vec3{1, 0, 1})
	right := linalg.vector_normalize(linalg.matrix_mul_vector(player_data.lookRotMat3, vec3{1, 0, 0}) * vec3{1, 0, 1})

	movedir : vec2 = {}
	if rl.IsKeyDown(rl.KeyboardKey.W)	do movedir.y += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.A)	do movedir.x += 1.0
	if rl.IsKeyDown(rl.KeyboardKey.S)	do movedir.y -= 1.0
	if rl.IsKeyDown(rl.KeyboardKey.D)	do movedir.x -= 1.0
	//if rl.IsKeyPressed(rl.KeyboardKey.C)do player_data.pos.y -= 2.0

	tilepos := map_worldToTile(player_data.pos)
	c := [2]u8{cast(u8)tilepos.x, cast(u8)tilepos.y}
	isInElevatorTile := c in map_data.elevatorHeights

	player_data.vel.y -= PLAYER_GRAVITY * deltatime // * (player_data.isOnGround ? 0.25 : 1.0)

	jumped := rl.IsKeyDown(PLAYER_KEY_JUMP) && player_data.isOnGround
	if jumped {
		player_data.vel = phy_applyFrictionToVelocity(player_data.vel, 19.0 - clamp((linalg.length(player_data.vel)-PLAYER_SPEED)*4.0, 0.0, 30.0))
		player_data.vel.y = PLAYER_JUMP_SPEED
		if isInElevatorTile do player_data.pos.y += 0.05 * PLAYER_SIZE.y
		//player_data.isOnGround = false
		playSoundMulti(player_data.jumpSound)
	}


	player_accelerate :: proc(dir : vec3, wishspeed : f32, accel : f32) {
		currentspeed := linalg.dot(player_data.vel, dir)
		addspeed := wishspeed - currentspeed
		if addspeed < 0.0 do return

		accelspeed := accel * wishspeed * deltatime
		if accelspeed > addspeed do accelspeed = addspeed

		player_data.vel += dir * accelspeed
	}

	player_accelerate(forw*movedir.y + right*movedir.x, PLAYER_SPEED,
		player_data.isOnGround ? PLAYER_GROUND_ACCELERATION : PLAYER_AIR_ACCELERATION)

	wishpos := player_data.pos + player_data.vel * deltatime
	
	phy_tn, phy_norm, phy_hit := phy_boxCastTilemap(player_data.pos, wishpos, PLAYER_SIZE)
	phy_vec := player_data.pos + linalg.normalize(player_data.vel)*phy_tn
	
	println("pos", player_data.pos, "vel", player_data.vel)
	//println("phy vec", phy_vec, "norm", phy_norm, "hit", phy_hit)
	
	player_data.pos = phy_vec
	if phy_hit do player_data.pos += phy_norm*PHY_BOXCAST_EPS*2.0

	prevIsOnGround := player_data.isOnGround
	player_data.isOnGround = phy_hit && phy_norm.y > PLAYER_MIN_NORMAL_Y && !jumped

	if player_data.isOnGround {
		player_data.lastValidPos = player_data.pos
		player_data.lastValidVel = player_data.vel
	}

	if !prevIsOnGround && player_data.isOnGround { // just landed
		if !rl.IsSoundPlaying(player_data.landSound) {
			playSound(player_data.landSound)
			playSoundMulti(player_data.footstepSound)
		}
	}



	if phy_hit do player_data.vel = phy_clipVelocity(player_data.vel, phy_norm, !player_data.isOnGround && phy_hit ? 1.3 : 1.02)

	player_data.vel = phy_applyFrictionToVelocity(
		player_data.vel,
		(player_data.isOnGround ? PLAYER_GROUND_FRICTION : PLAYER_AIR_FRICTION) + player_data.slowness*15.0,
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

			y := math.lerp(TILE_ELEVATOR_Y0, TILE_ELEVATOR_Y1, height) + TILE_WIDTH*TILEMAP_MID/2.0 + PLAYER_SIZE.y+0.01

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
			map_data.elevatorHeights[c] = height

			if player_data.pos.y - 0.005 < y && elevatorIsMoving {
				player_data.pos.y = y + TILE_ELEVATOR_SPEED*deltatime
				player_data.vel.y = -PLAYER_GRAVITY * deltatime
			}

			if rl.IsKeyPressed(PLAYER_KEY_JUMP) && elevatorIsMoving {
				player_data.vel.y = TILE_ELEVATOR_SPEED * 0.5
			}
		}

		if elevatorIsMoving {
			if !rl.IsSoundPlaying(map_data.elevatorSound) do playSound(map_data.elevatorSound)
		} else {
			rl.StopSound(map_data.elevatorSound)
		}
	}

	player_data.isOnGround |= elevatorIsMoving



	cam_forw := linalg.matrix_mul_vector(player_data.lookRotMat3, vec3{0, 0, 1})
	player_data.lookDir = cam_forw // TODO: update after the new rotation has been set

	// camera
	{
		if framespassed > 5 { // mouse input seems to have weird spike first frame
			player_data.lookRotEuler.y += -rl.GetMouseDelta().x * PLAYER_LOOK_SENSITIVITY
			player_data.lookRotEuler.x += rl.GetMouseDelta().y * PLAYER_LOOK_SENSITIVITY
			player_data.lookRotEuler.x = clamp(player_data.lookRotEuler.x, -math.PI*0.5*0.95, math.PI*0.5*0.95)
		}
	
		player_data.lookRotEuler.z = math.lerp(player_data.lookRotEuler.z, 0.0, clamp(deltatime * 7.5, 0.0, 1.0))
		player_data.lookRotEuler.z -= movedir.x*deltatime*0.75
		player_data.lookRotEuler.z = clamp(player_data.lookRotEuler.z, -math.PI*0.3, math.PI*0.3)

		cam_y : f32 = PLAYER_HEAD_CENTER_OFFSET
		camera.position = player_data.pos + camera.up * cam_y
		camera.target = camera.position + cam_forw
		camera.up = linalg.normalize(linalg.quaternion_mul_vector3(linalg.quaternion_angle_axis(player_data.lookRotEuler.z*1.3, cam_forw), vec3{0,1.0,0}))
	}

	if debugIsEnabled {
		size := vec3{1,1,1}
		tn, normal, hit := phy_boxCastTilemap(camera.position, camera.position + cam_forw*1000.0, size*0.5)
		hitpos := camera.position + cam_forw*tn
		rl.DrawCube(hitpos, size.x, size.y, size.z, rl.YELLOW)
		rl.DrawLine3D(hitpos, hitpos + normal*4, rl.ORANGE)
	}


	if debugIsEnabled {
		rl.DrawCubeWires(map_tileToWorld(tilepos), TILE_WIDTH, TILE_HEIGHT, TILE_WIDTH, {0,255,0,100})
	}
}



player_startMap :: proc() {
	println("player started game")
	player_data.pos = map_data.startPos
	player_data.lookRotEuler.x = 0.0
	player_data.lookRotEuler.z = 0.0
	player_data.lookRotEuler.y = math.PI*2 - (math.atan2(-map_data.startPlayerDir.x, -map_data.startPlayerDir.y) * math.sign(-map_data.startPlayerDir.x))
	player_initData()
}

player_initData :: proc() {
	player_data.rotImpulse = {}
	player_data.vel = {}
	gun_data.timer = 0
	player_data.health = PLAYER_MAX_HEALTH
	player_data.vel = {0, 0.1, 0}
	player_data.lookDir = {0,0,1}

	gun_data.ammoCounts = gun_startAmmoCounts
}

player_die :: proc() {
	println("player died")
	player_damage(1.0)
	player_startMap()
	player_initData()
	world_reset()
}

player_finishMap :: proc() {
	println("player finished game")
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
	SHOTGUN		= 0,
	MACHINEGUN	= 1,
	LASERRIFLE	= 2,
}

GUN_SHOTGUN_SPREAD		:: 0.12
GUN_SHOTGUN_DAMAGE		:: 0.1
GUN_MACHINEGUN_SPREAD		:: 0.02
GUN_MACHINEGUN_DAMAGE		:: 0.2
GUN_LASERRIFLE_DAMAGE		:: 1.0

gun_startAmmoCounts : [GUN_COUNT]i32 = {24, 86, 12}
gun_shootTimes : [GUN_COUNT]f32 = {0.5, 0.15, 1.0}

gun_data : struct {
	equipped	: gun_kind_t,
	timer		: f32,

	ammoCounts	: [GUN_COUNT]i32,

	flareModel	: rl.Model,
	gunModels	: [GUN_COUNT]rl.Model,

	shotgunSound	: rl.Sound,
	machinegunSound	: rl.Sound,
	laserrifleSound	: rl.Sound,
	headshotSound	: rl.Sound,
	emptyMagSound	: rl.Sound,
	ammoPickupSound	: rl.Sound,
}



gun_calcViewportPos :: proc() -> vec3 {
	s := math.sin(player_data.stepTimer < 0.0 ? timepassed*PLAYER_HEAD_SIN_TIME*0.5 : player_data.stepTimer*0.5) * clamp(linalg.length(player_data.vel) * 0.01, 0.1, 1.0) *
		0.04 * (player_data.isOnGround ? 1.0 : 0.05)
	kick := clamp(gun_data.timer*0.5, 0.0, 1.0)*0.8
	return vec3{-GUN_POS_X + player_data.lookRotEuler.z*0.5,-0.2 + s + kick*0.15, 0.48 - kick}
}

gun_getMuzzleOffset :: proc() -> vec3 {
	offs := vec3{}
	switch gun_data.equipped {
		case gun_kind_t.SHOTGUN:	offs = {0,0,0.6}
		case gun_kind_t.MACHINEGUN:	offs = {0,0,0.9}
		case gun_kind_t.LASERRIFLE:	offs = {0,0,0.5}
	}
	return offs
}

gun_calcMuzzlePos :: proc() -> vec3 {
	offs := gun_getMuzzleOffset()
	return camera.position + linalg.matrix_mul_vector(player_data.lookRotMat3, gun_calcViewportPos() + offs)
}

gun_drawModel :: proc(pos : vec3) {
	if gun_data.ammoCounts[cast(i32)gun_data.equipped] <= 0 do return

	gunindex := cast(i32)gun_data.equipped
	rl.DrawModel(gun_data.gunModels[gunindex], pos, GUN_SCALE, rl.WHITE)

	// flare
	FADETIME :: 0.15
	fade := (gun_data.timer - gun_shootTimes[gunindex] + FADETIME) / FADETIME
	if fade > 0.0 {
		rnd := randVec3()
		muzzleoffs := gun_getMuzzleOffset() + rnd*0.02
		rl.DrawModel(gun_data.flareModel, pos + muzzleoffs, 0.4 - fade*fade*0.2, rl.Fade(rl.WHITE, clamp(fade, 0.0, 1.0)*0.9))
	}
}

_gun_update :: proc() {
	prevgun := gun_data.equipped
	gunindex := cast(i32)gun_data.equipped

	// scrool wheel gun switching
	if rl.GetMouseWheelMove() > 0.5			do gunindex += 1
	else if rl.GetMouseWheelMove() < -0.5		do gunindex -= 1
	else if rl.IsKeyPressed(rl.KeyboardKey.ONE)	do gunindex = 0
	else if rl.IsKeyPressed(rl.KeyboardKey.TWO)	do gunindex = 1
	else if rl.IsKeyPressed(rl.KeyboardKey.THREE)	do gunindex = 2
	gunindex %%= GUN_COUNT
	gun_data.equipped = cast(gun_kind_t)gunindex
	gunindex = cast(i32)gun_data.equipped


	if gun_data.equipped != prevgun {
		gun_data.timer = -1.0
		if gun_data.ammoCounts[gunindex] <= 0 {
			playSoundMulti(gun_data.emptyMagSound)
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
					COL :: vec4{1,0.7,0.2,0.9}
					DUR :: 0.7
					cl := bullet_shootRaycast(muzzlepos, player_data.lookDir,							GUN_SHOTGUN_DAMAGE, DUR, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*right),		GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*up),			GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir - GUN_SHOTGUN_SPREAD*right),		GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir - GUN_SHOTGUN_SPREAD*up),			GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*0.7*(+up + right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*0.7*(+up - right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*0.7*(-up + right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + GUN_SHOTGUN_SPREAD*0.7*(-up - right)),	GUN_SHOTGUN_DAMAGE, RAD, COL, DUR)

					player_data.vel -= player_data.lookDir*cast(f32)(cl < PLAYER_SIZE.y*2.1 ? 55.0 : 2.0)
					player_data.rotImpulse.x -= 0.15
					playSound(gun_data.shotgunSound)

				case gun_kind_t.MACHINEGUN:
					rnd := randVec3()
					bullet_shootRaycast(muzzlepos, linalg.normalize(player_data.lookDir + rnd*GUN_MACHINEGUN_SPREAD), GUN_MACHINEGUN_DAMAGE, 1.1, {0.6,0.7,0.8, 1.0}, 0.7)
					if !player_data.isOnGround do player_data.vel -= player_data.lookDir * 6.0
					player_data.rotImpulse.x -= 0.035
					player_data.rotImpulse -= rnd * 0.01
					playSoundMulti(gun_data.machinegunSound)

				case gun_kind_t.LASERRIFLE:
					bullet_shootRaycast(muzzlepos, player_data.lookDir, GUN_LASERRIFLE_DAMAGE, 2.5, {1,0.3,0.2, 1.0}, 1.6)
					player_data.vel /= 1.5
					player_data.vel -= player_data.lookDir * 50
					player_data.rotImpulse.x -= 0.2
					player_data.rotImpulse.y += 0.04
					playSound(gun_data.laserrifleSound)

			}

			gun_data.ammoCounts[gunindex] -= 1

			switch gun_data.equipped {
				case gun_kind_t.SHOTGUN:	gun_data.timer = gun_shootTimes[gunindex]
				case gun_kind_t.MACHINEGUN:	gun_data.timer = gun_shootTimes[gunindex]
				case gun_kind_t.LASERRIFLE:	gun_data.timer = gun_shootTimes[gunindex]
			}
		} else if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			playSoundMulti(gun_data.emptyMagSound)
		}
	}
}



