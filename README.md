<p align="center">
  <img src="/build/textures/dungeon_of_quake_logo.png" width="400">  
</p>

<p align="center">
  Dungeon of Quake is a simple first person shooter, inspired by Quake.
  </br>
  Written in the Odin programming language, and using Raylib
</p>
</br>
</br>

**currently work in progress!**

# how to build
- get the [Odin compiler](https://github.com/odin-lang/Odin)
- add Odin to `$PATH` enviroment variable
- use `.\build.bat` command to build the game  
- use `.\build.bat run` command to build and run the game  



# maps
Maps are a top-down, ascii view on the map, and different characters correspond to different
tiles - this means anyone can edit maps with just a simple text editor.  
`.doqm` file extension, is used, even though the underlying file is just plain text.
#### Info for creating maps is in [DOQM file spec](doqm_format_spec.md)  

> The raw tile table is in [map.odin](/doq/map.odin) as `map_tileKind_t`

Some tiles are translated to different tiles when the map gets loaded into memory. For instance, lowercase
health pickup `h` is translated to `empty` tile, and the pickup itself gets spawned separately.



# TODO
- simple profiler, maybe with [chrome://tracing](chrome://tracing)
- particles
- (?) map editor, probaly as a separate program
