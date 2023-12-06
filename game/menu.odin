package game



import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

MENU_MAX_MAP_SELECT_FILES :: 256

Menu_Data :: struct {
    loadScreenTimer:         f32,
    pauseMenuIsOpen:         bool,
    mapSelectFileElemsCount: i32,
    mapSelectFileElems:      [MENU_MAX_MAP_SELECT_FILES]Ui_Elem,
    mapSelectButtonBool:     bool, // shared
    mapSelectIsOpen:         bool,
    selected:                i32, // this can be shared, since we always have only one menu on screen
    startOffs:               f32,
    normalFont:              rl.Font,
    selectSound:             rl.Sound,
    setValSound:             rl.Sound,
}


menu_resetState :: proc() {
    g_state.menu.selected = 0
    g_state.menu.mapSelectIsOpen = false
    g_state.menu.mapSelectButtonBool = false
    g_state.menu.pauseMenuIsOpen = false
    g_state.menu.loadScreenTimer = 0.0
}


menu_drawPlayerUI :: proc() {
    using g_state

    // crosshair
    {
        W :: 8
        H :: 4

        // horizontal
        rl.DrawRectangle(
            window_size.x / 2 - 10 - W / 2,
            window_size.y / 2 - 1,
            W,
            2,
            rl.Fade(rl.WHITE, settings.crosshair_opacity),
        )
        rl.DrawRectangle(
            window_size.x / 2 + 10 - W / 2,
            window_size.y / 2 - 1,
            W,
            2,
            rl.Fade(rl.WHITE, settings.crosshair_opacity),
        )

        // vertical
        rl.DrawRectangle(
            window_size.x / 2 - 1,
            window_size.y / 2 - 7 - H / 2,
            2,
            H,
            rl.Fade(rl.WHITE, settings.crosshair_opacity),
        )
        rl.DrawRectangle(
            window_size.x / 2 - 1,
            window_size.y / 2 + 7 - H / 2,
            2,
            H,
            rl.Fade(rl.WHITE, settings.crosshair_opacity),
        )

        // center dot
        //rl.DrawRectangle(window_size.x/2-1, window_size.y/2-1, 2, 2, rl.WHITE)
    }

    gun := gun_data.equipped

    // draw ammo
    ui_draw_text(
        {f32(window_size.x) - 150, f32(window_size.y) - 50},
        30,
        rl.Color{255, 200, 50, 220},
        fmt.tprint("AMMO: ", gun_data.ammoCounts[gun]),
    )
    // health
    ui_draw_text(
        {30, f32(window_size.y) - 50},
        30,
        rl.Color{255, 80, 80, 220},
        fmt.tprint("HEALTH: ", player_data.health),
    )
    ui_draw_text({30, 30}, 30, rl.Color{220, 180, 50, 150}, fmt.tprint("KILL COUNT: ", enemy_data.deadCount))

    // draw gun ui
    for kind, i in Gun_Kind {
        LINE :: 40
        TEXTHEIGHT :: LINE * 0.5
        pos := Vec2 {
            f32(window_size.x) - 120,
            f32(window_size.y) * 0.5 + len(Gun_Kind) * LINE * 0.5 - cast(f32)i * LINE,
        }

        col := gun_data.ammoCounts[kind] == 0 ? UI_INACTIVE_COLOR : UI_ACTIVE_COLOR
        if gun_data.equipped == kind do col = UI_ACTIVE_VAL_COLOR
        ui_draw_text(pos, TEXTHEIGHT, col, fmt.tprint(cast(Gun_Kind)i))
        ui_draw_text(
            pos - Vec2{30, 0},
            TEXTHEIGHT,
            UI_TITLE_COLOR,
            fmt.tprint(args = {i + 1, "."}, sep = ""),
        )
    }

}

