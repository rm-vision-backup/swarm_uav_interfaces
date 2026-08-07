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
- `UavTask.srv`：非阻塞单机任务接收入口。
- `UavHold.srv`：本机 HOLD 安全入口。

首版机载执行只支持 `MOVE_TO` 和 `HOLD`。`formation_follow`、`target_id` 与 `waypoints` 为后续能力保留，不代表首版已实现。

## 构建与检查

```bash
source /opt/ros/noetic/setup.bash
catkin build swarm_uav_interfaces
source /home/ub20tg/catkin_swarm6-2/devel/setup.bash
rosmsg show swarm_uav_interfaces/UavTaskState
rossrv show swarm_uav_interfaces/UavTask
rossrv show swarm_uav_interfaces/UavHold
```

工作空间只使用 `catkin build`。不要直接修改 `build/`、`devel/` 或 `logs/`。
