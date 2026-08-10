cmake_minimum_required(VERSION 3.0.2)
project(swarm_uav_interfaces)

find_package(catkin REQUIRED COMPONENTS
  message_generation
  geometry_msgs
)

add_message_files(
  FILES
  Pose3DYaw.msg
  TaskAssignment.msg
  UavLinkHealth.msg
  UavTaskState.msg
  UavTrajectoryIntent.msg
)

add_service_files(
  FILES
  UavTask.srv
  UavHold.srv
  UavSafetyLease.srv
)

generate_messages(
  DEPENDENCIES geometry_msgs
)

catkin_package(
  CATKIN_DEPENDS geometry_msgs message_runtime
)