_debugtext_y: i32 = 2
menu_drawDebugUI :: proc() {
    using g_state

    if g_state.settings.draw_fps || g_state.settings.debug {
        rl.DrawFPS(1, 1)
    }

    _debugtext_y = 2

    if settings.debug {
        debugtext :: proc(args: ..any) {
            SIZE :: 10
            tstr := fmt.tprint(args = args)
            cstr := strings.clone_to_cstring(tstr, context.temp_allocator)
            col := tstr[0] == ' ' ? rl.WHITE : rl.YELLOW
            rl.DrawText(cstr, tstr[0] == ' ' ? 16 : 4, _debugtext_y * (SIZE + 2), SIZE, col)
            _debugtext_y += 1
        }

        debugtext("player")
        debugtext(" mouse", rl.GetMouseDelta())
        debugtext(" pos", player_data.pos)
        debugtext(" vel", player_data.vel)
        debugtext(" speed", i32(linalg.length(player_data.vel)))
        debugtext(" onground", player_data.isOnGround)
        debugtext(" onground timer", player_data.onGroundTimer)
        debugtext("system")
        debugtext(" windowSize", []i32{window_size.x, window_size.y})
        debugtext(" app_updatePathKind", app_state)
        debugtext(" IsAudioDeviceReady", rl.IsAudioDeviceReady())
        debugtext(" g_state.load_dir", g_state.load_dir)
        debugtext(" g_state.paused", g_state.paused)
        debugtext("map")
        debugtext(" bounds", level.bounds)
        debugtext(" nextMapName", level.nextMapName)
        debugtext(" startPlayerDir", level.startPlayerDir)
        debugtext(" gunPickupCount", level.gunPickupCount, "gunPickupSpawnCount", level.gunPickupCount)
        debugtext(
            " healthPickupCount",
            level.healthPickupCount,
            "healthPickupSpawnCount",
            level.healthPickupSpawnCount,
        )
        debugtext(" skyColor", level.skyColor)
        debugtext(" fogStrengh", level.fogStrength)
        debugtext("gun")
        debugtext(" equipped", gun_data.equipped)
        debugtext(" last equipped", gun_data.lastEquipped)
        debugtext(" timer", gun_data.timer)
        debugtext(" ammo counts", gun_data.ammoCounts)
        debugtext("bullets")
        debugtext(" bulletline count", bullet_data.bulletLinesCount)
        debugtext("enemies")
        debugtext(" grunt count", enemy_data.gruntCount)
        debugtext(" grunt count", enemy_data.knightCount)
        // debugtext(" grunt anim count", g_state.assets.enemy.gruntAnimCount)
        // debugtext(" grunt anim[0] bone count", g_state.assets.enemy.gruntAnim[0].boneCount)
        // debugtext(" grunt anim[0] frame count", g_state.assets.enemy.gruntAnim[0].frameCount)
        // debugtext(" grunt model bone count", g_state.assets.enemy.gruntModel.boneCount)
        // debugtext(" knight anim count", g_state.assets.enemy.knightAnimCount)
        // debugtext(" knight anim[0] bone count", g_state.assets.enemy.knightAnim[0].boneCount)
        // debugtext(" knight anim[0] frame count", g_state.assets.enemy.knightAnim[0].frameCount)
        // debugtext(" knight model bone count", g_state.assets.enemy.knightModel.boneCount)
        debugtext("menus")
        debugtext(" pauseMenuIsOpen", g_state.menu.pauseMenuIsOpen)
        debugtext(" mapSelectFileElemsCount", g_state.menu.mapSelectFileElemsCount)
        debugtext("gui")
        debugtext(" selected", g_state.menu.selected)
        debugtext(" startOffset", g_state.menu.startOffs)
    }
}



menu_updateAndDrawPauseMenu :: proc(delta: f32) {
    using g_state

    if level.isMapFinished {
        screen_tint = {}
        shouldContinue := false
        should_exit := false
        shouldReset := false
        elems: []Ui_Elem =  {
            Ui_Button{"continue", &shouldContinue},
            Ui_Button{"play again", &shouldReset},
            Ui_Button{"exit to main menu", &should_exit},
        }

        ui_update_and_draw_elems(elems[:])


        if shouldContinue {
            if level.nextMapName == "" {
                should_exit = true
            } else {
                if level_loadFromFile(level.nextMapName) {
                    app_set_state(.Game)
                    menu_resetState()
                } else {
                    should_exit = true
                }
            }
        }
        if should_exit {
            app_set_state(.Main_Menu)
        }
        if shouldReset {
            player_die()
            menu_resetState()
            g_state.paused = false
        }
    } else {
        should_exit := false
        shouldReset := false
        elems := make([dynamic]Ui_Elem, context.temp_allocator)
        append(
            &elems,
            Ui_Button{"RESUME", &g_state.paused},
            Ui_Button{"reset", &shouldReset},
            Ui_Button{"go to main menu", &should_exit},
            Ui_Button{"exit to desktop", &exit_next_frame},
        )
        append(&elems, ..menu_settings_elems())

        menu_drawNavTips()
        if ui_update_and_draw_elems(elems[:]) {
            settings_save()
        }

        rl.SetSoundVolume(g_state.assets.player.swooshSound, 0.0)

        screen_tint = linalg.lerp(screen_tint, Vec3{0.1, 0.1, 0.1}, clamp(delta * 5.0, 0.0, 1.0))

        if should_exit {
            app_set_state(.Main_Menu)
        }
        if shouldReset {
            player_die()
            menu_resetState()
            g_state.paused = false
        }
    }
}



