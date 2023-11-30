package game

// 'Dungeon of Quake' is a simple first person shooter, heavily inspired by the Quake.

import "attrib"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

VERSION_STRING :: "0.1-alpha"

App_State :: enum {
    Loadscreen = 0,
    Main_Menu,
    Game,
}


Global_State :: struct {
    window_size:     IVec2,
    camera:          rl.Camera,
    time_passed:     f32,
    frame_index:     i64,
    exit_next_frame: bool,
    load_dir:        string,
    render_texture:  rl.RenderTexture2D,
    current_music:   ^rl.Music,
    paused:          bool,
    screen_tint:     Vec3,
    app_state:       App_State,
    settings:        Settings,
    assets:          Assets,
}

g_state: Global_State

main :: proc() {
    _app_init()
    rl.DisableCursor()

    for !rl.WindowShouldClose() && !g_state.exit_next_frame {
        //println("### frame =", frame_index, "deltatime =", deltatime)
        g_state.frame_index += 1

        // fixup
        g_state.settings.master_volume = clamp(g_state.settings.master_volume, 0.0, 1.0)
        g_state.settings.music_volume = clamp(g_state.settings.music_volume, 0.0, 1.0)
        g_state.settings.crosshair_opacity = clamp(g_state.settings.crosshair_opacity, 0.0, 1.0)
        g_state.settings.mouse_speed = clamp(g_state.settings.mouse_speed, 0.1, 5.0)
        g_state.settings.fov = clamp(g_state.settings.fov, 60.0, 160.0)
        g_state.settings.gun_fov = clamp(g_state.settings.gun_fov, 80.0, 120.0)
        g_state.settings.gun_offset_x = clamp(g_state.settings.gun_offset_x, -0.4, 0.4)
        rl.SetMasterVolume(g_state.settings.master_volume)

        g_state.camera.fovy = g_state.settings.fov

        if g_state.current_music != nil {
            rl.UpdateMusicStream(g_state.current_music^)
        }

        rl.SetTraceLogLevel(g_state.settings.debug ? .ALL : .NONE)

        if g_state.app_state != .Game {
            // Stop all sounds
            rl.StopSound(g_state.assets.elevatorSound)
            rl.StopSound(g_state.assets.player.swooshSound)
        }

        switch g_state.app_state {
        case .Loadscreen:
            menu_updateAndDrawLoadScreenUpdatePath()
        case .Main_Menu:
            menu_updateAndDrawMainMenuUpdatePath()
        case .Game:
            // main game update path
            {
                rl.UpdateCamera(&g_state.camera, .CUSTOM)

                _app_update()

                rl.BeginTextureMode(g_state.render_texture)
                bckgcol := Vec4{map_data.skyColor.r, map_data.skyColor.g, map_data.skyColor.b, 1.0}
                rl.ClearBackground(rl.ColorFromNormalized(bckgcol))

                rl.BeginMode3D(g_state.camera)
                _app_render3d()
                if !g_state.paused {
                    _gun_update()
                    _player_update()
                }
                // _enemy_updateDataAndRender()
                _bullet_updateDataAndRender()
                rl.EndMode3D()

                viewmodel_cam := g_state.camera
                viewmodel_cam.fovy = g_state.settings.gun_fov
                rl.UpdateCamera(&viewmodel_cam, .CUSTOM)
                rl.BeginMode3D(viewmodel_cam)
                gun_drawModel(gun_calcViewportPos())
                rl.EndMode3D()

                rl.EndTextureMode()

                rl.BeginDrawing()
                rl.ClearBackground(rl.PINK) // for debug
                rl.SetShaderValue(
                    postprocessShader,
                    cast(rl.ShaderLocationIndex)rl.GetShaderLocation(postprocessShader, "tintColor"),
                    &screenTint,
                    rl.ShaderUniformDataType.VEC3,
                )

                rl.BeginShaderMode(postprocessShader)
                rl.DrawTextureRec(
                    render_texture.texture,
                    rl.Rectangle {
                        0,
                        0,
                        cast(f32)render_texture.texture.width,
                        -cast(f32)render_texture.texture.height,
                    },
                    {0, 0},
                    rl.WHITE,
                )
                rl.EndShaderMode()

                if gameIsPaused {
                    menu_updateAndDrawPauseMenu()
                }

                _app_render2d()
                rl.EndDrawing()
            }
        }

        if !g_state.paused {
            g_state.time_passed += rl.GetFrameTime()
        }
    }

    rl.CloseWindow()
    rl.CloseAudioDevice()
}



//
// APP
//

