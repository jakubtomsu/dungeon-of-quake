package gui


//
// GUI
// menus and on-screen UI
//



import "core:fmt"
import "core:strings"
import rl "vendor:raylib"



SCROLL_MARGIN :: 200
SCROLL_SPEED :: 14.0

ACTIVE_COLOR :: rl.Color{220, 220, 220, 220}
INACTIVE_COLOR :: rl.Color{200, 200, 200, 160}
ACTIVE_VAL_COLOR :: rl.Color{200, 70, 50, 255}
INACTIVE_VAL_COLOR :: rl.Color{200, 200, 200, 160}
TITLE_COLOR :: rl.Color{200, 200, 200, 100}

BACKGROUND :: rl.Vector4{0.08, 0.08, 0.1, 1.0}



menuContext: struct {
    selected:    i32, // this can be shared, since we always have only one menu on screen
    startOffs:   f32,
    normalFont:  rl.Font,
    selectSound: rl.Sound,
    setValSound: rl.Sound,

    // gui inputs
    windowSizeX: i32,
    windowSizeY: i32,
    deltatime:   f32,
}

// val is not rendered
menuButton_t :: struct {
    name: string,
    val:  ^bool,
}

menuBool_t :: struct {
    name: string,
    val:  ^bool,
}

menuF32_t :: struct {
    name: string,
    val:  ^f32,
    step: f32,
}

menuI32_t :: struct {
    name: string,
    val:  ^i32,
}

menuTitle_t :: struct {
    name: string,
}

menuFileButton_t :: struct {
    name:     string,
    fullpath: string,
    val:      ^bool,
}

menuElem_t :: union {
    menuButton_t,
    menuBool_t,
    menuF32_t,
    menuI32_t,
    menuTitle_t,
    menuFileButton_t,
}



drawText :: proc(pos: rl.Vector2, size: f32, color: rl.Color, text: string) {
    cstr := strings.clone_to_cstring(text, context.temp_allocator)
    rl.DrawTextEx(menuContext.normalFont, cstr, pos, size, 0.0, color)
}

// @retunrs: true if any value changed
updateAndDrawElemBuf :: proc(elems: []menuElem_t) -> bool {
    selectDir := 0
    if rl.IsKeyPressed(rl.KeyboardKey.DOWN) || rl.IsKeyPressed(rl.KeyboardKey.S) do selectDir += 1
    if rl.IsKeyPressed(rl.KeyboardKey.UP) || rl.IsKeyPressed(rl.KeyboardKey.W) do selectDir -= 1

    if selectDir != 0 {
        rl.PlaySound(menuContext.selectSound)

        if !rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) {
            loopfind: for i := 0; i < len(elems); i += 1 {
                index := (int(menuContext.selected) + i * selectDir + selectDir) %% len(elems)
                #partial switch _ in elems[index] {
                case menuTitle_t:
                    continue loopfind
                }
                menuContext.selected = i32(index)
                break loopfind
            }
        } else {     // jump between titles (also stops at first/last elem)
            loopfindjump: for i := 0; i < len(elems); i += 1 {
                index := (int(menuContext.selected) + i * selectDir + selectDir) %% len(elems)
                #partial switch _ in elems[index] {
                case menuTitle_t:
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
        case menuButton_t:
            drawText({nameoffs, offs}, SIZE, vcol, elem.name)
        case menuBool_t:
            drawText({nameoffs, offs}, SIZE, col, elem.name)
            drawText({valoffs, offs}, SIZE, vcol, elem.val^ ? "yes" : "no")
        case menuF32_t:
            drawText({nameoffs, offs}, SIZE, col, elem.name)
            drawText({valoffs, offs}, SIZE, vcol, fmt.tprint(elem.val^))
        case menuI32_t:
            drawText({nameoffs, offs}, SIZE, col, elem.name)
            drawText({valoffs, offs}, SIZE, vcol, fmt.tprint(elem.val^))
        case menuTitle_t:
            offs += 0.8 * SIZE
            drawText({nameoffs - SIZE, offs}, SIZE * 0.8, TITLE_COLOR, elem.name)
        case menuFileButton_t:
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
            clamp(menuContext.deltatime * SCROLL_SPEED, 0.0, 1.0)
    }

    if selectedOffs < SCROLL_MARGIN {     // top
        menuContext.startOffs +=
            (SCROLL_MARGIN - selectedOffs) * clamp(menuContext.deltatime * SCROLL_SPEED, 0.0, 1.0)
    }


    // edit selected value based on input
    isEdited := false
    switch elem in elems[menuContext.selected] {
    case menuButton_t:
        if rl.IsKeyPressed(rl.KeyboardKey.ENTER) || rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
            elem.val^ = !elem.val^
            isEdited = true
        }

    case menuBool_t:
        if rl.IsKeyPressed(rl.KeyboardKey.ENTER) ||
           rl.IsKeyPressed(rl.KeyboardKey.SPACE) ||
           rl.IsKeyPressed(rl.KeyboardKey.RIGHT) ||
           rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
            elem.val^ = !elem.val^
            isEdited = true
        }

    case menuF32_t:
        step := elem.step
        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) do step *= 5.0

        if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
            elem.val^ += step
            isEdited = true
        } else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
            elem.val^ -= step
            isEdited = true
        }

    case menuI32_t:
        step: i32 = 1
        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) do step *= 10

        if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
            elem.val^ += step
            isEdited = true
        } else if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
            elem.val^ -= step
            isEdited = true
        }

    case menuTitle_t:

    case menuFileButton_t:
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
