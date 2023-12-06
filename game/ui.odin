package game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

UI_SCROLL_MARGIN :: 200
UI_SCROLL_SPEED :: 14.0

UI_ACTIVE_COLOR :: rl.Color{220, 220, 220, 220}
UI_INACTIVE_COLOR :: rl.Color{200, 200, 200, 160}
UI_ACTIVE_VAL_COLOR :: rl.Color{200, 70, 50, 255}
UI_INACTIVE_VAL_COLOR :: rl.Color{200, 200, 200, 160}
UI_TITLE_COLOR :: rl.Color{200, 200, 200, 100}

UI_BACKGROUND :: rl.Vector4{0.08, 0.08, 0.1, 1.0}

// val is not rendered
Ui_Button :: struct {
    name: string,
    val:  ^bool,
}

Ui_Bool :: struct {
    name: string,
    val:  ^bool,
}

Ui_F32 :: struct {
    name: string,
    val:  ^f32,
    step: f32,
}

Ui_Int :: struct {
    name: string,
    val:  ^i32,
}

Ui_Menu_Title :: struct {
    name: string,
}

Ui_File_Button :: struct {
    name:     string,
    fullpath: string,
    val:      ^bool,
}

Ui_Elem :: union {
    Ui_Button,
    Ui_Bool,
    Ui_F32,
    Ui_Int,
    Ui_Menu_Title,
    Ui_File_Button,
}

ui_draw_text :: proc(pos: rl.Vector2, size: f32, color: rl.Color, text: string) {
    cstr := strings.clone_to_cstring(text, context.temp_allocator)
    rl.DrawTextEx(menuContext.normalFont, cstr, pos, size, 0.0, color)
}

// @retunrs: true if any value changed
ui_update_and_draw_elems :: proc(elems: []Ui_Elem) -> bool {
    selectDir := 0
    if rl.IsKeyPressed(rl.KeyboardKey.DOWN) || rl.IsKeyPressed(rl.KeyboardKey.S) do selectDir += 1
    if rl.IsKeyPressed(rl.KeyboardKey.UP) || rl.IsKeyPressed(rl.KeyboardKey.W) do selectDir -= 1

    if selectDir != 0 {
        rl.PlaySound(menuContext.selectSound)

        if !rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
            loopfind: for i := 0; i < len(elems); i += 1 {
                index := (int(menuContext.selected) + i * selectDir + selectDir) %% len(elems)
                #partial switch _ in elems[index] {
                case Ui_Menu_Title:
                    continue loopfind
                }
                menuContext.selected = i32(index)
                break loopfind
            }
        } else {     // jump between titles (also stops at first/last elem)
            loopfindjump: for i := 0; i < len(elems); i += 1 {
                index := (int(menuContext.selected) + i * selectDir + selectDir) %% len(elems)
                #partial switch _ in elems[index] {
                case Ui_Menu_Title:
                    menuContext.selected = i32(index + selectDir)
                    break loopfindjump
                }

                if index == 0 || index == len(elems) - 1 {
                    menuContext.selected = i32(index)
                    break loopfindjump
                }
            }
        }
    }

    menuContext.selected = menuContext.selected %% i32(len(elems))

    SIZE :: 30
    offs: f32 = menuContext.startOffs
    selectedOffs: f32 = 0
    for i := 0; i < len(elems); i += 1 {
        isSelected := i32(i) == menuContext.selected
        col: rl.Color = isSelected ? ACTIVE_COLOR : INACTIVE_COLOR
        vcol: rl.Color = isSelected ? ACTIVE_VAL_COLOR : INACTIVE_VAL_COLOR
        W :: 150
        nameoffs := f32(menuContext.windowSizeX) / 2 - W * 1.2
        valoffs := f32(menuContext.windowSizeX) / 2 + W
        switch elem in elems[i] {
        case Ui_Button:
            drawText({nameoffs, offs}, SIZE, vcol, elem.name)
        case Ui_Bool:
            drawText({nameoffs, offs}, SIZE, col, elem.name)
            drawText({valoffs, offs}, SIZE, vcol, elem.val^ ? "yes" : "no")
        case Ui_F32:
            drawText({nameoffs, offs}, SIZE, col, elem.name)
            drawText({valoffs, offs}, SIZE, vcol, fmt.tprint(elem.val^))
        case Ui_Int:
            drawText({nameoffs, offs}, SIZE, col, elem.name)
            drawText({valoffs, offs}, SIZE, vcol, fmt.tprint(elem.val^))
        case Ui_Menu_Title:
            offs += 0.8 * SIZE
            drawText({nameoffs - SIZE, offs}, SIZE * 0.8, TITLE_COLOR, elem.name)
        case Ui_File_Button:
            drawText({nameoffs, offs}, SIZE, vcol, elem.name)
            if isSelected {
                drawText(
                    {valoffs, offs + SIZE * 0.25},
                    SIZE * 0.5,
                    {col.r, col.g, col.b, 100},
                    elem.fullpath,
                )
            }
        }

        if isSelected {
            drawText({nameoffs - 30, offs}, SIZE, vcol, ">")
            selectedOffs = offs
        }

        offs += SIZE
    }

    if selectedOffs > f32(menuContext.windowSizeY) - SCROLL_MARGIN {     // bottom
        menuContext.startOffs +=
            (f32(menuContext.windowSizeY) - SCROLL_MARGIN - selectedOffs) *
            clamp(menuContext.delta * SCROLL_SPEED, 0.0, 1.0)
    }

    if selectedOffs < SCROLL_MARGIN {     // top
        menuContext.startOffs +=
            (SCROLL_MARGIN - selectedOffs) * clamp(menuContext.delta * SCROLL_SPEED, 0.0, 1.0)
    }


    // edit selected value based on input
    isEdited := false
    switch elem in elems[menuContext.selected] {
    case Ui_Button:
        if rl.IsKeyPressed(rl.KeyboardKey.ENTER) || rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            elem.val^ = !elem.val^
            isEdited = true
        }

    case Ui_Bool:
        if rl.IsKeyPressed(rl.KeyboardKey.ENTER) ||
           rl.IsKeyPressed(rl.KeyboardKey.SPACE) ||
           rl.IsKeyPressed(rl.KeyboardKey.RIGHT) ||
           rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
            elem.val^ = !elem.val^
            isEdited = true
        }

    case Ui_F32:
        step := elem.step
        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) do step *= 5.0

        if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
            elem.val^ += step
            isEdited = true
        } else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
            elem.val^ -= step
            isEdited = true
        }

    case Ui_Int:
        step: i32 = 1
        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) do step *= 10

        if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
            elem.val^ += step
            isEdited = true
        } else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
            elem.val^ -= step
            isEdited = true
        }

    case Ui_Menu_Title:

    case Ui_File_Button:
        if rl.IsKeyPressed(rl.KeyboardKey.ENTER) || rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            elem.val^ = !elem.val^
            isEdited = true
        }
    }

    if isEdited {
        rl.PlaySound(menuContext.setValSound)
    }

    return isEdited
}