_app_init :: proc() {
    {
        context.allocator = context.temp_allocator
        if path, ok := filepath.abs(os.args[0]); ok {
            g_state.load_dir = filepath.dir(filepath.clean(path))
            println("g_state.load_dir", g_state.load_dir)
        }
    }


    rl.SetWindowState({.WINDOW_RESIZABLE, .VSYNC_HINT, .FULLSCREEN_MODE})
    rl.InitWindow(800, 600, "Dungeon of Quake")
    rl.SetWindowMonitor(0)
    rl.SetWindowSize(rl.GetMonitorWidth(0), rl.GetMonitorHeight(0))
    rl.ToggleFullscreen()

    g_state.window_size = {rl.GetScreenWidth(), rl.GetScreenHeight()}

    rl.SetExitKey(.KEY_NULL)
    rl.SetTargetFPS(120)

    rl.InitAudioDevice()

    if !rl.IsAudioDeviceReady() || !rl.IsWindowReady() do time.sleep(10)

    rl.SetMasterVolume(g_state.settings.master_volume)


    g_state.render_texture = rl.LoadRenderTexture(g_state.window_size.x, g_state.window_size.y)

    assets_load_persistent()

    g_state.camera = {
        position = {0, 3, 0},
        target = {},
        up = Vec3{0.0, 1.0, 0.0},
        projection = rl.CameraProjection.PERSPECTIVE,
    }

    rand.init(&randData, cast(u64)time.now()._nsec)

    map_clearAll()
    map_data.bounds = {MAP_SIDE_TILE_COUNT, MAP_SIDE_TILE_COUNT}
    if os.is_file(asset_path("maps", "_quickload.dqm")) {
        map_loadFromFile("_quickload.dqm")
        app_setUpdatePathKind(.GAME)
    }

    player_startMap()

}

_app_update :: proc() {
    //rl.UpdateMusicStream(map_data.backgroundMusic)
    //rl.UpdateMusicStream(map_data.ambientMusic)
    //rl.SetMusicVolume(player_data.swooshMusic, clamp(linalg.length(player_data.vel * 0.05), 0.0, 1.0))

    if rl.IsKeyPressed(rl.KeyboardKey.RIGHT_ALT) {
        g_state.settings.debug = !g_state.settings.debug
    }

    if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
        g_state.paused = true
    }

    // pull elevators down
    {
        playerTilePos := map_worldToTile(player_data.pos)
        c := [2]u8{cast(u8)playerTilePos.x, cast(u8)playerTilePos.y}
        for key, val in map_data.elevatorHeights {
            if key == c do continue
            map_data.elevatorHeights[key] = clamp(val - (TILE_ELEVATOR_MOVE_FACTOR * deltatime), 0.0, 1.0)
        }
    }

    screenTint = linalg.lerp(screenTint, Vec3{1, 1, 1}, clamp(deltatime * 3.0, 0.0, 1.0))
}

_app_render2d :: proc() {
    menu_drawPlayerUI()
    menu_drawDebugUI()
}

_app_render3d :: proc() {
    when false {
        if settings.debugIsEnabled {
            LEN :: 100
            WID :: 1
            rl.DrawCube(Vec3{LEN, 0, 0}, LEN, WID, WID, rl.RED)
            rl.DrawCube(Vec3{0, LEN, 0}, WID, LEN, WID, rl.GREEN)
            rl.DrawCube(Vec3{0, 0, LEN}, WID, WID, LEN, rl.BLUE)
            rl.DrawCube(Vec3{0, 0, 0}, WID, WID, WID, rl.RAYWHITE)
        }
    }

    //rl.DrawPlane(Vec3{0.0, 0.0, 0.0}, Vec2{32.0, 32.0}, rl.LIGHTGRAY) // Draw ground

    rl.SetShaderValue(
        g_state.assets.tileShader,
        g_state.assets.tileShaderCamPosUniformIndex,
        &camera.position,
        rl.ShaderUniformDataType.VEC3,
    )
    fogColor := Vec4{map_data.skyColor.r, map_data.skyColor.g, map_data.skyColor.b, map_data.fogStrength}

    rl.SetShaderValue(
        g_state.assets.defaultShader,
        cast(rl.ShaderLocationIndex)rl.GetShaderLocation(g_state.assets.defaultShader, "camPos"),
        &camera.position,
        rl.ShaderUniformDataType.VEC3,
    )
    rl.SetShaderValue(
        g_state.assets.defaultShader,
        cast(rl.ShaderLocationIndex)rl.GetShaderLocation(g_state.assets.defaultShader, "fogColor"),
        &fogColor,
        rl.ShaderUniformDataType.VEC4,
    )

    rl.SetShaderValue(
        g_state.assets.tileShader,
        cast(rl.ShaderLocationIndex)rl.GetShaderLocation(g_state.assets.tileShader, "fogColor"),
        &fogColor,
        rl.ShaderUniformDataType.VEC4,
    )

    rl.SetShaderValue(
        g_state.assets.portalShader,
        cast(rl.ShaderLocationIndex)rl.GetShaderLocation(g_state.assets.portalShader, "g_state.time_passed"),
        &g_state.time_passed,
        rl.ShaderUniformDataType.FLOAT,
    )

    rl.SetShaderValue(
        g_state.assets.cloudShader,
        cast(rl.ShaderLocationIndex)rl.GetShaderLocation(g_state.assets.cloudShader, "g_state.time_passed"),
        &g_state.time_passed,
        rl.ShaderUniformDataType.FLOAT,
    )
    rl.SetShaderValue(
        g_state.assets.cloudShader,
        cast(rl.ShaderLocationIndex)rl.GetShaderLocation(g_state.assets.cloudShader, "camPos"),
        &camera.position,
        rl.ShaderUniformDataType.VEC3,
    )


    map_drawTilemap()
}



