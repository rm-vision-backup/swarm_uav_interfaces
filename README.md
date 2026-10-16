# swarm_uav_interfaces

Group A 地面站与单机执行器共同依赖的纯 ROS `msg/srv` 契约包。本包不包含业务节点、桥接逻辑或飞控控制权。

> 实机部署与运行说明（机器/包清单、地址端口、构建、配置冻结、启动、运行流程、故障排查）见
> [`real_setup.md`](real_setup.md)。
> 日常上机按总工作区的 [实机测试工作流](../../verification/real_uav_workflow/README.md) 执行；本包文档用于查接口和部署细节。

## 契约

- 唯一任务键：`(mission_id, command_id, uav_id)`。
- `UavTask.accepted=true` 仅表示机载执行器已校验、登记并接管动作入口，不表示动作完成。
- 终态由 `UavTaskState` 发布；主状态为 `ACCEPTED`、`COMPLETED`、`FAILED`。
- 同一任务键内 `status_seq` 严格单调递增。
- `UavHold` 是独立高优先级安全入口。
- 所有参与 GCS、bridge 和 UAV 的主机必须安装并 source 同一版本的本包。

## 接口

- `Pose3DYaw.msg`：位置与 yaw；坐标系和单位由部署配置冻结，消息不做隐式换算。
- `TaskAssignment.msg`：单机任务分配，包含 `target_pose`、`waypoints`、`formation_follow`、`formation_offset`、`target_id` 等字段；按命令使用，具体支持范围由执行器决定。
- `UavTaskState.msg`：机载接受与终态反馈。
- `UavLinkHealth.msg`：GCS_A 发布的逐机端到端链路健康事件与快照；状态为 `DISCOVERED`、`HEALTHY`、`SUSPECT`、`LOST`、`RECOVERED`。
- `UavTask.srv`：非阻塞单机任务接收入口。
- `UavTaskControl.srv`：对已登记任务执行 `START` 或 `ABORT`；用于整组启动屏障，不直接暴露给 TCP 上游。
- `UavHold.srv`：本机 HOLD 安全入口。
- `UavSafetyLease.srv`：已废弃（dead definition）。原为 GCS_A 对机载安全看门狗执行 `START`、`RENEW`、`END` 的租约入口；safety-lease 机制按 implementation_plan_26081406 移除，运行时不启动该服务，保留 .srv 定义仅为兼容旧构建与历史消息。

## 飞行安全租约（已移除）

- safety-lease 层（机载 watchdog 与 GCS 协调器）已按 `implementation_plan_26081406.md` 整体移除。
- 断链安全改由 GCS_A 的 `link_health` 监测与 `safe_hold` 承担；机载 HOLD 服务保留为本机安全停止入口。
- 下方历史约束不再适用：`mission_id + session_epoch`、`lease_seq` 单调、幂等重试、过期锁存等均为旧机制语义。

机载执行支持 `MOVE_TO`、`FOLLOW_ROUTE`（leader EGO / follower PI+编队偏置）、`FAULT_EXIT` 与
`HOVER`；`formation_follow`、`target_id` 与 `waypoints` 语义见 `swarm_uav_executor/README.md`。

## 构建与检查

```bash
source /opt/ros/noetic/setup.bash
catkin build swarm_uav_interfaces
source "$HOME/catkin_swarm6-2/devel/setup.bash"
rosmsg show swarm_uav_interfaces/UavTaskState
rosmsg show swarm_uav_interfaces/UavLinkHealth
rossrv show swarm_uav_interfaces/UavTask
rossrv show swarm_uav_interfaces/UavHold
rossrv show swarm_uav_interfaces/UavSafetyLease  # dead definition, no longer served
```

工作空间只使用 `catkin build`。不要直接修改 `build/`、`devel/` 或 `logs/`。
