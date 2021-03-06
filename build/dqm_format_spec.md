# DQM map file format specification



## general info
Maps are a top-down, ascii view on the world, where different characters correspond to different
tiles - this means anyone can edit maps with just a simple text editor.
`.dqm` file extension is used for the map files, even though the underlying data in that file is just plain text.
Maps can also be split into two floors, using specific tiles.  

Maps are stored inside the `maps/` directory of the build folder.

> **NOTE:** Text editors don't really use fonts with sqare aspect ratio characters,
so the resulting level might end up looking a little stretched in-game. In some text
editors, you can change text spacing to circumvent the issue.


## simple 8x8 example level
finish is on a elevated platform made with walls (`w`), where you can't get without the elevator (`e`)  

```cpp
########
#      #
# s    #
#      #
#      #
#wwweww#
#wwwwwF#
########
```


## tiles
>**NOTE:** some blocks have different lowercase/uppercase versions.  
for instance: you can use uppercase `S` instead of lowercase `s` if you want the start position to be on the 2nd floor.  
In that case, only the lowercase version is shown in the table, and the tile has the `uppercase` value as `✓`
>> **NOTE:** some tiles have lowercase/uppercase versions which **do not** change which floor the tile is on, but change something else.


tile character | tile name | uppercase | note |
-------------- | --------- | --------- | ---- |
`-`|none               |✕| this tile is completely empty
` `|empty              |✕| this tile has floor and ceiling, that's all
`#`|full               |✕| one very tall tile
`w`|wall-mid           |✕| wall up to the 2nd floor
`c`|ceiling            |✕| lower ceiling
`s`|start              |✓| place where the player spawns when the game starts
`f`|finish             |✓| place where the end portal is spawned
`p`|small platform     |✕| like `empty`, but also has a single tile between the 1st and 2nd floor
`P`|large platform     |✕| `platform`, but 3 tiles tall
`e`|elevator           |✕| elevator that takes you from the 1st to 2nd floor. Also adds jump boost
`o`|obstacle           |✕| like `empty`, but floor is 1 tile taller
`O`|obstacle           |✕| `obstacle`, but 2 blocks tall
`h`|health pickup      |✓| adds 1/4 of health to player
`t`|thorns             |✕| pillar with thorns/spikes, that can hurt the player when too close
`d`|shotgun pickup     |✓| refills **shotgun** ammo. `d` stands for `default`, since it's the default weapon
`m`|machinegun pickup  |✓| refills **machinegun** ammo
`l`|laser rifle pickup |✓| refills **laser rifle** ammo
`g`|grunt spawn        |✓| place where a grunt enemy spawns
`k`|knight spawn       |✓| place where a knight enemy spawns



Some tiles get translated into a different tile when loading the level. It's mostly pickups, enemies, etc.
> the translation table is in [tiles.odin](/doq/tiles/tiles.odin) inside `translate` procedure



## map attributes
Each map can have some attributes which change how it looks or behaves.  

All attributes are alwats defined between a pair of curly braces `{ }`, and each attribute is followed by a colon `:` character.  
Text attribute value has to be between two quotation marks `"` like this: `"foo"`. Multiple values, like numbers, are always separated by a space (or tab, multiple spaces, ...)  
example attribute declarations:  
```cpp
{
	skyColor: 1.0 0.5 1
}
```


attribute name | value          | note
-------------- | -------------- | ----
nextMapName    | `text`         | next map to load after this one is finished. Needs to include the `.dqm` extension. Subfolders are ok.
startPlayerDir | `xy decimal`   | which direction should the player be looking when the game starts
skyColor       | `rgb decimal`  | color of the sky and fog
fogStrength    | `decimal`      | strength/attenuation of fog


## more complex example level

```cpp
{
	nextMapName: "some_map.dqm"
	startPlayerDir: 0.0 -1.0
	skyColor: 1.0 0.2 0.0
	fogStrength: 1.2
}

#######-------#######
#  s  #-------#ewFwe#
c     c-------c     c
#     #-------# k   #
c     c-------c   k c
#h  h #-------#     #
##wew##-------#Oo oO#
-#www#--------#wwwww#
##wpw##########wwwGw#
#Gwppppp--w---pwwwwww
#wwwKww########wwGww#
##w#w###------##w#w##
```


## map directory info
Maps with underscore `_` as a first character are hidden in the map selection menu.  

You can use `_quickload.dqm` map file to instantly load a level, and bypass all the menu's.  
Subdirectories are supported in the map selection menu, but their name isn't relative to this folder, it's just the last folder in path.
