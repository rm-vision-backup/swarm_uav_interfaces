string protocol_version
uint8 PHASE_UNKNOWN=0
uint8 PHASE_TENTATIVE=1
uint8 PHASE_ACTIVE=2
uint8 PHASE_BRAKING=3
uint8 phase                       # protocol 1.0 is always interpreted as ACTIVE
string uav_id
string exec_target
string frame_id
int32 traj_id
float64 stamp
float64[] t                       # strictly increasing seconds relative to stamp; t[0] == 0
geometry_msgs/Pose[] sampled_traj
float64 clearance                 # per-aircraft clearance radius in metres
