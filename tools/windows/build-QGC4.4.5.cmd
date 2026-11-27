@echo off
setlocal
set "SOURCE_DIR=D:\ROS2Android\QGC_modification\QGC4.4"
set "BUILD_DIR=D:\ROS2Android\QGC_modification\build-QGC4.4.5"
set "QT_BIN=D:\Qt\5.15.2\msvc2019_64\bin"
set "JOM=D:\Qt\Tools\jom\jom.exe"
set "GST_BIN=D:\gstreamer\1.0\msvc_x86_64\bin"

call "D:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 -vcvars_ver=14.29
if errorlevel 1 exit /b 1
set "PATH=%QT_BIN%;%GST_BIN%;%PATH%"
set "GSTREAMER_1_0_ROOT_MSVC_X86_64=D:\gstreamer\1.0\msvc_x86_64"

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if not exist "%BUILD_DIR%\tmp" mkdir "%BUILD_DIR%\tmp"
set "TEMP=%BUILD_DIR%\tmp"
set "TMP=%BUILD_DIR%\tmp"
cd /d "%BUILD_DIR%"
cl > toolchain.log 2>&1
"%QT_BIN%\qmake.exe" -v >> toolchain.log 2>&1
"%JOM%" /? >> toolchain.log 2>&1

"%QT_BIN%\qmake.exe" -r "%SOURCE_DIR%\qgroundcontrol.pro" CONFIG+=StableBuild CONFIG+=release > qmake.log 2>&1
if errorlevel 1 (
    echo qmake failed. See "%BUILD_DIR%\qmake.log"
    exit /b 1
)
echo qmake completed. See "%BUILD_DIR%\qmake.log"

"%JOM%" -j2 > jom.log 2>&1
if errorlevel 1 (
    echo JOM failed. See "%BUILD_DIR%\jom.log"
    exit /b 1
)
echo JOM completed. See "%BUILD_DIR%\jom.log"
exit /b 0
