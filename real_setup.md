# Group A 实机部署与运行说明（real_setup）

> 适用：Group A 侦查集群实机部署（GCS_A 地面站 + 机载电脑 UAV1–UAV16）。
> 依据：`implementation_plan_26091101.md`（实机多主部署适配，已实施）。
> 与仿真流程的区别：**入口、身份、topology 全部切换为实机版本**；仿真 15 机流程不受影响。
> 实机飞行前必须完成现场门禁（不上桨验证 → 上桨）。本说明不替代现场安全评审。

---

## 1. 部署拓扑与地址/端口

```text
上位机 / 任务 runtime ── TCP JSON Lines :39001 ──▶ GCS_A (192.168.5.241)
                                                     │ ZeroMQ over LAN
                    ┌──────────────┬──────────────┬──┴───────────┐
                 UAV1(.11)      UAV2(.21)  ...  UAV15(.151)   UAV16(.161，备用)
```

- 地址约定（现场逐机核对）：
  - `UAVn = 192.168.5.(10*n+1)`：UAV1=`192.168.5.11`、UAV12=`192.168.5.121`、UAV16=`192.168.5.161`
  - `GCS_A = 192.168.5.241`
- 端口（跨机 TCP，按此放行防火墙）：

| 用途 | 端口 | 说明 |
|---|---|---|
| bridge topic（每台机） | `4200 + idx`（idx=0..10） | 生产 topology 共 11 个 topic；`base_port=4200`（冻结） |
| bridge service（每台机） | `14000` | `service_base_port=14000`（冻结） |
| GCS_A TCP server | `39001` | 仅 GCS_A 对上位机/runtime；监听 `0.0.0.0` |
| 本机 ROS Master | `11311` | 每台机各自本地 Master，不跨机 |

- **身份边界（不可混用）**：
  - 任务层 `Axx` 只出现在 GCS_A 的 `tcp_to_ros`（`config/uav_identity_map.yaml` 映射到执行层）。
  - 机载 ROS 运行时统一使用执行层 `UAVn`（`uav_id`、`exec_target`、hostname、topic/service 路径）。
  - **不得**为机载包/bridge/ROS 接口新增 Axx 反向映射。

## 2. 前置条件

1. 操作系统与 ROS：Ubuntu 20.04 + ROS Noetic（全部机器一致）。
2. ROS 包：
   - 地面站：`ros-noetic-mavros`（含 `px4.launch`）、`ros-noetic-mavros-msgs`、`ros-noetic-geographic-msgs`、
     `python3-zmq`、`python3-yaml`、`python3-rospkg`、`ros-noetic-actionlib`。
   - 机载：同上（机载也必须安装 MAVROS 与 `python3-zmq`）。
3. 主机名（**部署环境条件，已实机验证**）：
   - 每台机载电脑 `hostname` 固定为 `UAVn`（如 `UAV3`），GCS_A 主机 `hostname=GCS_A`。
   - bridge 用 hostname 判定本机身份；无法唯一匹配 `config/topology.yaml` 节点时启动失败。
4. 网络：所有机器同一网段可互通；建议 NTP/时钟同步（机间 intent 时间戳依赖 GPS bias 修正，
   但系统时钟漂移仍会影响日志对齐）。
5. 飞控侧（现场设置，不属于本工作区代码）：
   - 无 RC 触发的意外保护按现场策略配置；`arm/OFFBOARD` 由遥控器执行。
   - 参数：`COM_RCL_EXCEPT=4`、`NAV_RCL_ACT=0`（与仿真一致的无 RC 策略，现场按实际 RC 情况复核）。
6. 上位机/runtime：由 runtime 负责人部署（本工作区 `references/runtime` 仅供联调与协议核对）。

## 3. 代码部署

### 3.1 包清单

| 机器 | 部署包 |
|---|---|
| GCS_A 地面站 | `swarm_uav_interfaces`、`swarm_topology_bridge`、`tcp_to_ros`、（runtime 对接程序） |
| 每台机载电脑 | `swarm_uav_interfaces`、`swarm_topology_bridge`、`swarm_uav_executor`、`ego_planner_driver`、MAVROS |

> `swarm_simulation` 仅仿真使用，实机不部署，也不启动任何 Gazebo/PX4 SITL。

### 3.2 获取与构建（每台机器）

