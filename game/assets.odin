package game

import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

Assets :: struct {
    postprocessShader:            rl.Shader,
    defaultShader:                rl.Shader,
    tileShader:                   rl.Shader,
    portalShader:                 rl.Shader,
    cloudShader:                  rl.Shader,
    bulletLineShader:             rl.Shader,
    tileShaderCamPosUniformIndex: rl.ShaderLocationIndex,
    wallTexture:                  rl.Texture2D,
    portalTexture:                rl.Texture2D,
    elevatorTexture:              rl.Texture2D,
    cloudTexture:                 rl.Texture2D,
    backgroundMusic:              rl.Music,
    ambientMusic:                 rl.Music,
    elevatorSound:                rl.Sound,
    elevatorEndSound:             rl.Sound,
    tileModel:                    rl.Model,
    elevatorModel:                rl.Model,
    healthPickupModel:            rl.Model,
    boxModel:                     rl.Model, // the wooden crate
    thornsModel:                  rl.Model,
    player:                       struct {
        jumpSound:         rl.Sound,
        footstepSound:     rl.Sound,
        landSound:         rl.Sound,
        damageSound:       rl.Sound,
        swooshSound:       rl.Sound,
        healthPickupSound: rl.Sound,
    },
    gun:                          struct {
        flareModel:      rl.Model,
        gunModels:       [Gun_Kind]rl.Model,
        shotgunSound:    rl.Sound,
        machinegunSound: rl.Sound,
        laserrifleSound: rl.Sound,
        headshotSound:   rl.Sound,
        emptyMagSound:   rl.Sound,
        ammoPickupSound: rl.Sound,
        gunSwitchSound:  rl.Sound,
    },
    enemy:                        struct {
        gruntHitSound:    rl.Sound,
        gruntDeathSound:  rl.Sound,
        knightHitSound:   rl.Sound,
        knightDeathSound: rl.Sound,
        gruntModel:       rl.Model,
        knightModel:      rl.Model,
        knightAnim:       [^]rl.ModelAnimation,
        knightAnimCount:  u32,
        gruntAnim:        [^]rl.ModelAnimation,
        gruntAnimCount:   u32,
        gruntTexture:     rl.Texture2D,
        knightTexture:    rl.Texture2D,
    },
    loadScreenLogo:               rl.Texture,
    music:                        [Music_Id]rl.Music,
}

Music_Id :: enum u8 {
    Load_Screen,
    Background,
    Ambient,
}


// loads assets we don't need to unload until end of the game
assets_load_persistent :: proc() -> (result: Assets) {
    result.loadScreenLogo = loadTexture("dungeon_of_quake_logo.png")
    result.music = {
        .Load_Screen = loadMusic("ambient0.wav"),
        .Background = {},
        .Ambient = {},
    }
    rl.SetTextureFilter(result.loadScreenLogo, rl.TextureFilter.TRILINEAR)
    rl.PlayMusicStream(result.music[.Load_Screen])

    result.defaultShader = loadShader("default.vert", "default.frag")
    result.postprocessShader = loadFragShader("postprocess.frag")
    result.tileShader = loadShader("tile.vert", "tile.frag")
    result.portalShader = loadShader("portal.vert", "portal.frag")
    result.cloudShader = loadShader("primitive.vert", "cloud.frag")
    result.bulletLineShader = loadShader("bulletLine.vert", "bulletLine.frag")
    result.tileShaderCamPosUniformIndex =
    cast(rl.ShaderLocationIndex)rl.GetShaderLocation(result.tileShader, "camPos")

    result.wallTexture = loadTexture("tile0.png")
    result.portalTexture = loadTexture("portal.png")
    result.elevatorTexture = loadTexture("metal.png")
    result.cloudTexture = loadTexture("clouds.png")

    result.backgroundMusic = loadMusic("music0.wav")
    result.ambientMusic = loadMusic("wind.wav")
    result.elevatorSound = loadSound("elevator.wav")
    result.elevatorEndSound = loadSound("elevator_end0.wav")
    rl.SetSoundVolume(result.elevatorSound, 0.4)
    rl.PlayMusicStream(result.ambientMusic)
    rl.SetMasterVolume(0.5)

    result.gun.shotgunSound = loadSound("shotgun.wav")
    result.gun.machinegunSound = loadSound("machinegun.wav")
    result.gun.laserrifleSound = loadSound("laserrifle.wav")
    result.gun.headshotSound = loadSound("headshot.wav")
    result.gun.emptyMagSound = loadSound("emptymag.wav")
    result.gun.ammoPickupSound = loadSound("ammo_pickup.wav")
    result.gun.gunSwitchSound = loadSound("gun_switch.wav")
    rl.SetSoundVolume(result.gun.headshotSound, 1.0)
    rl.SetSoundPitch(result.gun.headshotSound, 0.85)
    rl.SetSoundVolume(result.gun.shotgunSound, 0.55)
    rl.SetSoundPitch(result.gun.shotgunSound, 1.1)
    rl.SetSoundVolume(result.gun.laserrifleSound, 0.2)
    rl.SetSoundPitch(result.gun.laserrifleSound, 0.8)
    rl.SetSoundVolume(result.gun.emptyMagSound, 0.6)
    rl.SetSoundVolume(result.gun.ammoPickupSound, 1.2)

    result.player.jumpSound = loadSound("jump.wav")
    result.player.footstepSound = loadSound("footstep.wav")
    result.player.landSound = loadSound("land.wav")
    result.player.damageSound = loadSound("death0.wav")
    result.player.swooshSound = loadSound("swoosh.wav")
    result.player.healthPickupSound = loadSound("heal.wav")
    rl.SetSoundVolume(result.player.footstepSound, 1.1)
    rl.SetSoundVolume(result.player.landSound, 0.45)
    rl.SetSoundPitch(result.player.landSound, 0.8)

    result.gun.gunModels = {
        .Shotgun     = loadModel("shotgun.glb"),
        .Machine_Gun = loadModel("machinegun.glb"),
        .Laser_Rifle = loadModel("laserrifle.glb"),
    }

    result.gun.flareModel = loadModel("flare.glb")

    result.tileModel = rl.LoadModelFromMesh(rl.GenMeshCube(1.0, 1.0, 1.0))
    result.elevatorModel = loadModel("elevator.glb")
    result.healthPickupModel = loadModel("healthpickup.glb")
    result.boxModel = loadModel("box.glb")
    result.thornsModel = loadModel("thorns.glb")
    rl.SetMaterialTexture(&result.tileModel.materials[0], rl.MaterialMapIndex.ALBEDO, result.wallTexture)
    rl.SetMaterialTexture(
        &result.elevatorModel.materials[0],
        rl.MaterialMapIndex.ALBEDO,
        result.elevatorTexture,
    )
    result.tileModel.materials[0].shader = result.tileShader
    result.elevatorModel.materials[0].shader = result.tileShader
    result.boxModel.materials[1].shader = result.defaultShader
    result.thornsModel.materials[1].shader = result.defaultShader

    result.enemy.gruntHitSound = loadSound("death3.wav")
    result.enemy.gruntDeathSound = result.enemy.gruntHitSound
    result.enemy.knightHitSound = result.enemy.gruntHitSound
    result.enemy.knightDeathSound = result.enemy.gruntHitSound
    rl.SetSoundVolume(result.enemy.gruntHitSound, 0.35)
    rl.SetSoundPitch(result.enemy.gruntHitSound, 1.3)

    // // result.enemy.gruntModel = loadModel("grunt.iqm")
    // // result.enemy.knightModel = loadModel("knight.iqm")
    // // result.enemy.gruntAnim = loadModelAnim("grunt.iqm", &result.enemy.gruntAnimCount)
    // // result.enemy.knightAnim = loadModelAnim("knight.iqm", &result.enemy.knightAnimCount)
    // result.enemy.gruntTexture = loadTexture("grunt.png")
    // result.enemy.knightTexture = loadTexture("knight.png")
    // rl.SetMaterialTexture(
    //     &result.enemy.gruntModel.materials[0],
    //     rl.MaterialMapIndex.ALBEDO,
    //     result.enemy.gruntTexture,
    // )
    // rl.SetMaterialTexture(
    //     &result.enemy.knightModel.materials[0],
    //     rl.MaterialMapIndex.ALBEDO,
    //     result.enemy.knightTexture,
    // )


    // gui.menuContext.normalFont = loadFont("germania_one.ttf")
    // gui.menuContext.selectSound = loadSound("button4.wav")
    // gui.menuContext.setValSound = loadSound("button3.wav")
    // rl.SetSoundVolume(gui.menuContext.selectSound, 0.6)
    // rl.SetSoundVolume(gui.menuContext.setValSound, 0.8)

    return result
}



