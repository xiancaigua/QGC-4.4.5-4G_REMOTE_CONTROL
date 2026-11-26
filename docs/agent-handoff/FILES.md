# 修改文件清单

相对于官方 `v4.4.5`：

| 路径（相对 `QGC4.4`） | 内容 |
| --- | --- |
| `src/FlightDisplay/KeyboardJoystickPanel.qml` | 键盘状态、25 Hz 轴值更新、安全停用、双摇杆面板及随视图尺寸约束的拖动坐标 |
| `src/FlightDisplay/FlyView.qml` | 将独立面板放入 Fly View，并在点击面板外时停控且透传原有点击 |
| `src/QmlControls/QGroundControl/FlightDisplay/qmldir` | 注册 QML 类型 |
| `qgroundcontrol.qrc` | 打包面板 QML 资源 |
| `src/FlightDisplay/CMakeLists.txt` | 将新 QML 加入 CMake 源文件清单 |

交付目录另有 `build-QGC4.4.5.cmd`、`build-QGC4.4.5-debug.cmd`、`run-QGC4.4.5.cmd`、`delivery-QGC4.4.5/mavlink_loopback.py`、`mavlink_loopback_capture_*.csv` 测试记录与文档。原有 `Vehicle`、`Joystick`、MAVLink 源码均未改动。