```bash
mkdir -p ~/catkin_swarm6-2/src && cd ~/catkin_swarm6-2
# 将对应仓库放入 src/（机载 4 包 + 地面站 3 包）
source /opt/ros/noetic/setup.bash
catkin build
source devel/setup.bash
```

- 地面站：`catkin build swarm_uav_interfaces swarm_topology_bridge tcp_to_ros`
- 机载：`catkin build swarm_uav_interfaces swarm_topology_bridge swarm_uav_executor ego_planner_driver`
- 校验（可选）：`rostopic list`、`rosmsg show swarm_uav_interfaces/UavTaskState`

### 3.3 环境变量（每台机器）

```bash
export ROS_HOME=$HOME/catkin_swarm6-2/.ros_home
export ROS_LOG_DIR=$HOME/catkin_swarm6-2/.ros_home/log
mkdir -p "$ROS_LOG_DIR"
```

- `ROS_MASTER_URI` / `ROS_IP` / `ROS_HOSTNAME` 使用系统安装后的默认值（本机 Master `11311`）；
  **实机不要**按仿真方式设置 `11310` / `11311–11325`。
- 所有 ROS 日志与临时文件写入工作区 `.ros_home` / `.tmp`，不使用 `/tmp`。

## 4. 配置冻结（部署前逐项核对）

| 文件 | 关键内容 |
|---|---|
| `tcp_to_ros/config/uav_identity_map.yaml` | `A01..A16 → UAV1..UAV16`，`hostname`、`ip` 与现场一致（A16 为备用机） |
| `tcp_to_ros/config/calibration_defaults.yaml` | `calibration_uavs`（默认 UAV1–UAV6，参与原点/航向冻结）、`all_uavs`（默认 UAV1–UAV16，仅确认记账） |
| `swarm_topology_bridge/config/topology.yaml` | `GCS_A` + `UAV1..UAV16` 物理 IP；所有节点 `port_offset: 0`；`base_port: 4200`、`service_base_port: 14000`；生产 topic/service 与接收矩阵 |
| 机载 MAVROS launch（`/opt/ros/noetic/share/mavros/launch/px4.launch`，现场 `px4_multi.launch`） | 现场按机配置 `fcu_url`、`tgt_system`（实测 UAV6：`udp://:15500@`、`6`）；本工作区机载入口 `uav_offboard_ego_real.launch` **不传**这两个参数 |
| 防火墙 | 放行 `4200–4211`（每机 topic）、`14000`（service）、GCS_A `39001`（对上位机） |

启动校验（失败即拒绝启动，fail-closed）：

- `calibration_uavs` / `all_uavs` 非空、无重复，且 `calibration_uavs ⊆ all_uavs`；
- 每个配置的 UAVn 在身份映射中存在且 `enabled: true`；
- UAVn 无重复、`exec_target` 非空且唯一。

## 5. 启动

### 5.1 机载电脑（每台，只启动本机）

推荐（systemd，开机自启、失败重启）：

```bash
# 首次安装（见 src/swarm_uav_executor/services/README.md）
sudo cp ~/catkin_swarm6-2/src/swarm_uav_executor/services/swarm-uav-onboard.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable swarm-uav-onboard.service
# FCU 连接无需传参：现场已在 MAVROS launch 中配置 fcu_url / tgt_system
sudo systemctl start swarm-uav-onboard.service
systemctl status swarm-uav-onboard.service
```

手动/调试等价方式：

```bash
roslaunch swarm_uav_executor uav_offboard_ego_real.launch   # 不传 fcu_url
```

- `uav_name` 默认取本机 `hostname`（= `UAVn`），无需显式传入；
- `topology_config` 默认加载生产 `swarm_topology_bridge/config/topology.yaml`；
- `diagnostic_log_dir` 默认 `~/catkin_swarm6-2/runtime_logs/ego_planner`；
- **不传 `fcu_url` / `tgt_system`**：实机 FCU 链路以机载机 MAVROS launch 的现场配置为准（见 §4），
  本入口不再要求也不允许覆盖；
- **该入口不 arm、不 OFFBOARD、不起飞、不发送任务 START**（实机由遥控器操作）。

### 5.2 GCS_A 地面站