app_setUpdatePathKind :: proc(kind: app_updatePathKind_t) {
    app_updatePathKind = kind
    menu_resetState()
    gameIsPaused = false
}



world_reset :: proc() {
    player_initData()
    player_startMap()

    for i: i32 = 0; i < enemy_data.gruntCount; i += 1 {
        enemy_data.grunts[i].pos = enemy_data.grunts[i].spawnPos
        enemy_data.grunts[i].health = ENEMY_GRUNT_HEALTH
        enemy_data.grunts[i].attackTimer = ENEMY_GRUNT_ATTACK_TIME
        enemy_data.grunts[i].vel = {}
        enemy_data.grunts[i].target = {}
        enemy_data.grunts[i].isMoving = false
    }

    for i: i32 = 0; i < enemy_data.knightCount; i += 1 {
        enemy_data.knights[i].pos = enemy_data.knights[i].spawnPos
        enemy_data.knights[i].health = ENEMY_KNIGHT_HEALTH
        enemy_data.knights[i].attackTimer = ENEMY_KNIGHT_ATTACK_TIME
        enemy_data.knights[i].vel = {}
        enemy_data.knights[i].target = {}
        enemy_data.knights[i].isMoving = false
    }

    map_data.gunPickupCount = map_data.gunPickupSpawnCount
    map_data.healthPickupCount = map_data.healthPickupSpawnCount
}



//
// BULLETS
//

BULLET_LINEAR_EFFECT_MAX_COUNT :: 64
BULLET_LINEAR_EFFECT_MESH_QUALITY :: 5 // equal to cylinder slices

BULLET_REMOVE_THRESHOLD :: 0.04

bullet_ammoInfo_t :: struct {
    damage:    f32,
    knockback: f32,
}

bullet_data: struct {
    bulletLinesCount: i32,
    bulletLines:      [BULLET_LINEAR_EFFECT_MAX_COUNT]struct {
        start:      Vec3,
        timeToLive: f32,
        end:        Vec3,
        radius:     f32,
        color:      Vec4,
        duration:   f32,
    },
}

// @param timeToLive: in seconds
bullet_createBulletLine :: proc(start: Vec3, end: Vec3, rad: f32, col: Vec4, duration: f32) {
    if duration <= BULLET_REMOVE_THRESHOLD do return
    index := bullet_data.bulletLinesCount
    if index + 1 >= BULLET_LINEAR_EFFECT_MAX_COUNT do return
    bullet_data.bulletLinesCount += 1
    bullet_data.bulletLines[index] = {}
    bullet_data.bulletLines[index].start = start
    bullet_data.bulletLines[index].timeToLive = duration
    bullet_data.bulletLines[index].end = end
    bullet_data.bulletLines[index].radius = rad
    bullet_data.bulletLines[index].color = col
    bullet_data.bulletLines[index].duration = duration
}

