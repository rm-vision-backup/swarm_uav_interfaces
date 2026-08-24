string protocol_version
string uav_id
string exec_target
string frame_id
int32 traj_id
float64 stamp
float64[] t                       # strictly increasing seconds relative to stamp; t[0] == 0
geometry_msgs/Pose[] sampled_traj
float64 clearance                 # per-aircraft clearance radius in metres
