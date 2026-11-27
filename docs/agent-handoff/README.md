# QGC 4.4.5 键盘模拟遥控器

2026-11-26 的 PX4 1.16.0 4G 控制源、失联状态与载荷面板开发见 [新阶段交接](REMOTE_CONTROL_2026_11_26.md) 和 [测试报告](../4G_REMOTE_CONTROL_TEST_REPORT.md)。以下内容记录原键盘功能阶段，分支与测试结论不能直接代表新阶段。

## 交付位置

- 完整源码：`D:\ROS2Android\QGC_modification\QGC4.4`，分支 `feature/keyboard-joystick`，基于官方 `v4.4.5`。
- 可执行程序与部署 DLL：`D:\ROS2Android\QGC_modification\build-QGC4.4.5\staging\QGroundControl.exe`。
- 编译脚本：`D:\ROS2Android\QGC_modification\build-QGC4.4.5.cmd`。
- Debug 测试构建脚本：`D:\ROS2Android\QGC_modification\build-QGC4.4.5-debug.cmd`。
- 启动脚本：`D:\ROS2Android\QGC_modification\run-QGC4.4.5.cmd`。
- 编译日志：`build-QGC4.4.5\toolchain.log`、`qmake.log`、`jom.log`。

## 环境与编译

编译脚本使用 Qt 5.15.2 MSVC2019 x64、VS 2026 的 MSVC v142（`-vcvars_ver=14.29`）、GStreamer 1.18.1 与 JOM。使用官方 `qgroundcontrol.pro`，配置为 `StableBuild`、`release`，所有构建输出在独立目录。运行：

```bat
D:\ROS2Android\QGC_modification\build-QGC4.4.5.cmd
D:\ROS2Android\QGC_modification\run-QGC4.4.5.cmd
```

本机缺少 NSIS。官方 CI 的 `CONFIG+=installer` 会调用固定的 `C:\Program Files (x86)\NSIS\makensis.exe`，因此当前构建不生成安装包；可执行程序及运行所需 DLL 已生成。没有安装或修改 Visual Studio、Qt、GStreamer、NSIS。

另有独立的 `build-QGC4.4.5-debug` 目录和 Debug 构建，用于 QGC 内建 PX4 Mock Link 测试；它不替代 Release 交付程序。

`delivery-QGC4.4.5/mavlink_loopback.py` 是仅监听 `127.0.0.1:14560` 的轻量 MAVLink 测试端点，向 QGC 默认 UDP 端口 14550 发送未解锁心跳，并将收到的 `MANUAL_CONTROL` 记录到同目录 CSV。它不是 PX4 SITL，不会模拟飞行或响应全部参数请求。

本机复现回环测试可先运行 `D:\ProgramData\anaconda3\python.exe -u D:\ROS2Android\QGC_modification\delivery-QGC4.4.5\mavlink_loopback.py`，再运行 QGC。脚本启动时会重新创建 `mavlink_loopback_capture.csv`；已有的安全测试记录保存在 `mavlink_loopback_capture_safety.csv`。

## 使用

打开 Fly View 右上方的 **Keyboard Joystick** 面板。点击 `+` 展开，拖动标题栏可移动。连接飞机后，确认实体游戏手柄和触屏虚拟摇杆均未启用，点击 **Enable**。面板获得键盘焦点后以 25 Hz 通过 QGC 现有 `Vehicle::virtualTabletJoystickValue()` 链路发送 `MANUAL_CONTROL`。点击 **Disable** 停止；点击面板外、切换视图、应用失焦、切换飞机、断开连接或打开全屏视频也会停止。

| Mode 2 摇杆 | 按键 | 作用 |
| --- | --- | --- |
| 左摇杆纵轴 | W / S | 油门连续增加 / 减少；松开保持 |
| 左摇杆横轴 | A / D | 左 / 右偏航；松开回中 |
| 右摇杆纵轴 | ↑ / ↓ | 前进 / 后退俯仰；松开回中 |
| 右摇杆横轴 | ← / → | 左 / 右横滚；松开回中 |

可同时按下多个键；相反方向同时按下时该轴为零。键盘自动重复事件不重复累计油门。**Sensitivity** 调整方向轴幅度（0.1–1.0），**Throttle speed** 调整每秒油门变化量（0.1–1.0）。控制默认关闭，启用时油门从 0 开始。面板无解锁、起飞、降落按钮。仅在 SITL 中验证后再考虑任何真实飞机使用。

已知测试问题：第二轮人工按键后曾观察到面板暂时不可见，切换 Plan 再返回未恢复；重启 QGC 后恢复。已加入随视图尺寸持续约束面板位置的修正。新版经人工拖动与展开收起、边缘拖动及 Plan/Fly 切换复测，面板保持可见；原触发条件仍未确定，见测试报告。此构建尚未在 PX4 SITL 或实体手柄上验证。

## 其他报告

- [测试报告](TEST_REPORT.md)
- [修改文件清单](FILES.md)
- [4.4.4 兼容性](COMPATIBILITY_4.4.4.md)
- [手柄优先与 4G 失联返航评估](INPUT_PRIORITY_AND_LINK_FAILSAFE_REVIEW.md)
- [航线任务汇报讲稿与架构图](MISSION_ONLY_PRESENTATION.md)