// @returns: tn, hitenemy
bullet_shootRaycast :: proc(
    start: Vec3,
    dir: Vec3,
    damage: f32,
    rad: f32,
    col: Vec4,
    effectDuration: f32,
) -> (
    tn: f32,
    enemykind: Enemy_Kind,
    enemyindex: i32,
) {
    hit: bool
    tn, hit, enemykind, enemyindex = phy_boxcastWorld(start, start + dir * 1e6, {0, 0, 0}) //Vec3{rad,rad,rad})
    hitpos := start + dir * tn
    hitenemy := enemykind != Enemy_Kind.NONE
    bullet_createBulletLine(
        start + dir * rad * 2.0,
        hitpos,
        hitenemy ? rad : rad * 0.65,
        hitenemy ? col : col * Vec4{0.5, 0.5, 0.5, 1.0},
        hitenemy ? effectDuration : effectDuration * 0.7,
    )
    if hit {
        switch enemykind {
        case Enemy_Kind.NONE:
        case Enemy_Kind.GRUNT:
            headshot :=
                hitpos.y >
                enemy_data.grunts[enemyindex].pos.y + ENEMY_GRUNT_SIZE.y * ENEMY_HEADSHOT_HALF_OFFSET
            enemy_data.grunts[enemyindex].health -= headshot ? damage * 2 : damage
            if headshot do playSound(g_state.assets.gun.headshotSound)
            playSound(g_state.assets.enemy.gruntHitSound)
            if enemy_data.grunts[enemyindex].health <= 0.0 do playSoundMulti(g_state.assets.enemy.gruntDeathSound)
            enemy_data.grunts[enemyindex].vel += dir * 10.0 * damage
        case Enemy_Kind.KNIGHT:
            headshot :=
                hitpos.y >
                enemy_data.knights[enemyindex].pos.y + ENEMY_KNIGHT_SIZE.y * ENEMY_HEADSHOT_HALF_OFFSET
            enemy_data.knights[enemyindex].health -= headshot ? damage * 2 : damage
            if headshot do playSound(g_state.assets.gun.headshotSound)
            playSound(g_state.assets.enemy.knightHitSound)
            if enemy_data.knights[enemyindex].health <= 0.0 do playSoundMulti(g_state.assets.enemy.knightDeathSound)
            enemy_data.knights[enemyindex].vel += dir * 10.0 * damage
        }
    }

    return tn, enemykind, enemyindex
}

bullet_shootProjectile :: proc(start: Vec3, dir: Vec3, damage: f32, rad: f32, col: Vec4) {
    // TODO
}

_bullet_updateDataAndRender :: proc() {
    assert(bullet_data.bulletLinesCount >= 0)
    assert(bullet_data.bulletLinesCount < BULLET_LINEAR_EFFECT_MAX_COUNT)

    if !gameIsPaused {
        // remove old
        loopremove: for i: i32 = 0; i < bullet_data.bulletLinesCount; i += 1 {
            bullet_data.bulletLines[i].timeToLive -= deltatime
            if bullet_data.bulletLines[i].timeToLive <= BULLET_REMOVE_THRESHOLD {     // needs to be removed
                if i + 1 >= bullet_data.bulletLinesCount {     // we're on the last one
                    bullet_data.bulletLinesCount -= 1
                    break loopremove
                }
                bullet_data.bulletLinesCount -= 1
                lastindex := bullet_data.bulletLinesCount
                bullet_data.bulletLines[i] = bullet_data.bulletLines[lastindex]
            }
        }
    }

    // draw
    rl.BeginShaderMode(g_state.assets.bulletLineShader)
    for i: i32 = 0; i < bullet_data.bulletLinesCount; i += 1 {
        fade := (bullet_data.bulletLines[i].timeToLive / bullet_data.bulletLines[i].duration)
        col := bullet_data.bulletLines[i].color
        sphfade := fade * fade

        // thin white
        rl.DrawSphere(
            bullet_data.bulletLines[i].end,
            sphfade * bullet_data.bulletLines[i].radius * 2.0,
            rl.ColorFromNormalized(Vec4{1, 1, 1, 0.5 + sphfade * 0.5}),
        )

        rl.DrawSphere(
            bullet_data.bulletLines[i].end,
            (sphfade + 2.0) / 3.0 * bullet_data.bulletLines[i].radius * 4.0,
            rl.ColorFromNormalized(Vec4{col.r, col.g, col.b, col.a * sphfade}),
        )

        // thin white
        rl.DrawCylinderEx(
            bullet_data.bulletLines[i].start,
            bullet_data.bulletLines[i].end,
            fade * bullet_data.bulletLines[i].radius * 0.05,
            fade * bullet_data.bulletLines[i].radius * 0.4,
            3,
            rl.ColorFromNormalized(Vec4{1, 1, 1, 0.5 + fade * 0.5}),
        )

        rl.DrawCylinderEx(
            bullet_data.bulletLines[i].start,
            bullet_data.bulletLines[i].end,
            fade * bullet_data.bulletLines[i].radius * 0.1,
            fade * bullet_data.bulletLines[i].radius,
            BULLET_LINEAR_EFFECT_MESH_QUALITY,
            rl.ColorFromNormalized(Vec4{col.r, col.g, col.b, col.a * fade}),
        )

        //rl.DrawSphere(
        //	bullet_data.bulletLines[i].start,
        //	fade * bullet_data.bulletLines[i].radius,
        //	rl.ColorFromNormalized(Vec4{col.r, col.g, col.b, col.a * fade}),
        //)
    }
    rl.EndShaderMode()
}
