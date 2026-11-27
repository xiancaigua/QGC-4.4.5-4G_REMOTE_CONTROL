@echo off
setlocal
set "PATH=D:\ROS2Android\QGC_modification\build-QGC4.4.5-debug\staging;D:\Qt\5.15.2\msvc2019_64\bin;D:\gstreamer\1.0\msvc_x86_64\bin;%PATH%"
set "GST_PLUGIN_PATH=D:\ROS2Android\QGC_modification\build-QGC4.4.5-debug\staging\gstreamer-plugins"
set "QT_FORCE_STDERR_LOGGING=1"
cd /d D:\ROS2Android\QGC_modification\build-QGC4.4.5-debug\staging
QGroundControl.exe --unittest --no-windows-assert-ui > D:\ROS2Android\QGC_modification\build-QGC4.4.5-debug\unit-test.log 2>&1
