# PX4 1.16.0 PWM 舵机与载荷控制

QGC Payload Control Panel 使用现有 Vehicle 命令链路发送 `MAV_CMD_DO_SET_ACTUATOR`（187）。选择 Actuator Set 1 的 1–6 路之一，目标值限制为 `[-1,1]`，其他五路参数为 `NaN`，组索引 `param7=0`。PX4 1.16.0 的 FunctionActuatorSet 仅接受组索引 0，且只更新有限值的通道。MAVLink `COMMAND_ACK` 只能确认命令处理结果，不能证明舵机物理到位。

## 无桨台架配置步骤

1. 在当前机体的 QGC **Vehicle Setup → Actuators** 中核对电机输出映射，选取未分配给电机和关键控制面的空闲 AUX/PWM 输出。不要改动现有电机映射。
2. 将该空闲输出的 Function 设置为 **Peripheral via Actuator Set 1**（对应面板 Actuator 1）；更多舵机分别选 Set 2–6。核对同一定时器组内各通道的 PWM 更新频率要求，避免影响电机/ESC。
3. 舵机信号线接所选 PWM 信号脚，地线共地。使用符合舵机电流需求的独立或经核验的供电；不要假设飞控 PWM 信号针脚同时提供足够舵机电源。
4. 在 Actuators 中设置并核对 PWM 最小、最大、停止/失效输出和舵机方向。先断开桨叶，在低风险位置以小步幅试验；记录实测 OPEN 与 CLOSE 对应的归一化值，再填入面板。界面不预设 -1/+1。
5. 在 SITL 或无桨台架验证 OPEN、CLOSE、自定义位置、其他执行器保持、ACK、快速连点、4G/飞控断链后的行为。实际机械位置须人工观察或独立反馈传感器确认。

依据：[PX4 1.16 Generic Actuator Control](https://docs.px4.io/v1.16/en/payloads/generic_actuator_control)、[PX4 1.16 Actuator Configuration](https://docs.px4.io/v1.16/en/config/actuators)、[FunctionActuatorSet.hpp](https://github.com/PX4/PX4-Autopilot/blob/v1.16.0/src/lib/mixer_module/functions/FunctionActuatorSet.hpp)。
