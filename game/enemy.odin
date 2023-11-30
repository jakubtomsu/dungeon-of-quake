package game


ENEMY_GRUNT_MAX_COUNT :: 64
ENEMY_KNIGHT_MAX_COUNT :: 64

ENEMY_HEALTH_MULTIPLIER :: 1.5
ENEMY_HEADSHOT_HALF_OFFSET :: 0.2
ENEMY_GRAVITY :: 40

ENEMY_GRUNT_SIZE :: Vec3{2.5, 3.7, 2.5}
ENEMY_GRUNT_ACCELERATION :: 10
ENEMY_GRUNT_MAX_SPEED :: 20
ENEMY_GRUNT_FRICTION :: 5
ENEMY_GRUNT_MIN_GOOD_DIST :: 30
ENEMY_GRUNT_MAX_GOOD_DIST :: 60
ENEMY_GRUNT_ATTACK_TIME :: 1.7
ENEMY_GRUNT_DAMAGE :: 1.0
ENEMY_GRUNT_HEALTH :: 1.0
ENEMY_GRUNT_SPEED_RAND :: 0.012 // NOTE: multiplier for length(player velocity) ^ 2
ENEMY_GRUNT_DIST_RAND :: 1.1
ENEMY_GRUNT_MAX_DIST :: 250.0

ENEMY_KNIGHT_SIZE :: Vec3{1.5, 3.0, 1.5}
ENEMY_KNIGHT_ACCELERATION :: 7
ENEMY_KNIGHT_MAX_SPEED :: 38
ENEMY_KNIGHT_FRICTION :: 2
ENEMY_KNIGHT_DAMAGE :: 1.0
ENEMY_KNIGHT_ATTACK_TIME :: 1.0
ENEMY_KNIGHT_HEALTH :: 1.0
ENEMY_KNIGHT_RANGE :: 5.0

ENEMY_GRUNT_ANIM_FRAMETIME :: 1.0 / 15.0
ENEMY_KNIGHT_ANIM_FRAMETIME :: 1.0 / 15.0

Enemy_Kind :: enum u8 {
    NONE = 0,
    GRUNT,
    KNIGHT,
}

enemy_data: struct {
    deadCount:   i32,
    gruntCount:  i32,
    grunts:      [ENEMY_GRUNT_MAX_COUNT]struct {
        spawnPos:       Vec3,
        attackTimer:    f32,
        pos:            Vec3,
        health:         f32,
        target:         Vec3,
        isMoving:       bool,
        vel:            Vec3,
        rot:            f32, // angle in radians around Y axis
        animFrame:      i32,
        animFrameTimer: f32,
        animState:      enum u8 {
            // also index to animation
            RUN    = 0,
            ATTACK = 1,
            IDLE   = 2,
        },
    },
    knightCount: i32,
    knights:     [ENEMY_KNIGHT_MAX_COUNT]struct {
        spawnPos:       Vec3,
        health:         f32,
        pos:            Vec3,
        attackTimer:    f32,
        vel:            Vec3,
        rot:            f32, // angle in radians around Y axis
        target:         Vec3,
        isMoving:       bool,
        animFrame:      i32,
        animFrameTimer: f32,
        animState:      enum u8 {
            // also index to animation
            RUN    = 0,
            ATTACK = 1,
            IDLE   = 2,
        },
    },
}



// guy with a gun
enemy_spawnGrunt :: proc(pos: Vec3) {
    index := enemy_data.gruntCount
    if index + 1 >= ENEMY_GRUNT_MAX_COUNT do return
    enemy_data.gruntCount += 1
    enemy_data.grunts[index] = {}
    enemy_data.grunts[index].spawnPos = pos
    enemy_data.grunts[index].pos = pos
    enemy_data.grunts[index].target = {}
    enemy_data.grunts[index].health = ENEMY_GRUNT_HEALTH * ENEMY_HEALTH_MULTIPLIER
}

