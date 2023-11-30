package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
    rl.InitWindow(800, 600, "collision")
    defer rl.CloseWindow()

    rl.SetWindowSize(rl.GetScreenWidth(), rl.GetScreenHeight())
    rl.DisableCursor()


    look_angles: rl.Vector2 = 0
    cam: rl.Camera3D = {
        position = {5, 1, 5},
        target = {0, 0, 3},
        up = {0, 3, 0},
        fovy = 90,
        projection = .PERSPECTIVE,
    }

    vel: rl.Vector3

    tris: [dynamic][3]rl.Vector3

    append_quad :: proc(tris: ^[dynamic][3]rl.Vector3, a, b, c, d: rl.Vector3, offs: rl.Vector3 = {}) {
        points := [][3]rl.Vector3{{b + offs, a + offs, c + offs}, {b + offs, c + offs, d + offs}}
        append(tris, ..points)
    }

    append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {0, -2, 0})
    append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {0, -2, 10})
    append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {10, 0, 10})
    append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 10, 10}, {10, 10, 10}, {10, 0, 20})
    append_quad(&tris, {0, 0, 0}, {10, 0, 0}, {0, 0, 10}, {10, 0, 10}, {10, 10, 30})

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground({40, 30, 50, 255})
        rl.BeginMode3D(cam)

        dt := rl.GetFrameTime()

        rot :=
            linalg.quaternion_from_euler_angle_y_f32(look_angles.y) *
            linalg.quaternion_from_euler_angle_x_f32(look_angles.x)

        forward := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{0, 0, 1})
        right := linalg.quaternion128_mul_vector3(rot, linalg.Vector3f32{1, 0, 0})

        look_angles.y -= rl.GetMouseDelta().x * 0.0015
        look_angles.x += rl.GetMouseDelta().y * 0.0015

        SPEED :: 20
        RAD :: 1

        if rl.IsKeyDown(.W) do vel += forward * dt * SPEED
        if rl.IsKeyDown(.S) do vel -= forward * dt * SPEED
        if rl.IsKeyDown(.D) do vel -= right * dt * SPEED
        if rl.IsKeyDown(.A) do vel += right * dt * SPEED

        if rl.IsKeyDown(.E) do vel.y += dt * SPEED
        if rl.IsKeyDown(.Q) do vel.y -= dt * SPEED

        // gravity
        vel.y -= dt * 10 * (vel.y < 0.0 ? 2 : 1)

        if rl.IsKeyPressed(.SPACE) do vel.y = 15

        // damping
        vel *= 1.0 / (1.0 + dt * 2)

        // Collide
        for t in tris {
            closest := closest_point_on_triangle(cam.position, t[0], t[1], t[2])
            diff := cam.position - closest
            dist := linalg.length(diff)
            normal := diff / dist

            rl.DrawCubeV(closest, 0.05, dist > RAD ? rl.ORANGE : rl.WHITE)

            if dist < RAD {
                cam.position += normal * (RAD - dist)
                // project velocity to the normal plane, if moving towards it
                vel_normal_dot := linalg.dot(vel, normal)
                if vel_normal_dot < 0 {
                    vel -= normal * vel_normal_dot
                }
            }
        }

        cam.position += vel * dt
        cam.target = cam.position + forward

        rl.DrawCubeV(cam.position + forward * 10, 0.25, rl.BLACK)
        for t in tris {
            rl.DrawTriangle3D(t[0], t[1], t[2], rl.GRAY)
            rl.DrawLine3D(t[0], t[1], rl.LIGHTGRAY)
            rl.DrawLine3D(t[0], t[2], rl.LIGHTGRAY)
            rl.DrawLine3D(t[1], t[2], rl.LIGHTGRAY)
        }

        rl.DrawCube({0, 0, 0}, 0.1, 0.1, 0.1, rl.WHITE)
        rl.DrawCube({1, 0, 0}, 1, 0.1, 0.1, rl.RED)
        rl.DrawCube({0, 1, 0}, 0.1, 1, 0.1, rl.GREEN)
        rl.DrawCube({0, 0, 1}, 0.1, 0.1, 1, rl.BLUE)

        rl.EndMode3D()

        rl.DrawFPS(4, 4)

        rl.DrawText(fmt.ctprintf("pos: %v, vel: %v", cam.position, vel), 4, 30, 20, rl.WHITE)

        rl.EndDrawing()
    }
}

// Real Time collision detection 5.1.5
closest_point_on_triangle :: proc(p, a, b, c: rl.Vector3) -> rl.Vector3 {
    // Check if P in vertex region outside A
    ab := b - a
    ac := c - a
    ap := p - a
    d1 := linalg.dot(ab, ap)
    d2 := linalg.dot(ac, ap)
    if d1 <= 0.0 && d2 <= 0.0 do return a // barycentric coordinates (1,0,0)
    // Check if P in vertex region outside B
    bp := p - b
    d3 := linalg.dot(ab, bp)
    d4 := linalg.dot(ac, bp)
    if d3 >= 0.0 && d4 <= d3 do return b // barycentric coordinates (0,1,0)
    // Check if P in edge region of AB, if so return projection of P onto AB
    vc := d1 * d4 - d3 * d2
    if vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0 {
        v := d1 / (d1 - d3)
        return a + v * ab // barycentric coordinates (1-v,v,0)
    }
    // Check if P in vertex region outside C
    cp := p - c
    d5 := linalg.dot(ab, cp)
    d6 := linalg.dot(ac, cp)
    if d6 >= 0.0 && d5 <= d6 do return c // barycentric coordinates (0,0,1)
    // Check if P in edge region of AC, if so return projection of P onto AC
    vb := d5 * d2 - d1 * d6
    if vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0 {
        w := d2 / (d2 - d6)
        return a + w * ac // barycentric coordinates (1-w,0,w)
    }
    // Check if P in edge region of BC, if so return projection of P onto BC
    va := d3 * d6 - d5 * d4
    if va <= 0.0 && (d4 - d3) >= 0.0 && (d5 - d6) >= 0.0 {
        w := (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return b + w * (c - b) // barycentric coordinates (0,1-w,w)
    }
    // P inside face region. Compute Q through its barycentric coordinates (u,v,w)
    denom := 1.0 / (va + vb + vc)
    v := vb * denom
    w := vc * denom
    return a + ab * v + ac * w // = u*a + v*b + w*c, u = va * denom = 1.0-v-w
}
