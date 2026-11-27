# PX4 1.16.0 控制源与失联保护配置

本文件针对 **PX4 1.16.0**。当前机体与先前机体不同，必须从当前飞控读取实际参数和输出映射。QGC 的 Flight Control Source 面板只写入用户明确选择的 `COM_RC_IN_MODE`；失联保护参数仅供查看。

## RC 与 MAVLink 摇杆

PX4 1.16.0 的 `COM_RC_IN_MODE`：`0` 仅 RC，`1` 仅 MAVLink joystick，`2` 两者可回退，`3` 选择首先有效的输入并保持到重启，`4` 禁用摇杆。参数元数据不要求重启，ManualControl 模块收到参数更新后在运行时刷新。0/1 切换会禁用另一来源，所以 **4G 模式丢失时，RC 虽仍通过无线电接入飞控，却不会自动接管**。若 QGC 与飞机失联，QGC 也不能再写参数切回 RC。此限制必须先在 PX4 SITL、再在无桨台架验证，并规划机载失联动作；当前实现不得用于真实飞行。

QGC 通过 `Vehicle::virtualTabletJoystickValue()` 送 `MANUAL_CONTROL`。面板切到 4G 前检查本机近期是否在发送，回读 `COM_RC_IN_MODE` 确认参数响应。标准 QGC 遥测不直接提供 PX4 当前实际使用的 `manual_control_setpoint.data_source`，因此参数回读 **不等于** 已验证的实际接管。RC RSSI 仅是信号代理指标，不能证明 RC 校准和飞控源有效。

当前 QGC 面板将控制源切换限制在**未解锁地面试验**。点击别的面板会使键盘失焦并停控；在完成真正的 PX4 SITL 双源切换和无桨台架交接测试前，不提供飞行中切换。

## 当前机体必须核对

在 QGC Vehicle Setup / Parameters 记录：

| 参数 | 检查目的 |
| --- | --- |
| `SER_TEL1_BAUD`、`MAV_0_CONFIG` | 与 HyperLTE 连接的 TELEM1 串口和 MAVLink 实例是否匹配 |
| `COM_RC_IN_MODE` | 当前人工控制来源 |
| `COM_DL_LOSS_T` | GCS 数据链路失联阈值，PX4 1.16 默认 10 秒 |
| `NAV_DLL_ACT` | GCS 失联动作，`2` 为 Return，PX4 1.16 默认 `0`（Disabled） |
| `COM_FAIL_ACT_T` | 失联到动作的延迟，PX4 1.16 默认 5 秒 |
| `COM_RC_LOSS_T`、`NAV_RCL_ACT` | 当前选中手动输入丢失的阈值与动作 |
| `COM_RCL_EXCEPT`、`COM_DLL_EXCEPT` | Mission/Hold/Offboard 例外位；若固件未提供则不能假定未屏蔽 |

不要直接套用另一机体的参数。由操作员在检查返航高度、定位、Home 点、航线模式和供电后，明确决定是否配置 `NAV_DLL_ACT=2`；本软件不会自动写入该值。

## 4G 专用断链的边界

PX4 原生 Data Link Loss 主要取决于它是否仍收到 GCS 心跳。如果 G20 或其他 MAVLink 链路仍向飞控提供 GCS 心跳，HyperLTE 单独断开不一定触发 `NAV_DLL_ACT`。QGC 只能观察自己与车辆的 MAVLink 连接，无法从该状态推断飞控端 HyperLTE 专用链路是否已断。应在 SITL/无桨台架分别测试：仅 4G 断开、仅 RC 断开、两者都断开、其他 GCS 心跳仍在，以及 Mission/Hold/Offboard 例外。

依据：[PX4 1.16 参数参考](https://docs.px4.io/v1.16/en/advanced_config/parameter_reference)、[PX4 1.16 安全配置](https://docs.px4.io/v1.16/en/config/safety)、[ManualControl.cpp](https://github.com/PX4/PX4-Autopilot/blob/v1.16.0/src/modules/manual_control/ManualControl.cpp)、[ManualControlSelector.cpp](https://github.com/PX4/PX4-Autopilot/blob/v1.16.0/src/modules/manual_control/ManualControlSelector.cpp)。