// guy with a sword
enemy_spawnKnight :: proc(pos: Vec3) {
    index := enemy_data.knightCount
    if index + 1 >= ENEMY_KNIGHT_MAX_COUNT do return
    enemy_data.knightCount += 1
    enemy_data.knights[index] = {}
    enemy_data.knights[index].spawnPos = pos
    enemy_data.knights[index].pos = pos
    enemy_data.knights[index].target = {}
    enemy_data.knights[index].health = ENEMY_KNIGHT_HEALTH * ENEMY_HEALTH_MULTIPLIER
}



_enemy_updateDataAndRender :: proc() {
    assert(enemy_data.gruntCount >= 0)
    assert(enemy_data.knightCount >= 0)
    assert(enemy_data.gruntCount < ENEMY_GRUNT_MAX_COUNT)
    assert(enemy_data.knightCount < ENEMY_KNIGHT_MAX_COUNT)

    if !gameIsPaused {
        //enemy_data.knightAnimFrame += 1
        //animindex := 1
        //rl.UpdateModelAnimation(asset_data.enemy.knightModel, asset_data.enemy.knightAnim[animindex], enemy_data.knightAnimFrame)
        //if enemy_data.knightAnimFrame >= asset_data.enemy.knightAnim[animindex].frameCount do enemy_data.knightAnimFrame = 0

        //if !rl.IsModelAnimationValid(asset_data.enemy.knightModel, asset_data.enemy.knightAnim[animindex]) do println("! error: KNIGHT ANIM INVALID")

        enemy_data.deadCount = 0

        // update grunts
        for i: i32 = 0; i < enemy_data.gruntCount; i += 1 {
            if enemy_data.grunts[i].health <= 0.0 {
                enemy_data.deadCount += 1
                continue
            }

            pos := enemy_data.grunts[i].pos + Vec3{0, ENEMY_GRUNT_SIZE.y * 0.5, 0}
            dir := linalg.normalize(player_data.pos - pos)
            // cast player
            p_tn, p_hit := phy_boxcastPlayer(pos, dir, {0, 0, 0})
            EPS :: 0.0
            t_tn, t_norm, t_hit := phy_boxcastTilemap(pos, pos + dir * 1e6, {EPS, EPS, EPS})
            seeplayer := p_tn < t_tn && p_hit

            if pos.y < -TILE_HEIGHT do enemy_data.knights[i].health = -1.0

            // println("p_tn", p_tn, "p_hit", p_hit, "t_tn", t_tn, "t_hit", t_hit)

            enemy_data.grunts[i].attackTimer -= deltatime


            if seeplayer {
                enemy_data.grunts[i].target = player_data.pos
                enemy_data.grunts[i].isMoving = true
            }


            flatdir := linalg.normalize((enemy_data.grunts[i].target - pos) * Vec3{1, 0, 1})

            toTargetRot: f32 = math.atan2(-flatdir.z, flatdir.x) // * math.sign(flatdir.x)
            enemy_data.grunts[i].rot = math.angle_lerp(
                enemy_data.grunts[i].rot,
                roundstep(toTargetRot, 4.0 / math.PI),
                clamp(deltatime * 1.0, 0.0, 1.0),
            )

            if p_tn < ENEMY_GRUNT_SIZE.y {
                player_data.vel = flatdir * 50.0
                player_data.slowness = 0.1
            }

            if seeplayer && p_tn < ENEMY_GRUNT_MAX_DIST {
                if enemy_data.grunts[i].attackTimer < 0.0 {     // attack
                    enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME
                    rndstrength := clamp(
                        (linalg.length2(player_data.vel) * ENEMY_GRUNT_SPEED_RAND +
                            p_tn * ENEMY_GRUNT_DIST_RAND) *
                        1e-3 *
                        0.5,
                        0.0005,
                        0.04,
                    )
                    // cast bullet
                    bulletdir := linalg.normalize(
                        dir + randVec3() * rndstrength + player_data.vel * deltatime / PLAYER_SPEED,
                    )
                    bullet_tn, bullet_norm, bullet_hit := phy_boxcastTilemap(
                        pos,
                        pos + bulletdir * 1e6,
                        {EPS, EPS, EPS},
                    )
                    bullet_createBulletLine(
                        pos,
                        pos + bulletdir * bullet_tn,
                        2.0,
                        Vec4{1.0, 0.0, 0.0, 1.0},
                        1.0,
                    )
                    bulletplayer_tn, bulletplayer_hit := phy_boxcastPlayer(pos, bulletdir, {0, 0, 0})
                    if bulletplayer_hit && bulletplayer_tn < bullet_tn {     // if the ray actually hit player first
                        player_damage(ENEMY_GRUNT_DAMAGE)
                        player_data.vel += bulletdir * 40.0
                        player_data.rotImpulse += {0.1, 0.0, 0.0}
                    }

                    enemy_data.grunts[i].animState = .ATTACK
                    enemy_data.grunts[i].animFrame = 0
                }
            } else {
                enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME * 0.5
            }



            speed := linalg.length(enemy_data.grunts[i].vel)
            enemy_data.grunts[i].vel.y -= ENEMY_GRAVITY * deltatime

            phy_pos, phy_vel, phy_hit, phy_norm := phy_simulateMovingBox(
                enemy_data.grunts[i].pos,
                enemy_data.grunts[i].vel,
                0.0,
                ENEMY_GRUNT_SIZE,
                0.1,
            )
            enemy_data.grunts[i].pos = phy_pos
            enemy_data.grunts[i].vel = phy_vel
            isOnGround := phy_hit && phy_norm.y > 0.3

            if speed > 0.1 && enemy_data.grunts[i].isMoving && isOnGround {
                forwdepth := phy_raycastDepth(pos + flatdir * ENEMY_GRUNT_SIZE.x * 1.7)
                if forwdepth > ENEMY_GRUNT_SIZE.y * 4 {
                    enemy_data.grunts[i].vel = -flatdir * ENEMY_GRUNT_MAX_SPEED * 0.5
                    enemy_data.grunts[i].animState = .IDLE
                    enemy_data.grunts[i].isMoving = false
                }
            }

            if enemy_data.grunts[i].isMoving && speed < ENEMY_GRUNT_MAX_SPEED && isOnGround {
                if !seeplayer {
                    enemy_data.grunts[i].vel += flatdir * ENEMY_GRUNT_ACCELERATION
                    enemy_data.grunts[i].animState = .RUN
                } else if p_tn < ENEMY_GRUNT_MIN_GOOD_DIST {
                    enemy_data.grunts[i].vel -= flatdir * ENEMY_GRUNT_ACCELERATION
                    enemy_data.grunts[i].animState = .RUN
                }
            }
        }



        // update knights
        for i: i32 = 0; i < enemy_data.knightCount; i += 1 {
            if enemy_data.knights[i].health <= 0.0 {
                enemy_data.deadCount += 1
                continue
            }

            pos := enemy_data.knights[i].pos + Vec3{0, ENEMY_KNIGHT_SIZE.y * 0.5, 0}
            dir := linalg.normalize(player_data.pos - pos)
            p_tn, p_hit := phy_boxcastPlayer(pos, dir, {0, 0, 0})
            t_tn, t_norm, t_hit := phy_boxcastTilemap(pos, pos + dir * 1e6, {1, 1, 1})
            seeplayer := p_tn < t_tn && p_hit

            if pos.y < -TILE_HEIGHT do enemy_data.knights[i].health = -1.0

            // println("p_tn", p_tn, "p_hit", p_hit, "t_tn", t_tn, "t_hit", t_hit)

            enemy_data.knights[i].attackTimer -= deltatime


            if seeplayer {
                enemy_data.knights[i].target = player_data.pos
                enemy_data.knights[i].isMoving = true
            }


            flatdir := linalg.normalize((enemy_data.knights[i].target - pos) * Vec3{1, 0, 1})

            toTargetRot: f32 = math.atan2(-flatdir.z, flatdir.x)
            enemy_data.knights[i].rot = math.angle_lerp(
                enemy_data.knights[i].rot,
                roundstep(toTargetRot, 4.0 / math.PI),
                clamp(deltatime * 3, 0.0, 1.0),
            )

            if seeplayer {
                if p_tn < ENEMY_KNIGHT_RANGE {
                    enemy_data.knights[i].vel = -flatdir * ENEMY_KNIGHT_MAX_SPEED * 2.0
                    player_data.vel = flatdir * 100.0
                    player_data.vel.y = 10.0
                    if enemy_data.knights[i].attackTimer < 0.0 {     // attack
                        enemy_data.knights[i].attackTimer = ENEMY_KNIGHT_ATTACK_TIME
                        player_damage(ENEMY_KNIGHT_DAMAGE)
                        player_data.vel = flatdir * 100.0
                        player_data.vel.y = 20.0
                        enemy_data.knights[i].vel = -flatdir * ENEMY_KNIGHT_MAX_SPEED * 2.0
                        enemy_data.knights[i].animState = .ATTACK
                        enemy_data.knights[i].animFrame = 0
                    }
                }
            } else {
                enemy_data.knights[i].attackTimer = ENEMY_KNIGHT_ATTACK_TIME * 0.5
            }



            speed := linalg.length(enemy_data.knights[i].vel)
            enemy_data.knights[i].vel.y -= ENEMY_GRAVITY * deltatime

            phy_pos, phy_vel, phy_hit, phy_norm := phy_simulateMovingBox(
                enemy_data.knights[i].pos,
                enemy_data.knights[i].vel,
                0.0,
                ENEMY_KNIGHT_SIZE,
                0.1,
            )
            enemy_data.knights[i].pos = phy_pos
            enemy_data.knights[i].vel = phy_vel
            isOnGround := phy_hit && phy_norm.y > 0.3

            if speed > 0.1 && enemy_data.knights[i].isMoving && isOnGround {
                forwdepth := phy_raycastDepth(pos + flatdir * ENEMY_KNIGHT_SIZE.x * 1.7)
                if forwdepth > ENEMY_KNIGHT_SIZE.y * 4 {
                    enemy_data.knights[i].vel = -enemy_data.knights[i].vel * 0.5
                    enemy_data.knights[i].animState = .IDLE
                    enemy_data.knights[i].isMoving = false
                }
            }

            if enemy_data.knights[i].isMoving &&
               speed < ENEMY_KNIGHT_MAX_SPEED &&
               isOnGround &&
               enemy_data.grunts[i].animState != .ATTACK {
                enemy_data.knights[i].vel += flatdir * ENEMY_KNIGHT_ACCELERATION
            }
        }
    } // if !gameIsPaused

    // render grunts
    for i: i32 = 0; i < enemy_data.gruntCount; i += 1 {
        if enemy_data.grunts[i].health <= 0.0 do continue

        // anim
        {
            // update state
            if !gameIsPaused {
                prevanim := enemy_data.grunts[i].animState
                if !enemy_data.grunts[i].isMoving do enemy_data.grunts[i].animState = .IDLE
                else {
                    if enemy_data.grunts[i].attackTimer < 0.0 do enemy_data.grunts[i].animState = .RUN
                }
                if enemy_data.grunts[i].animState != prevanim do enemy_data.grunts[i].animFrame = 0
            }

            animindex := i32(enemy_data.grunts[i].animState)

            if !gameIsPaused {
                enemy_data.grunts[i].animFrameTimer += deltatime
                if enemy_data.grunts[i].animFrameTimer > ENEMY_GRUNT_ANIM_FRAMETIME {
                    enemy_data.grunts[i].animFrameTimer -= ENEMY_GRUNT_ANIM_FRAMETIME
                    enemy_data.grunts[i].animFrame += 1

                    if enemy_data.grunts[i].animFrame >= asset_data.enemy.gruntAnim[animindex].frameCount {
                        enemy_data.grunts[i].animFrame = 0
                        enemy_data.grunts[i].animFrameTimer = 0
                        if enemy_data.grunts[i].animState == .ATTACK do enemy_data.grunts[i].animState = .IDLE
                    }
                }
            }

            // rl.UpdateModelAnimation(
            //     asset_data.enemy.gruntModel,
            //     asset_data.enemy.gruntAnim[animindex],
            //     enemy_data.grunts[i].animFrame,
            // )
        }

        rl.DrawModelEx(
            asset_data.enemy.gruntModel,
            enemy_data.grunts[i].pos,
            {0, 1, 0},
            enemy_data.grunts[i].rot * 180.0 / math.PI,
            1.4,
            rl.WHITE,
        )
    }

    // render knights
    for i: i32 = 0; i < enemy_data.knightCount; i += 1 {
        if enemy_data.knights[i].health <= 0.0 do continue

        // anim
        {
            // update state
            if !gameIsPaused {
                prevanim := enemy_data.knights[i].animState
                if !enemy_data.knights[i].isMoving do enemy_data.knights[i].animState = .IDLE
                else {
                    if enemy_data.knights[i].attackTimer < 0.0 do enemy_data.knights[i].animState = .RUN
                }
                if enemy_data.knights[i].animState != prevanim do enemy_data.knights[i].animFrame = 0
            }

            animindex := i32(enemy_data.knights[i].animState)

            if !gameIsPaused {
                enemy_data.knights[i].animFrameTimer += deltatime
                if enemy_data.knights[i].animFrameTimer > ENEMY_KNIGHT_ANIM_FRAMETIME {
                    enemy_data.knights[i].animFrameTimer -= ENEMY_KNIGHT_ANIM_FRAMETIME
                    enemy_data.knights[i].animFrame += 1

                    if enemy_data.knights[i].animFrame >= asset_data.enemy.knightAnim[animindex].frameCount {
                        enemy_data.knights[i].animFrame = 0
                        enemy_data.knights[i].animFrameTimer = 0
                        if enemy_data.knights[i].animState == .ATTACK do enemy_data.knights[i].animState = .RUN
                    }
                }
            }

            // rl.UpdateModelAnimation(
            //     asset_data.enemy.knightModel,
            //     asset_data.enemy.knightAnim[animindex],
            //     enemy_data.knights[i].animFrame,
            // )
        }

        rl.DrawModelEx(
            asset_data.enemy.knightModel,
            enemy_data.knights[i].pos,
            {0, 1, 0},
            enemy_data.knights[i].rot * 180.0 / math.PI, // rot
            1.0,
            rl.WHITE,
        )
    }

    if settings.debugIsEnabled {
        // render grunt physics AABBS
        for i: i32 = 0; i < enemy_data.gruntCount; i += 1 {
            if enemy_data.grunts[i].health <= 0.0 do continue
            rl.DrawCubeWires(
                enemy_data.grunts[i].pos,
                ENEMY_GRUNT_SIZE.x * 2,
                ENEMY_GRUNT_SIZE.y * 2,
                ENEMY_GRUNT_SIZE.z * 2,
                rl.GREEN,
            )
        }

        // render knight physics AABBS
        for i: i32 = 0; i < enemy_data.knightCount; i += 1 {
            if enemy_data.knights[i].health <= 0.0 do continue
            rl.DrawCubeWires(
                enemy_data.knights[i].pos,
                ENEMY_KNIGHT_SIZE.x * 2,
                ENEMY_KNIGHT_SIZE.y * 2,
                ENEMY_KNIGHT_SIZE.z * 2,
                rl.GREEN,
            )
        }
    }
}
