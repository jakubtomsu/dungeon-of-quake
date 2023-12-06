// +build windows
package game

import "core:sys/windows"

_platform_game_save_dir :: proc(allocator := context.allocator) -> Maybe(string) {
    S_OK :: 0
    path: windows.LPWSTR
    folder_id := windows.FOLDERID_SavedGames
    if windows.SHGetKnownFolderPath(&folder_id, u32(windows.KNOWN_FOLDER_FLAG.CREATE), nil, &path) == S_OK {
        if str, err := windows.wstring_to_utf8(path, -1, allocator); err == nil {
            return str
        }
    }
    return nil
}
