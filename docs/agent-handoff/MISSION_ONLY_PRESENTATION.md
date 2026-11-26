# QGC 4.4.5 航线任务架构与汇报材料

本版只讨论航线任务。所绘的 Plan View、MissionController、任务同步、Fly View 任务执行入口都是 QGC 4.4.5 原生功能；当前功能分支没有修改这些模块。图中的规划增强项均标为待开发。本项目已完成 QGC 源码编译与航线任务源码链路梳理；本材料不把原生航线功能记作新增代码。

## 可直接讲述的文本

本项目选择 QGroundControl 4.4.5 作为地面站基础平台。我对航线任务链路做了源码级分析：用户在 Plan View 中建立航点或区域任务，PlanMasterController 统一管理任务、地理围栏和集结点，MissionController 维护可视化任务项及航线数据。保存到本地时，规划数据由控制器序列化；上传至飞机时，MissionManager 和底层 PlanManager 通过 MAVLink Mission 协议与飞控同步，并处理进度、确认及超时错误。任务上传后，Fly View 使用 QGC 原有的任务入口展示和触发任务，飞控回传当前任务项与执行状态。

这次分析的工作重点是把界面、数据模型、传输协议和飞控执行分清楚，确定二次开发的插入点与验证边界。现阶段航线模块保留 QGC 原有实现，未声称重写航线规划算法或任务上传协议。下一阶段若要形成独立的航线功能增量，可以开发任务模板、飞前规则校验、上传结果核对、执行过程记录和任务中断恢复策略；这些增强需要分别实现、编译，并在 PX4 1.13.3 SITL 中验证。

## 图一：航线任务软件分层架构

灰色为 QGC/PX4 原生能力；黄色为待开发的航线增强模块。

```mermaid
flowchart LR
    subgraph UI["规划与执行界面｜QGC 原生"]
        PLAN["Plan View<br/>航点、Survey、Corridor 等编辑"]
        FLY["Fly View<br/>任务状态与启动入口"]
    end
    subgraph MODEL["规划数据层｜QGC 原生"]
        MASTER["PlanMasterController<br/>统一协调"]
        MISSION["MissionController<br/>任务项与航线数据"]
        FENCE["GeoFenceController<br/>地理围栏"]
        RALLY["RallyPointController<br/>集结点"]
        FILE["Plan 文件<br/>本地保存与载入"]
    end
    subgraph TRANSPORT["任务同步层｜QGC 原生"]
        MM["MissionManager / PlanManager<br/>上传、下载、进度、错误处理"]
        PROTO["MAVLink Mission 协议"]
    end
    subgraph FC["PX4 1.13.3｜原生"]
        STORE["机载任务存储"]
        EXEC["Mission 执行与状态回传"]
    end
    PLAN --> MASTER
    MASTER --> MISSION
    MASTER --> FENCE
    MASTER --> RALLY
    MASTER <--> FILE
    MISSION --> MM --> PROTO --> STORE --> EXEC --> FLY
    TEMPLATE["任务模板<br/>待开发"] -.-> PLAN
    VALIDATE["飞前航线规则校验<br/>待开发"] -.-> MISSION
    AUDIT["上传核对与执行记录<br/>待开发"] -.-> MM
    classDef native fill:#e9ecef,stroke:#65727e,color:#17212b;
    classDef planned fill:#fff0cf,stroke:#b7791f,color:#392500;
    class PLAN,FLY,MASTER,MISSION,FENCE,RALLY,FILE,MM,PROTO,STORE,EXEC native;
    class TEMPLATE,VALIDATE,AUDIT planned;
```

## 图二：航线规划与上传业务流程

```mermaid
flowchart TD
    START["进入 Plan View"] --> EDIT["创建或编辑航点、区域任务"]
    EDIT --> MODEL["MissionController 更新可视化任务项"]
    MODEL --> LOCAL{"保存到本地？"}
    LOCAL -- 是 --> SAVE["PlanMasterController 保存 Plan 文件"] --> REVIEW
    LOCAL -- 否 --> REVIEW["检查任务内容与目标飞机类型"]
    REVIEW --> CONNECT{"飞机已连接且可同步？"}
    CONNECT -- 否 --> EDIT
    CONNECT -- 是 --> SEND["PlanMasterController.sendToVehicle()"]
    SEND --> MM["MissionManager / PlanManager 执行同步"]
    MM --> ACK{"飞控确认成功？"}
    ACK -- 否 --> ERR["显示错误或重试状态"] --> EDIT
    ACK -- 是 --> READY["机载任务就绪"]
    READY --> FLY["Fly View 显示任务信息"]
```

上图是 QGC 原生流程的简化表达；“检查任务内容”表示现有上传前检查，不代表本项目新增了独立的规则引擎。

## 图三：MAVLink 航线上传时序

```mermaid
sequenceDiagram
    actor User as 操作员
    participant UI as Plan View
    participant Ctrl as PlanMasterController / MissionController
    participant PM as MissionManager / PlanManager
    participant PX4 as PX4 Mission 存储
    User->>UI: 点击 Upload
    UI->>Ctrl: 执行上传前检查
    Ctrl->>PM: sendToVehicle / writeMissionItems
    PM->>PX4: MISSION_COUNT
    loop 按序请求任务项
        PX4-->>PM: MISSION_REQUEST 或 MISSION_REQUEST_INT
        PM->>PX4: MISSION_ITEM 或 MISSION_ITEM_INT
    end
    PX4-->>PM: MISSION_ACK
    PM-->>UI: 上传结果、进度或错误
```

## 图四：任务执行与状态监控逻辑

```mermaid
stateDiagram-v2
    [*] --> 草稿
    草稿 --> 本地已保存: 保存 Plan 文件
    草稿 --> 上传中: 上传到飞机
    本地已保存 --> 上传中: 连接后上传
    上传中 --> 机载就绪: 飞控确认成功
    上传中 --> 草稿: 上传失败后修订
    机载就绪 --> 执行中: 操作员启动任务
    执行中 --> 暂停: 执行暂停
    暂停 --> 执行中: 操作员继续
    执行中 --> 完成: 飞控报告任务完成
    执行中 --> 返航: 飞控进入 Return
    返航 --> 完成: 返航流程结束
    完成 --> [*]
```

该状态图用于解释任务生命周期，不等同于 PX4 内部状态机的逐项代码实现；失联返航参数未在真实飞控上配置或测试。

## 源码核对位置

- `src/PlanView/PlanView.qml`：规划界面、上传前检查、本地保存与下载入口。
- `src/MissionManager/PlanMasterController.cc`：任务、地理围栏、集结点的协调，以及文件保存和飞机同步。
- `src/MissionManager/MissionController.cc`：任务项模型与航线数据处理。
- `src/MissionManager/PlanManager.cc`：MAVLink Mission 消息、超时与确认处理。
- `src/FlightDisplay/GuidedActionsController.qml`：Fly View 的任务启动与状态条件。

本材料只完成源码核对与说明整理；没有执行新的航线任务上传、PX4 SITL 或真实飞机测试。
