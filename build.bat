
@echo off

echo build...
call odin build dungeon_of_quake.odin -out:build/dungeon_of_quake.exe -o:speed -strict-style -vet && if "%1%"=="run" (echo run... && cd build && call dungeon_of_quake.exe) else (echo done)