```bash
roslaunch tcp_to_ros gcs_a_real.launch
# = swarm_topology_bridge 实机 bridge（uav_name=GCS_A，加载生产 topology.yaml）
#   + gcs_a_calibration + gcs_a_backend + tcp_server_node（0.0.0.0:39001）
```

可选覆盖：`topology_config:=<path>`、`tcp_port:=39001`。

### 5.3 就绪检查

| 检查 | 命令（对应机器） | 期望 |
|---|---|---|
| 本机 ROS 节点 | 机载：`rosnode list` | `/mavros`、`/ego_planner_driver`、`/uav_executor_UAVn`、`/swarm_bridge`、`/gp_origin_receiver`、`/gps_bias_node`、`/pose_relay`、`/setpoint_relay` |
| MAVROS 连接 | 机载：`rostopic echo -n1 /mavros/state` | `connected: True`，`mode` 未 OFFBOARD（等待遥控） |
| 跨机 service | GCS_A：`rosservice list | grep uav_task` | 每个在线 `UAVn` 的 `/UAVn/uav_task(_control)`、`/UAVn/uav_hold` |
| 跨机 topic | GCS_A：`rostopic echo -n1 /UAV1/uav_task_state` | 有数据（在线机） |
| 标定参数 | GCS_A：`rosparam get /group_a/calibration_ready` | 标定完成后 `True` |
| 逐机 ready | GCS_A 日志（`gcs_a_calibration`） | 输出计算集合、航向门限、逐机已确认/未确认清单 |

> 缺席/未上电 UAV 不阻塞 ready：ready 只要求 `calibration_uavs` 在线且满足采样条件。
> 原点发布后持续广播，后续上电的 UAV 自动接收原点并完成回读确认。

## 6. 运行流程（每轮任务）

1. **预检**：机载栈与 GCS_A 均已启动；重启后 `/group_a/calibration_ready=false`；**所有 UAV 处于 disarm**。
2. **标定（必须在 arm 之前）**：
   - `calibration_uavs` 各机 global/local pose 连续采样 2s、航向一致（≤30°）；
   - 冻结原点/参考航向并持续广播 `/group_a/gp_origin`；各机回读 `gp_origin_confirmed`；
   - GCS_A：`rostopic echo -n1 /group_a/calibration_ready` → `data: True`；日志给出逐机 ready 清单。
   - 缺席/未上电机不阻塞 ready；但**计算集合成员必须在线**。
3. **上桨 + 遥控 arm/OFFBOARD**：现场逐步执行（每机），确认 `/mavros/state` `armed: True`、`mode: OFFBOARD`。
4. **下发任务**：runtime 经 TCP `39001` 发批次命令（联调用 §10）。
5. **监控**：`/UAVn/uav_task_state`、`/group_a/group_task_state`；机载 `rosout` 关注 `MIN_DISTANCE_BREACH`、
   `direct BRAKE_HOLD locked`、`EGO_PLAN_FAILED`。
6. **收尾**：按现场规程返航/降落（遥控或地面站 RTL）；**不得就地重启单机/子集机载层**，
   需要重跑时先整机收口（停 service + 清端口）再整体重启。

## 7. 运行约束与安全边界

- 机载入口**不** arm、**不** OFFBOARD、**不**起飞、**不**发送任务 START；实机由遥控器完成 arm/OFFBOARD。
- 软件 HOLD/BRAKE_HOLD 不替代 PX4 datalink/offboard/RC failsafe。
- 组级安全语义：任一参与机进入安全终态（如 `MIN_DISTANCE_BREACH`）→ GCS_A 对同任务其余参与机
  fan-out `BRAKE_HOLD`（排除触发者/已终态/失联）；reserve 与缺席机不涉及。
- 不得修改安全门禁、不得减少 UAV 数量、不得用无界等待/旁路逻辑掩盖失败。
- A16 为备用/替换身份：映射与路由已就绪；**实机启用需上游 runtime roster/配置支持**（不属本工作区）。

## 8. 日志与证据

| 来源 | 位置 |
|---|---|
| 机载 ROS 日志 | `~/catkin_swarm6-2/.ros_home/log/<session>/`（rosout、各节点日志） |
| planner 诊断 | `~/catkin_swarm6-2/runtime_logs/ego_planner/UAVn-ego-planner.log` |
| GCS_A 日志 | `~/catkin_swarm6-2/.ros_home/log/<session>/`（bridge/backend/calibration/tcp_server） |
| 任务结果 JSON | `task_test.py` 输出（含 `status`/`failed_robot_ids`/`ticks`） |

