@echo off
setlocal
set "STAGING=D:\ROS2Android\QGC_modification\build-QGC4.4.5\staging"
if not exist "%STAGING%\QGroundControl.exe" (
    echo QGroundControl.exe not found. Run build-QGC4.4.5.cmd first.
    exit /b 1
)
set "PATH=%STAGING%;D:\gstreamer\1.0\msvc_x86_64\bin;%PATH%"
set "GST_PLUGIN_PATH=%STAGING%\gstreamer-plugins"
start "" /D "%STAGING%" "%STAGING%\QGroundControl.exe"
exit /b 0
