package game

import rl "vendor:raylib"

/*
 *  Adapted from https://github.com/raysan5/raylib/blob/master/examples/models/models_draw_cube_texture.c
 *  Since this is no longer a part of Raylib core itself
 */

doqDrawCubeTexture :: proc(
    texture: rl.Texture2D,
    position: rl.Vector3,
    width, height, length: f32,
    color: rl.Color,
) {
    x := position.x
    y := position.y
    z := position.z

    rl.rlSetTexture(texture.id)

    rl.rlBegin(rl.RL_QUADS)

    rl.rlColor4ub(color.r, color.g, color.b, color.a)
    // Front Face
    rl.rlNormal3f(0.0, 0.0, 1.0) // Normal Pointing Towards Viewer
    rl.rlTexCoord2f(0.0, 0.0)
    rl.rlVertex3f(x - width / 2, y - height / 2, z + length / 2) // Bottom Left Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 0.0)
    rl.rlVertex3f(x + width / 2, y - height / 2, z + length / 2) // Bottom Right Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 1.0)
    rl.rlVertex3f(x + width / 2, y + height / 2, z + length / 2) // Top Right Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 1.0)
    rl.rlVertex3f(x - width / 2, y + height / 2, z + length / 2) // Top Left Of The Texture and Quad
    // Back Face
    rl.rlNormal3f(0.0, 0.0, -1.0) // Normal Pointing Away From Viewer
    rl.rlTexCoord2f(1.0, 0.0)
    rl.rlVertex3f(x - width / 2, y - height / 2, z - length / 2) // Bottom Right Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 1.0)
    rl.rlVertex3f(x - width / 2, y + height / 2, z - length / 2) // Top Right Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 1.0)
    rl.rlVertex3f(x + width / 2, y + height / 2, z - length / 2) // Top Left Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 0.0)
    rl.rlVertex3f(x + width / 2, y - height / 2, z - length / 2) // Bottom Left Of The Texture and Quad
    // Top Face
    rl.rlNormal3f(0.0, 1.0, 0.0) // Normal Pointing Up
    rl.rlTexCoord2f(0.0, 1.0)
    rl.rlVertex3f(x - width / 2, y + height / 2, z - length / 2) // Top Left Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 0.0)
    rl.rlVertex3f(x - width / 2, y + height / 2, z + length / 2) // Bottom Left Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 0.0)
    rl.rlVertex3f(x + width / 2, y + height / 2, z + length / 2) // Bottom Right Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 1.0)
    rl.rlVertex3f(x + width / 2, y + height / 2, z - length / 2) // Top Right Of The Texture and Quad
    // Bottom Face
    rl.rlNormal3f(0.0, -1.0, 0.0) // Normal Pointing Down
    rl.rlTexCoord2f(1.0, 1.0)
    rl.rlVertex3f(x - width / 2, y - height / 2, z - length / 2) // Top Right Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 1.0)
    rl.rlVertex3f(x + width / 2, y - height / 2, z - length / 2) // Top Left Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 0.0)
    rl.rlVertex3f(x + width / 2, y - height / 2, z + length / 2) // Bottom Left Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 0.0)
    rl.rlVertex3f(x - width / 2, y - height / 2, z + length / 2) // Bottom Right Of The Texture and Quad
    // Right face
    rl.rlNormal3f(1.0, 0.0, 0.0) // Normal Pointing Right
    rl.rlTexCoord2f(1.0, 0.0)
    rl.rlVertex3f(x + width / 2, y - height / 2, z - length / 2) // Bottom Right Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 1.0)
    rl.rlVertex3f(x + width / 2, y + height / 2, z - length / 2) // Top Right Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 1.0)
    rl.rlVertex3f(x + width / 2, y + height / 2, z + length / 2) // Top Left Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 0.0)
    rl.rlVertex3f(x + width / 2, y - height / 2, z + length / 2) // Bottom Left Of The Texture and Quad
    // Left Face
    rl.rlNormal3f(-1.0, 0.0, 0.0) // Normal Pointing Left
    rl.rlTexCoord2f(0.0, 0.0)
    rl.rlVertex3f(x - width / 2, y - height / 2, z - length / 2) // Bottom Left Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 0.0)
    rl.rlVertex3f(x - width / 2, y - height / 2, z + length / 2) // Bottom Right Of The Texture and Quad
    rl.rlTexCoord2f(1.0, 1.0)
    rl.rlVertex3f(x - width / 2, y + height / 2, z + length / 2) // Top Right Of The Texture and Quad
    rl.rlTexCoord2f(0.0, 1.0)
    rl.rlVertex3f(x - width / 2, y + height / 2, z - length / 2) // Top Left Of The Texture and Quad

    rl.rlEnd()

    rl.rlSetTexture(0)

}
