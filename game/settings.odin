package game

import "core:encoding/json"

SETTINGS_FILE_NAME :: "doq_settings.json"

Settings :: struct {
    draw_fps:          bool,
    fps_limit:         f32,
    debug:             bool,
    master_volume:     f32,
    music_volume:      f32,
    crosshair_opacity: f32,
    mouse_speed:       f32,
    fov:               f32,
    gun_fov:           f32,
    gun_offset_x:      f32,
}

SETTINGS_DEFAULT :: Settings {
    draw_fps          = false,
    debug             = false,
    master_volume     = 0.5,
    music_volume      = 0.4,
    crosshair_opacity = 0.2,
    mouse_speed       = 1.0,
    fov               = 100.0,
    gun_fov           = 110.0,
    gun_offset_x      = 0.15,
    fps_limit         = 120,
}

settings_path :: proc() -> string {
    return filepath.join({g_state.save_dir, SETTINGS_FILE_NAME})
}

settings_load_from_file :: proc(path: string) -> (result: Settings, err: Error) {
    defer if err != nil {
        result = SETTINGS_DEFAULT
    }

    data := os.read_entire_file(path, context.temp_allocator) or_return
    json.unmarshal(data, &result, json.DEFAULT_SPECIFICATION, allocator) or_return
    return result, nil
}

setting_save_to_file :: proc(path: string, settings: Settings) {
    if data, ok := json.marshal(settings, {.pretty}, context.temp_allocator); ok {
        os.write_entire_file(data)
    }
}
