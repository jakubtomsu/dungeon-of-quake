# DOQM map file format specification



## general info
Maps are saved as a plain text, but use the `.doqm` file extension. This means you can edit these levels with any text editor. Maps can also be split into two floors, using certain tiles.  

> **WARNING:** Text editors don't really use fonts with sqare aspect ratio characters,
so the resulting level might end up looking a little stretched in-game. In some text
editors, you can change text spacing to circumvent the issue.



## tiles
>**NOTE:** some blocks have different lowercase/uppercase versions.  
for instance: you can use uppercase `S` instead of lowercase `s` if you want the start position to be on the 2nd floor.


tile character | tile name          | note  |   
-------------- | ------------------ | ----- |
`-`            | none               |
` `            | empty              |
`#`            | full               |
`w`            | wall-mid           |
`c`            | ceiling            |
`s`            | start              |
`S`            | start              |
`f`            | finish             |
`F`            | finish             |
`p`            | small platform     |
`P`            | large platform     |
`e`            | elevator           |
`o`            | obstacle           |
`O`            | obstacle           |
`h`            | health pickup      | adds 1/4 of health to player
`H`            | health pickup      |
`d`            | shotgun pickup     |
`D`            | shotgun pickup     |
`m`            | machinegun pickup  |
`M`            | machinegun pickup  |
`l`            | laserrifle pickup  |
`L`            | laserrifle pickup  |
`k`            | knight spawn       |
`K`            | knight spawn       |
`g`            | grunt spawn        |
`G`            | grunt spawn        |



## map attributes
Each map can have some attributes which change how it looks or behaves.  

All attributes are alwats defined between a pair of curly braces `{ }`, and each attribute is followed by a colon `:` character.  
Text attribute value has to be between two quotation marks `"` like this: `"foo"`.  
example attribute declarations:  
```cpp
{
	mapName: "foo"
	skyColor: 1.0 0.5 1
}
```


attribute name | value          | note
-------------- | -------------- | ----
mapName        | `text`         | name of the map
nextMapName    | `text`         | next map to load after this one is finished
startPlayerDir | `xy decimal`   | which direction should the player be looking when the game starts
skyColor       | `rgb decimal`  | color of the sky and fog
fogStrength    | `decimal`      | strength/attenuation of fog



## simple 8x8 example level
finish is on a elevated platform made with walls (`w`), where you can't get without the elevator (`e`)  

```
########
#      #
# s    #
#      #
#      #
#wwweww#
#wwwwwF#
########
```

## more complex example level

```
{
	mapName: "example 0"
	skyColor: 1.0 0.2 0.0
	fogStrength: 1.2
	startPlayerDir: 0.0 -1.0
}

#######-------#######
#  s  #-------#ewFwe#
c     c-------c     c
#     #-------# k   #
c     c-------c   k c
#     #-------#     #
##wew##-------#Oo oO#
-#www#--------#wwwww#
##wpw##########wwwGw#
#Gwppppp--w---pwwwwww
#wwwKww########wwGww#
##w#w###------##w#w##
```
