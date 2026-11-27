# 4G 远控与载荷阶段文件清单

开发分支：`feature/4g-control-payload`。公开仓库的 `main` 与本地键盘分支各有独立交接提交；本阶段只上传开发分支，不覆盖 `main`。

| 文件 | 作用 |
| --- | --- |
| `AGENTS.md` | 新阶段交接与安全限制 |
| `.gitignore` | 忽略本地 MAVLink 捕获和 Python 缓存 |
| `src/FlightDisplay/KeyboardJoystickPanel.qml` | 输入流就绪时间和主链路保护 |
| `src/FlightDisplay/FlightControlSourcePanel.qml` | 人工控制源选择、飞控参数回读、失联保护只读检查 |
| `src/FlightDisplay/PayloadControlPanel.qml` | 舵机控制、配置值、ACK/超时 UI |
| `src/FlightDisplay/FlyView.qml` | 挂载三个独立面板 |
| `src/FlightDisplay/CMakeLists.txt` | 新面板文件清单 |
| `src/QmlControls/QGroundControl/FlightDisplay/qmldir` | QML 类型登记 |
| `qgroundcontrol.qrc` | QML 资源登记 |
| `src/FactSystem/ParameterManager.h/.cc` | QML 参数查询、刷新和实际 `PARAM_VALUE` 信号 |
| `src/Vehicle/Vehicle.h/.cc` | 舵机 MAVLink 命令封装、主链路可用性检查 |
| `tools/mavlink_control_mock.py` | 本地未解锁 MAVLink 测试端点，不是 PX4 SITL |
| `docs/PX4_1_16_REMOTE_CONTROL_SETUP.md` | 当前机体参数与 4G 失联保护说明 |
| `docs/PX4_1_16_PAYLOAD_ACTUATOR_SETUP.md` | 舵机 AUX/PWM 配置说明 |
| `docs/4G_REMOTE_CONTROL_TEST_REPORT.md` | 测试证据与未验证项目 |
| `docs/agent-handoff/REMOTE_CONTROL_2026_11_26.md` | 下一位 agent 的接续说明 |
| `docs/agent-handoff/README.md` | 原键盘阶段说明增加新阶段链接 |
| `tools/windows/*.cmd` | Windows Release、Debug 构建、启动和单元测试脚本；包含本机 D 盘路径，换机时需调整 |

本地构建与交付（不在 Git 中）：

- `D:\ROS2Android\QGC_modification\build-QGC4.4.5.cmd`：现有 Release 编译脚本。
- `D:\ROS2Android\QGC_modification\run-QGC4.4.5.cmd`：现有启动脚本。
- `D:\ROS2Android\QGC_modification\build-QGC4.4.5\staging\QGroundControl.exe`：本阶段可执行文件。
- `D:\ROS2Android\QGC_modification\build-QGC4.4.5\qmake.log`、`jom.log`、`startup.log`：本地构建与启动日志。
- `D:\ROS2Android\QGC_modification\delivery-QGC4.4.5\mavlink_control_mock_capture_initial.jsonl`：初轮模拟端点捕获。含大量中立摇杆样本，不应推送 GitHub。
