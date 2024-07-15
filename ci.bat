@echo off

setlocal enabledelayedexpansion
if "%1" == "dcd" (

    cd dcd_templates/
    dub build --compiler=ldc2 -b release -c library
    dir .
    move dcd.lib ../server/dls/
) 

if "%1" == "dls" (

    ldmd2 -of=bin/dls.exe -O2 -L/OPT:REF -preview=rvaluerefparam -preview=bitfields -i -Iserver/ \
    server/cjson/cJSON.c server/dls/main.d server/dls/libdcd.lib
) 