menu_updateAndDrawMainMenuUpdatePath :: proc() {
    using g_state

    rl.SetMusicVolume(g_state.assets.music[.Load_Screen], 1.0)
    current_music = &g_state.assets.music[.Load_Screen]

    rl.BeginDrawing()
    rl.ClearBackground(rl.ColorFromNormalized(UI_BACKGROUND))
    menu_drawNavTips()
    menu_drawDebugUI()

    if g_state.menu.mapSelectIsOpen {
        ui_update_and_draw_elems(g_state.menu.mapSelectFileElems[:g_state.menu.mapSelectFileElemsCount])
        if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
            rl.PlaySound(g_state.menu.setValSound)
            menu_resetState()
        }

        if g_state.menu.mapSelectButtonBool {
            g_state.menu.mapSelectButtonBool = false
            elem, ok := g_state.menu.mapSelectFileElems[g_state.menu.selected].(Ui_File_Button)
            if ok {
                if level_loadFromFileAbs(elem.fullpath) {
                    app_set_state(.Game)
                    menu_resetState()
                }
            } else {
                println("! error: selected element is invalid")
            }
        }

    } else {
        shouldMapSelect := false
        elems := make([dynamic]Ui_Elem, context.temp_allocator)
        append(
            &elems,
            Ui_Button{"SINGLEPLAYER", &shouldMapSelect},
            Ui_Button{"exit to desktop", &exit_next_frame},
        )
        append(&elems, ..menu_settings_elems())

        if ui_update_and_draw_elems(elems[:]) {
            settings_save()
        }

        if shouldMapSelect {
            menu_mainMenuFetchMapSelectFiles()
            menu_resetState()
            g_state.menu.mapSelectIsOpen = true
        }
    }

    rl.EndDrawing()
}

menu_settings_elems :: proc() -> []Ui_Elem {
    using g_state
    return(
         {
            Ui_Menu_Title{"settings"},
            Ui_F32{"audio volume", &settings.master_volume, 0.05},
            Ui_F32{"music volume", &settings.music_volume, 0.05},
            Ui_F32{"mouse sensitivity", &settings.mouse_speed, 0.05},
            Ui_F32{"crosshair visibility", &settings.crosshair_opacity, 0.1},
            Ui_F32{"gun size offset", &settings.gun_offset_x, 0.025},
            Ui_F32{"fild of view", &settings.fov, 10.0},
            Ui_F32{"viewmodel field of view", &settings.gun_fov, 10.0},
            Ui_Bool{"show FPS", &settings.draw_fps},
            Ui_Bool{"enable debug mode", &settings.debug},
        } \
    )
}

