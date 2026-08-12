# swarm_uav_interfaces

Group A 地面站与单机执行器共同依赖的纯 ROS `msg/srv` 契约包。本包不包含业务节点、桥接逻辑或飞控控制权。

## 契约

- 唯一任务键：`(mission_id, command_id, uav_id)`。
- `UavTask.accepted=true` 仅表示机载执行器已校验、登记并接管动作入口，不表示动作完成。
- 终态由 `UavTaskState` 发布；主状态为 `ACCEPTED`、`COMPLETED`、`FAILED`。
- 同一任务键内 `status_seq` 严格单调递增。
- `UavHold` 是独立高优先级安全入口。
- 所有参与 GCS、bridge 和 UAV 的主机必须安装并 source 同一版本的本包。

## 接口

- `Pose3DYaw.msg`：位置与 yaw；坐标系和单位由部署配置冻结，消息不做隐式换算。
- `TaskAssignment.msg`：单机任务分配；首版仅使用 `target_pose` 完成 `MOVE_TO`。
- `UavTaskState.msg`：机载接受与终态反馈。
- `UavLinkHealth.msg`：GCS_A 发布的逐机端到端链路健康事件与快照；状态为 `DISCOVERED`、`HEALTHY`、`SUSPECT`、`LOST`、`RECOVERED`。
- `UavTask.srv`：非阻塞单机任务接收入口。
- `UavTaskControl.srv`：对已登记任务执行 `START` 或 `ABORT`；用于整组启动屏障，不直接暴露给 TCP 上游。
- `UavHold.srv`：本机 HOLD 安全入口。
- `UavSafetyLease.srv`：GCS_A 对机载安全看门狗执行 `START`、`RENEW`、`END` 的单一租约入口。

## 飞行安全租约

- 飞行会话由 `mission_id + session_epoch` 唯一标识，`session_epoch` 使用字符串 UUID。
- 同一 epoch 内 `lease_seq` 严格递增；完全相同的 START/RENEW 重试保持幂等。
- 旧 epoch、倒退序号以及相同序号但内容不同的请求必须拒绝，避免迟到请求错误续命。
- 合法 RENEW 一经机载接收即完成续期；响应链路丢失不得回滚已应用的租约。
- 租约过期后的 HOLD 为锁存安全状态，恢复通信不代表恢复旧任务。
- 所有参与节点必须同步升级本接口包；不得单独修改已部署接口的字段顺序或类型。

首版机载执行只支持 `MOVE_TO` 和 `HOLD`。`formation_follow`、`target_id` 与 `waypoints` 为后续能力保留，不代表首版已实现。

## 构建与检查

```bash
source /opt/ros/noetic/setup.bash
catkin build swarm_uav_interfaces
source /home/ub20tg/catkin_swarm6-2/devel/setup.bash
rosmsg show swarm_uav_interfaces/UavTaskState
rosmsg show swarm_uav_interfaces/UavLinkHealth
rossrv show swarm_uav_interfaces/UavTask
rossrv show swarm_uav_interfaces/UavHold
rossrv show swarm_uav_interfaces/UavSafetyLease
```

工作空间只使用 `catkin build`。不要直接修改 `build/`、`devel/` 或 `logs/`。
