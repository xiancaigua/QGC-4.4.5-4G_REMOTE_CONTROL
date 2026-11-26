# 手柄优先与 4G 失联返航评估

评估对象：当前 `feature/keyboard-joystick` 的 QGC 4.4.5 源码。2026-11-18 至 19 日仅检查源码、Windows 即插即用设备和官方 PX4/云卓资料；没有连接实际云卓遥控器或飞控，也没有修改飞控参数。用户补充：云卓 G20（Android）、当前经接收机 SBUS/RC 直连飞控、PX4 1.13.3，正在考虑增加 4G。

## 手柄优先：当前实现与可改进处

- `JoystickManager` 使用 SDL 检测 Windows 手柄插拔，选择 `activeJoystick`；车辆在其变化时读取该车辆保存的 `JoystickEnabled` 设置。之前已启用且已校准的手柄重新接入时，QGC 会恢复手柄输入。参见 `src/Joystick/JoystickManager.cc`、`src/Vehicle/Vehicle.cc`。
- 当前键盘面板的 `canControl` 在 `vehicle.joystickEnabled` 为真时变假，立即清除键位并停控；`Vehicle::virtualTabletJoystickValue()` 也拒绝在实体手柄启用时发送。因此已启用的实体手柄优先于键盘。
- 仅检测到一个新手柄，不等于其轴映射、校准和启用状态可信。当前 QGC 不会为未配置的新手柄自动打开控制，这是合理的安全边界；本机未发现可用于热插拔复测的手柄。
- 后续优化可在面板显示“已检测到手柄 / 已校准 / 已启用 / 当前控制源”，在已启用手柄接入时明确提示“键盘已让位”。若要求“只要插入便停止键盘”，可增加 `joystickManager.activeJoystick` 互斥门控，但需要定义未校准手柄接入时如何维持可用控制源，并用实物或仿真手柄验证。不要静默开启未校准手柄。

## 云卓遥控器的三条输入路径

1. 如果遥控器被运行 QGC 的系统识别为标准 SDL/HID 游戏手柄，使用 QGC 原生 Joystick 配置和输入链路即可。当前 Windows 版本可做此类检测。
2. 如果 QGC 运行在云卓遥控器的 Android 系统上，而摇杆通过厂商接口提供，应按具体型号使用云卓 RCSDK 或系统输入接口，做单独的 Android 构建与真机验证。当前 Windows 可执行文件不能直接运行在遥控器 Android 上，也不能据此断言各型号会暴露标准 HID 输入。
3. 如果云卓接收机把摇杆以 SBUS/RC 直接送进飞控，QGC 不需要再转发同一组摇杆值。由 PX4 选择和监控 RC 输入；QGC 主要显示输入状态，避免产生第二条相冲突的 `MANUAL_CONTROL` 输入。

## G20 加 4G 的可行路径

云卓 G20 官方 V2.0 手册列出地面遥控器 SIM 卡槽；所列 GR01/G12 RX 机载接收机则为 2.4/5.8 GHz，提供 SBUS、数传串口及 LAN 接口，未在该手册列出机载蜂窝网络能力。因此仅在 G20 插 SIM 卡不能推断飞机获得 4G 链路。需要确认实际接收机型号，并在机载侧另配可联网的 LTE/4G 模块或具备同等能力的机载设备。

推荐先做独立 4G 遥测/任务链路：保持现有 G20→接收机→SBUS→PX4 的手动控制路径；机载 4G 设备通过 MAVLink 连接 PX4，G20 Android 或 Windows QGC 经受控网络连接机载端。这样 G20 物理摇杆无需重新映射；4G 负责地面站遥测、任务与模式命令。需在 SITL/台架验证多 MAVLink 链路、心跳来源和失联行为。