asset_path :: proc(subdir: string, path: string, allocator := context.temp_allocator) -> string {
    return filepath.join({g_state.load_dir, subdir, path}, allocator)
}

// ctx temp alloc
asset_path_cstr :: proc(subdir: string, path: string, allocator := context.temp_allocator) -> cstring {
    return strings.clone_to_cstring(asset_path(subdir, path), allocator)
}

loadTexture :: proc(path: string) -> rl.Texture {
    fullpath := asset_path_cstr("textures", path)
    println("! loading texture: ", fullpath)
    return rl.LoadTexture(fullpath)
}

loadSound :: proc(path: string) -> rl.Sound {
    //if !rl.IsAudioDeviceReady() do return {}
    fullpath := asset_path_cstr("audio", path)
    println("! loading sound: ", fullpath)
    return rl.LoadSound(fullpath)
}

loadMusic :: proc(path: string) -> rl.Music {
    //if !rl.IsAudioDeviceReady() do return {}
    fullpath := asset_path_cstr("audio", path)
    println("! loading music: ", fullpath)
    return rl.LoadMusicStream(fullpath)
}

loadFont :: proc(path: string) -> rl.Font {
    fullpath := asset_path_cstr("fonts", path)
    println("! loading font: ", fullpath)
    return rl.LoadFontEx(fullpath, 32, nil, 0)
    //return rl.LoadFont(fullpath)
}

loadModel :: proc(path: string) -> rl.Model {
    fullpath := asset_path_cstr("models", path)
    println("! loading model: ", fullpath)
    return rl.LoadModel(fullpath)
}

loadModelAnim :: proc(path: string, outCount: ^u32) -> [^]rl.ModelAnimation {
    fullpath := asset_path_cstr("anim", path)
    println("! loading anim: ", fullpath)
    return rl.LoadModelAnimations(fullpath, outCount)
}

loadShader :: proc(vertpath: string, fragpath: string) -> rl.Shader {
    vertfullpath := asset_path_cstr("shaders", vertpath)
    fragfullpath := asset_path_cstr("shaders", fragpath)
    println("! loading shader: vert: ", vertfullpath, "frag:", fragfullpath)
    return rl.LoadShader(vertfullpath, fragfullpath)
}

// uses default vertex shader
loadFragShader :: proc(path: string) -> rl.Shader {
    fullpath := asset_path_cstr("shaders", path)
    println("! loading shader: ", fullpath)
    return rl.LoadShader(nil, fullpath)
}
