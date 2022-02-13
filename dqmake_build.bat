
@echo off

echo build dqmake...
call odin build dqmake/dqmake.odin -out:build/dqmake.exe -o:speed -strict-style -vet && if "%1%"=="run" (echo run dqmake... && cd build && call dqmake.exe) else (echo done)