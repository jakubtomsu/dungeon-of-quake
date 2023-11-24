package attrib

// package for simple variable serialization/deserialization


import "core:fmt"
import "core:strconv"
import "core:strings"


println :: fmt.println


SEPARATOR :: ":"

match :: proc(buf: []u8, index: ^i32, name: string) -> bool {
    //println("buf", buf, "index", index^, "name", name)
    endindex: i32 = cast(i32)strings.index_byte(string(buf[index^:]), ':') + 1
    if endindex <= 0 do return false
    src: string = string(buf[index^:index^ + endindex])
    checkstr := fmt.tprint(args = {name, SEPARATOR}, sep = "")
    val := strings.compare(src, checkstr)
    res := val == 0
    if res {
        index^ += cast(i32)len(name) + 1
        skipWhitespace(buf, index)
    }
    return res
}

skipWhitespace :: proc(buf: []u8, index: ^i32) -> bool {
    skipped := false
    for strings.is_space(cast(rune)buf[index^]) || buf[index^] == '\n' || buf[index^] == '\r' {
        index^ += 1
        skipped = true
    }
    return skipped
}

readF32 :: proc(buf: []u8, index: ^i32) -> f32 {
    skipWhitespace(buf, index)
    str := string(buf[index^:])
    val, ok := strconv.parse_f32(str)
    _ = ok
    skipToNextWhitespace(buf, index)
    return val
}

readI32 :: proc(buf: []u8, index: ^i32) -> i32 {
    skipWhitespace(buf, index)
    str := string(buf[index^:])
    val, ok := strconv.parse_int(str)
    _ = ok
    skipToNextWhitespace(buf, index)
    return cast(i32)val
}

readBool :: proc(buf: []u8, index: ^i32) -> bool {
    skipWhitespace(buf, index)
    str := string(buf[index^:])
    res := strings.has_prefix(str, "true")
    skipToNextWhitespace(buf, index)
    return res
}

// reads string in between "
readString :: proc(buf: []u8, index: ^i32) -> string {
    skipWhitespace(buf, index)
    if buf[index^] != '\"' do return ""
    startindex := index^ + 1
    endindex := startindex + cast(i32)strings.index_byte(string(buf[startindex:]), '\"')
    index^ = endindex + 1
    res := string(buf[startindex:endindex])
    println("startindex", startindex, "endindex", endindex, "res", res)
    return res
}

skipToNextWhitespace :: proc(buf: []u8, index: ^i32) {
    for !strings.is_space(cast(rune)buf[index^]) && buf[index^] != '\n' && buf[index^] != '\r' {
        index^ += 1
        println("skip to next line")
    }
    index^ += 1
}
