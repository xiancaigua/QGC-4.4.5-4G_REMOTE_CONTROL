# Agent handoff: 4G remote control / payload

分支 `feature/4g-control-payload`，基于已有 `feature/keyboard-joystick`。GitHub 用户远端为 `https://github.com/xiancaigua/QGC-4.4.5-4G_REMOTE_CONTROL.git`；用户于 2026-11-27 授权本地测试后上传开发分支。公开仓库 `main` 与本地分支已分叉，上传时不覆盖 `main`。保留原有修改、所有交付放 D 盘、不要改 PX4 固件或真实飞控失效保护参数。

## 改动位置

- `src/FlightDisplay/KeyboardJoystickPanel.qml`：增加最近发送时间、切换准备、主链路就绪检查；仍发送 `MANUAL_CONTROL`，不是 Offboard。
- `src/FlightDisplay/FlightControlSourcePanel.qml`：人工选择 `COM_RC_IN_MODE=0/1`、真实 `PARAM_VALUE` 回读、模拟 RC RSSI 和键盘流检查、只读 4G 失联参数状态。参数回读后明确显示实际控制源未被遥测验证。
- `src/FlightDisplay/PayloadControlPanel.qml`：选择 Actuator Set 1 的 1–6 路、可编辑 OPEN/CLOSE/自定义值、ACK/超时提示、连点节流。
- `src/Vehicle/Vehicle.cc/.h`：`sendPayloadActuator` 封装 `MAV_CMD_DO_SET_ACTUATOR(187)`；仅指定一路，其他参数为 `NaN`，`param7=0`；`joystickLinkReady` 拒绝高延迟或失联主链路。
- `src/FactSystem/ParameterManager.cc/.h`：向 QML 暴露参数查询/刷新与真实 `PARAM_VALUE` 信号。
- `src/FlightDisplay/FlyView.qml`、`qgroundcontrol.qrc`、`src/QmlControls/QGroundControl/FlightDisplay/qmldir`、`src/FlightDisplay/CMakeLists.txt`：面板挂载和资源登记。
- `tools/mavlink_control_mock.py`：只监听本机的未解锁模拟端点；**不是 SITL**。

## 构建与验证

运行 `D:\ROS2Android\QGC_modification\build-QGC4.4.5.cmd`，产物 `D:\ROS2Android\QGC_modification\build-QGC4.4.5\staging\QGroundControl.exe`。Release 和 Debug 编译通过；先前启动显示三面板。2026-11-27 全套 Debug 单元测试未通过并在相机测试中崩溃；详情见 `docs/4G_REMOTE_CONTROL_TEST_REPORT.md`。运行时 QGC 自动弹出的参数缺失是模拟端点不完整所致。

下一步优先级：1) 在可操作的 Windows 桌面上复测 4G 切换的 `PARAM_SET` 与回读，以及 OPEN/CLOSE 的 `COMMAND_LONG`、`COMMAND_ACK`；2) 运行真正 PX4 1.16 SITL 验证双源与失联动作；3) 当前机体无桨台架核对参数、HyperLTE 心跳来源、AUX 输出及舵机供电。没有这些证据，不得宣称已完成飞行控制交接或 4G 专用断链 RTL。

PX4 1.16 `COM_RC_IN_MODE=1` 禁用 RC，4G 断后无法通过已断的 QGC 链路主动切回 RC。不要把 RC 仍物理连接误认为可接管。若未来需要 4G 断开时 RC 接管，需重新设计并验证机载仲裁或飞控配置；不要在本分支中偷偷实现自动抢占。

参数说明：`docs/PX4_1_16_REMOTE_CONTROL_SETUP.md`。舵机硬件：`docs/PX4_1_16_PAYLOAD_ACTUATOR_SETUP.md`。本阶段测试：`docs/4G_REMOTE_CONTROL_TEST_REPORT.md`。
完整修改文件清单：`docs/4G_REMOTE_CONTROL_FILE_LIST.md`。