多轮验收的留档命名见 `src/tcp_to_ros/test_records/README.md` §8（`.ros_home_round<n>_<s|f>`）。

## 9. 故障排查

| 现象 | 可能原因 | 处理 |
|---|---|---|
| bridge 启动即退出：`无法根据 hostname/IP 解析本机 UAV 名称` | hostname ≠ `UAVn`，或不在 `topology.yaml` | 修正 hostname 为 `UAVn`；或 launch 显式传 `uav_name:=UAVn` |
| 标定长期不 ready | `calibration_uavs` 成员未在线 / 已 armed / 采样不足 / 航向 > 30° | 查 `gcs_a_calibration` 逐机 ready 日志；确认计算集合成员全在线且 disarm、数据连续 2s |
| GCS_A `rosservice list` 无 `/UAVn/uav_task` | 该机 bridge/executor 未起；ZMQ 端口被占 | 检查该机进程；确认 `14000`、`4200–4211` 未被旧进程占用；核对防火墙 |
| `39001` 无监听 / 连接被拒 | tcp_server 未起，或残留进程占用 | `ss -ltnp \| grep 39001`；清理残留后重启 GCS_A 入口 |
| MAVROS 未 `connected` | 机载 MAVROS launch 的 `fcu_url` / `tgt_system` 与实际链路不符；串口权限 / 波特率 | 核对机载 MAVROS launch（`px4.launch`、现场 `px4_multi.launch`）的 `fcu_url`、`tgt_system` 与飞控一致；`ls -l /dev/ttyACM*`；用户加入 `dialout` 组 |
| 整组 FAILURE 且机载有 `MIN_DISTANCE_BREACH` | 真实安全事件（物理接近 → 组级 BRAKE_HOLD） | 属被测行为：保留机载 rosout/ulog 证据，整体收口后重来 |
| 上电顺序相关（后开机的机拿不到原点） | 正常：原点持续广播，机车自动重读 | 等其 ready 日志确认；不阻塞已 ready 机 |

## 10. 与 runtime / 上位机联调

```bash
# 在 GCS_A 或上位机（能连到 192.168.5.241:39001）
cd ~/catkin_swarm6-2
source /opt/ros/noetic/setup.bash && source devel/setup.bash
python3 references/runtime/task_test.py --backend tcp --group A --task prepare \
  --tcp-host 192.168.5.241 --tcp-port 39001 --timeout-s 180
```

- 线上协议：JSON Lines over TCP（见 `references/docs/实物无人机上下层TCP-IP接口对接方案.md`）。
- 实机 runtime 由上游负责人部署；本工作区仅提供 `tcp_to_ros` 服务端与上述联调脚本。

## 11. 命令速查

```bash
# —— 机载（每台，hostname=UAVn）——
sudo systemctl start|stop|status|enable|disable swarm-uav-onboard.service
# 或手动调试
roslaunch swarm_uav_executor uav_offboard_ego_real.launch   # 不传 fcu_url：现场配在 MAVROS launch
rosnode list
rostopic echo -n1 /mavros/state

# —— GCS_A（hostname=GCS_A）——
roslaunch tcp_to_ros gcs_a_real.launch
rostopic echo -n1 /group_a/calibration_ready
rosparam get /group_a/calibration_ready
rosservice list | grep uav_task
ss -ltnp | grep -E ':39001|:14000|:420[0-9]|:421[0-1]'

# —— 收口检查（确认无残留后再启动）——
ps -ef | grep -E '[m]avros|[b]ridge_node|[u]av_executor|[e]go_planner|[t]cp_server'
```

## 12. 关联文档

- `src/tcp_to_ros/README.md`、`CONTEXT.md`：GCS_A 流程、校准集合、身份边界。
- `src/swarm_topology_bridge/README.md`：生产 topology、实机 bridge 入口、端口。
- `src/swarm_uav_executor/README.md`、`services/README.md`：机载实机入口与 systemd 自启。
- `src/tcp_to_ros/plans/implementation_plan_26091101.md`：本部署适配计划。
- `src/tcp_to_ros/test_records/test_record_26091103.md`、`test_record_26091114.md`：实施与 5 轮回归证据。