若要把 G20 物理摇杆也改走 4G，需要 Android 版 QGC 或独立应用读取云卓 RCSDK 杆量，发送 MAVLink `MANUAL_CONTROL`；此时要重新设计与原 SBUS 的控制源切换。PX4 1.13 参数 `COM_RC_IN_MODE` 仅有 0=仅 RC、1=仅 Joystick、2=RC/Joystick 失效后回退、3=先到先用并保持、4=禁用输入，默认 3；该版本没有较新版本的明确 RC 优先枚举。4G 时延/抖动也需要测量，不应仅凭“有网络”就作为主手动控制链路。

## 4G 失联后中止任务并返航

返航决策必须在断线后仍能工作的机载侧执行。地面 QGC 发现断线时，通常已经无法可靠地向飞机发送 Return 命令。

- 对 PX4 1.13.3 的“地面站 MAVLink 数据链路丢失”，`COM_DL_LOSS_T` 是失联判定时间，`NAV_DLL_ACT=2` 是 Return。PX4 1.13 参数参考列出的 `NAV_DLL_ACT` 默认值为 0（Disabled），需要核对实际飞控值。QGC 4.4.5 的 PX4 Safety 页面已有 Data Link Loss Action 和 Timeout 控件，通常可在这里配置飞控参数，无须改 QGC 或 PX4 源码。PX4 v1.13 参数参考未列出新版的 `COM_DLL_EXCEPT`，不要把该参数当作 1.13.3 的必要配置。
- 当前接收机走独立 SBUS/RC，4G 断开与 RC 断开是不同事件，要分别配置和验证。PX4 v1.13 文档说明 RC 失联默认在 Mission 中被忽略；若还要求 SBUS 丢失时在 Mission 中返航，需单独检查 `COM_RCL_EXCEPT`、`COM_RC_LOSS_T`、`COM_RCL_ACT_T` 和 `NAV_RCL_ACT`。如果将来改为摇杆与遥测共用 MAVLink/4G，再核对两个失联动作是否一致。
- “4G 掉线”必须转化成飞控可见的失联。若机载伴随计算机或云端转发仍向飞控提供看似健康的 GCS 心跳，PX4 自带 Data Link Loss 可能不会触发。需要检查具体心跳拓扑，并在机载网关/伴随计算机实现带超时的链路健康报告，或选择飞控可识别的独立失联输入。仅修改地面 QGC 无法保证这一场景返航。
- 若原有 G20 2.4/5.8 GHz 数传也持续向飞控送地面站心跳，那么新增的 4G 路径单独中断时，不能预期 PX4 的通用 Data Link Loss 一定触发。应先明确目标是“所有地面站链路断开返航”，还是“4G 单独断开即返航”；后者通常需要机载侧单独监测 4G 健康状态。
- Return 会离开正在执行的 Mission；还需核对返航高度、Home 位置、定位状态，以及断线恢复后的任务恢复策略。不能只根据 QGC 显示“Communication Lost”推断飞控一定进入 Return。

## 验证边界与下一步

本次未修改控制代码或飞控参数。仍需确认机载接收机型号、是否已有机载 LTE/伴随计算机、G20 Android 与 Windows 哪端作为 4G 地面站，才能落实 4G 路由与失联检测。建议先在 PX4 1.13.3 SITL 中执行 Mission 时切断对应 MAVLink/GCS 心跳，验证飞控实际切换 Return、任务停止和恢复行为；实体手柄的热插拔与控制源切换需在台架上验证，不进行真实飞行测试。

## 参考

- PX4 v1.13 Safety：<https://docs.px4.io/v1.13/en/config/safety>
- PX4 v1.13 参数参考：<https://docs.px4.io/v1.13/en/advanced_config/parameter_reference>
- PX4 Integrated GCS：<https://docs.px4.io/main/en/config/integrated_gcs>
- 云卓 G20 官方 V2.0 手册：<https://cdn.shopify.com/s/files/1/1032/6815/5473/files/G20-Instructions-E_babe0188-a1dc-48a4-a85b-5ec67624a2da.pdf?v=1790560173>
- 云卓 RCSDK 示例：<https://gitee.com/skydroid/rcsdk-demo/blob/master/README.md>
