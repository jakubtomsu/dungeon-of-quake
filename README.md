<p align="center">
  <img src="/build/textures/dungeon_of_quake_logo.png" width="400">  
</p>

<p align="center">
Dungeon of Quake is a simple first person shooter, inspired by Quake.
</br>
made with
<a href="https://odin-lang.org">Odin programming language</a> 
and
<a href="https://raylib.com">Raylib</a>
</p>
</br>
</br>

**currently work in progress!**

# maps
#### Info for creating maps is in [DQM file spec](dqm_format_spec.md)  
Maps are a top-down, ascii view on the map, and different characters correspond to different
tiles - this means anyone can edit maps with just a simple text editor.  
`.dqm` file extension is used, even though the underlying file is just plain text.

> The raw tile table is in [map.odin](/doq/map.odin) as `map_tileKind_t`

Some tiles are translated to different tiles when the map gets loaded into memory. For instance, lowercase
health pickup `h` is translated to `empty` tile, and the pickup itself gets spawned separately.


# how to build
- get the [Odin compiler](https://github.com/odin-lang/Odin) (builds are usually tested on the last official release)
- add Odin to `$PATH` enviroment variable
- use `.\build.bat` command to build the game  
- or use `.\build.bat run` command to build and run the game  


# TODO
- fix: physics is weird on high frame rates
- better collision resolution!
- 3D audio
- simple profiler, maybe with [chrome://tracing](chrome://tracing)
- particles
- eventually render to G-buffer
- (?) map editor, probaly as a separate program



# screenshots
<img src="/misc/screenshot0.png">  
<img src="/misc/screenshot1.png">  
<img src="/misc/screenshot3.png">  
<img src="/misc/screenshot4.png">  
<img src="/misc/screenshot5.png">  
<img src="/misc/screenshot6.png">  