menu_mainMenuFetchMapSelectFiles :: proc() {
    println(#procedure)
    path := fmt.tprint(args = {g_state.load_dir, filepath.SEPARATOR_STRING, "maps"}, sep = "")
    println("path:", path)

    g_state.menu.mapSelectFileElemsCount = 0

    mapSelectFilesFetchDirAndAppend(path)

    // WARNING: recursive! we also load subfolders!
    mapSelectFilesFetchDirAndAppend :: proc(dir: string) {
        println(#procedure)
        println("dir:", dir)
        dirhandle, oerr := os.open(dir)
        if oerr != os.ERROR_NONE do return
        filebuf, rerr := os.read_dir(dirhandle, MENU_MAX_MAP_SELECT_FILES, context.allocator)
        if rerr != os.ERROR_NONE do return
        defer delete(filebuf)

        for i := 0; i < len(filebuf); i += 1 do println(i, filebuf[i].fullpath, filebuf[i].name) // debug

        // get all maps
        for i := 0; i < len(filebuf); i += 1 {
            fileinfo := filebuf[i]
            if fileinfo.is_dir do continue // skip for now
            if fileinfo.name[0] == '_' do continue // hidden
            dotindex := strings.index_byte(fileinfo.name, '.')
            if dotindex == 0 do continue
            if fileinfo.name[dotindex:] != ".dqm" do continue // check suffix
            //g_state.menu.mapSelectFileElems[g_state.menu.mapSelectFileElemsCount] = Ui_Button{fileinfo.name[:dotindex], &g_state.menu.mapSelectButtonBool}
            g_state.menu.mapSelectFileElems[g_state.menu.mapSelectFileElemsCount] = Ui_File_Button {
                fileinfo.name[:dotindex],
                fileinfo.fullpath,
                &g_state.menu.mapSelectButtonBool,
            }
            g_state.menu.mapSelectFileElemsCount += 1
        }

        // get subfolders
        for i := 0; i < len(filebuf); i += 1 {
            fileinfo := filebuf[i]
            if !fileinfo.is_dir do continue
            if fileinfo.name[0] == '_' do continue // hidden
            g_state.menu.mapSelectFileElems[g_state.menu.mapSelectFileElemsCount] = Ui_Menu_Title {
                fileinfo.name,
            }
            g_state.menu.mapSelectFileElemsCount += 1
            mapSelectFilesFetchDirAndAppend(fileinfo.fullpath)
        }
    }
}



menu_updateAndDrawLoadScreenUpdatePath :: proc(delta: f32) {
    using g_state

    if i32(rl.GetKeyPressed()) != 0 ||
       rl.IsMouseButtonPressed(rl.MouseButton.LEFT) ||
       rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) ||
       rl.IsMouseButtonPressed(rl.MouseButton.MIDDLE) {
        app_set_state(.Main_Menu)
        rl.PlaySound(g_state.menu.setValSound)
    }

    if !rl.IsWindowReady() do g_state.menu.loadScreenTimer = 0.0

    unfade := math.sqrt(glsl.smoothstep(0.0, 1.0, g_state.menu.loadScreenTimer * 0.5))

    rl.SetMusicVolume(g_state.assets.music[.Load_Screen], pow(unfade, 3))
    current_music = &g_state.assets.music[.Load_Screen]

    rl.BeginDrawing()
    rl.ClearBackground(rl.ColorFromNormalized(linalg.lerp(Vec4{0, 0, 0, 0}, UI_BACKGROUND, unfade)))

    OFFS :: 200
    STARTSCALE :: 4.0
    scale :=
        glsl.min(
            f32(window_size.x) / f32(g_state.assets.loadScreenLogo.width),
            f32(window_size.y) / f32(g_state.assets.loadScreenLogo.height),
        ) *
        (STARTSCALE + math.sqrt(unfade)) /
        (1.0 + STARTSCALE)
    col := rl.ColorFromNormalized(linalg.lerp(Vec4{0, 0, 0, 0}, Vec4{1, 1, 1, 1}, unfade))
    rl.DrawTextureEx(
        g_state.assets.loadScreenLogo,
         {
            f32(window_size.x) / 2 - f32(g_state.assets.loadScreenLogo.width) * scale / 4,
            f32(window_size.y) / 2 - f32(g_state.assets.loadScreenLogo.height) * scale / 4,
        },
        0.0, // rot
        scale * 0.5, // scale
        col,
    )

    ui_draw_text(
        {f32(window_size.x) / 2 - 100, f32(window_size.y) - 130},
        25,
        rl.ColorFromNormalized(
            linalg.lerp(
                Vec4{0, 0, 0, 0},
                Vec4{1, 1, 1, 1},
                clamp(unfade - 0.4 + math.sin(g_state.time_passed * 4.0) * 0.1, 0.0, 1.0),
            ),
        ),
        "press any key to continue",
    )

    versionstr := fmt.tprint("version: ", VERSION_STRING)
    ui_draw_text(
        {f32(window_size.x) - f32(len(versionstr) + 3) * 10, f32(window_size.y) - 50},
        25,
        col,
        versionstr,
    )
    rl.EndDrawing()

    g_state.menu.loadScreenTimer += delta
}



// draw info about the menu navigation
menu_drawNavTips :: proc() {
    SIZE :: 25.0

    ui_draw_text(
        {SIZE * 2.0, f32(g_state.window_size.y) - SIZE * 3},
        SIZE,
        {200, 200, 200, 120},
        "hold CTRL to skip to next title / edit values faster",
    )
}
