# QGC 4.4.4 兼容性检查

- 独立工作树：`D:\ROS2Android\QGC_modification\QGC4.4.4-compat`，官方标签提交 `b809674075f9c12ee4830a5ca824308d249b7ae4`。
- 静态确认 4.4.4 的 `Vehicle.h` 含 `virtualTabletJoystickValue(double,double,double,double)`、`joystickEnabled`、`vehicleLinkManager` 属性，`VehicleLinkManager` 含 `communicationLost` 属性；`AppSettings` 含 `virtualJoystick`，Fly View 的 `zOrderTopMost`、QML 资源与模块注册布局相同。
- 4.4.4 与 4.4.5 的 `Vehicle::sendJoystickDataThreadSafe()` 内部 `mavlink_msg_manual_control_pack_chan` 参数个数不同，但面板只使用公共 `virtualTabletJoystickValue()`，不直接调用该内部函数。
- 面板位置约束仅使用 Qt 5.15 的 QML JavaScript 与 Item 尺寸属性，未引入 4.4.5 特有接口。此结论是源码接口检查，**没有将功能移植到 4.4.4 编译或运行**。
