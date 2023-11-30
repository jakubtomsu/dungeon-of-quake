package game

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

println :: fmt.println
tprint :: fmt.tprint
tprintf :: fmt.tprintf

Vec2 :: rl.Vector2
Vec3 :: rl.Vector3
Vec4 :: rl.Vector4
IVec2 :: [2]i32
Mat3 :: linalg.Matrix3f32

Error :: union {
    bool,
    json.Error,
}

playSound :: proc(sound: rl.Sound) {
    if !rl.IsAudioDeviceReady() do return
    rl.PlaySound(sound)
}

playSoundMulti :: proc(sound: rl.Sound) {
    if !rl.IsAudioDeviceReady() do return
    //rl.PlaySoundMulti(sound)
}

// rand vector with elements in -1..1
randVec3 :: proc() -> Vec3 {
    return(
        Vec3 {
            rand.float32_range(-1.0, 1.0, &randData),
            rand.float32_range(-1.0, 1.0, &randData),
            rand.float32_range(-1.0, 1.0, &randData),
        } \
    )
}

roundstep :: proc(a: f32, step: f32) -> f32 {
    return math.round(a * step) / step
}
