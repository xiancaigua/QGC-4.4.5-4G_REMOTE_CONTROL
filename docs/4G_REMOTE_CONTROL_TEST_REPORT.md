# QGC 4.4.5 远控与载荷开发测试记录

日期：2026-11-26。工作分支：`feature/4g-control-payload`。目标飞控：PX4 1.16.0。**本报告只记录已实际完成的测试；本地 MAVLink 模拟端点不是 PX4 SITL。**

## 构建与启动

| 项目 | 结果与证据 |
| --- | --- |
| 现有代码先编译 | 通过。旧 PCH 的 `APP_VERSION_STR` 与当前 Git 描述不一致，重建 PCH 后使用 Qt 5.15.2、MSVC v142、GStreamer 1.18.1、JOM 完成 Release 编译。日志在 D 盘独立构建目录。 |
| 键盘小改动独立编译 | 通过。 |
| 控制源面板独立编译 | 通过。 |
| 载荷面板独立编译 | 通过。 |
| 最终代码编译 | 通过：`D:\ROS2Android\QGC_modification\build-QGC4.4.5\staging\QGroundControl.exe`。JOM 退出码 0。 |
| QML 静态检查 | Qt `qmllint` 对三个面板退出码 0；`git diff --check` 通过。 |
| Windows 启动 | 通过。首轮运行发现缺少 `FlightDisplay/qmldir` 登记，已修复并重编。修复后主窗口显示 Fly View 三个独立面板，启动日志无这三个面板的 QML 类型错误。 |

## 本地模拟端点实际观察

测试端点 `tools/mavlink_control_mock.py` 仅绑定 `127.0.0.1:14560`，发送未解锁 PX4 风格心跳和模拟参数。先前本地键盘测试端点捕获了大量 `MANUAL_CONTROL` 中立值样本；新端点也曾观察到键盘 ON 后的连续中立样本。该证据只证明 QGC 发包，不证明 PX4 接受输入。

| 项目 | 结果 |
| --- | --- |
| 键盘面板默认关闭、三面板显示 | 已在 Windows Fly View 实际观察。 |
| 模拟 RC RSSI、参数显示 | 已观察：RC 80%、`COM_RC_IN_MODE=0`、`COM_DL_LOSS_T=10`、`NAV_DLL_ACT=2 (Return)`。这些值由本地模拟端点提供，不是当前飞机参数。 |
| RC 存在时选择 4G 的确认弹窗 | 已观察到明确提示 RC 在模式 1 下会被忽略。 |
| 4G 切换参数写入与回读 | **未通过端到端复测**。首次操作暴露弹窗焦点交付时序误判；已改为等待实际发送样本并重编。随后 Windows 自动化无法激活 QGC 窗口，尚无修复后 `PARAM_SET` / `PARAM_VALUE` 证据。 |
| Payload OPEN/CLOSE/自定义命令 | **未验证**。尚无来自面板的 `COMMAND_LONG(187)` 记录，也没有 ACK UI 复测。C++ 编译通过、源码参数检查通过不等于运行测试。 |
| 4G 失联自动 Return | **未验证**。面板是只读状态检查，不配置或执行失联动作。 |
| 当前版本全键位、实体游戏手柄互斥 | **未重新验证**。原键盘实现和之前的测试见 `docs/agent-handoff/TEST_REPORT.md`；本次主要增加发送就绪检查。 |

测试模拟端点缺少完整 PX4 参数、任务与传感器服务，QGC 曾弹出缺失参数提示；此现象不能推断真实 PX4 1.16.0 的行为。

## PX4 SITL 与台架

本机没有发现可直接运行的 PX4 1.16 SITL；`wsl --list` 报告 WSL 未安装。未安装新软件。RC→4G、4G→RC、双源同时有效、目标源无效、参数失败、断链期间切换、舵机未使用通道保持、各飞行模式 RTL、HyperLTE 与 G20 实际链路均 **未验证**。没有连接或测试真实飞机。

特别风险：`COM_RC_IN_MODE=1` 忽略 RC。4G 丢失后，直接连接的 SBUS/RC 不会自动接管，QGC 也无法在已断链时把参数写回 0。标准遥测没有当前 `manual_control_setpoint.data_source` 的直接反馈。此功能目前是地面试验原型，不应投入真实飞行。
源切换按钮已限制为未解锁状态；飞行中切换不在当前可用范围。

## 2026-11-27 本地复测

- 使用 `build-QGC4.4.5.cmd` 对当前工作树重新执行 Qt 5.15.2 / MSVC v142 / JOM Release 构建，退出码 0。使用独立 Debug 构建目录重新构建，退出码 0。
- `qmllint` 检查三个面板退出码均为 0；`tools/mavlink_control_mock.py` 的 Python 语法解析通过。
- Debug 版 `--unittest --no-windows-assert-ui` 全套运行**未通过**：日志位于 `D:\ROS2Android\QGC_modification\build-QGC4.4.5-debug\unit-test.log`。`FactSystemTestPX4`（6/6）、`SendMavCommandWithSignallingTest`（4/4）、`SendMavCommandWithHandlerTest`（5/5）、`RequestMessageTest`（5/5）通过。缓存、链路管理、FTP、任务及参数等测试出现失败；随后 `CameraSectionTest::_testScanForMultipleItems()` 在 `MissionCommandUIInfo::rawName()` 路径发生 `0xc0000005` 崩溃，全套运行退出码 1。不能据此认定这些失败是本次修改导致或是既有问题，需要独立基线复核。
- 图形桌面当时无法把 QGC 窗口置前并投递自动点击；因此未补得控制源 `PARAM_SET`/回读、舵机 `COMMAND_LONG(187)`/ACK 的新端到端证据。这两项仍为**未验证**。
- 未运行 PX4 1.16 SITL、HyperLTE、G20 或真实飞机测试。当前构建成功不代表控制权切换、失联返航或舵机实际输出安全可用。
