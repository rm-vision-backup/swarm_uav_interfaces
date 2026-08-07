cmake_minimum_required(VERSION 3.0.2)
project(swarm_uav_interfaces)

find_package(catkin REQUIRED COMPONENTS
  message_generation
)

add_message_files(
  FILES
  Pose3DYaw.msg
  TaskAssignment.msg
  UavTaskState.msg
)

add_service_files(
  FILES
  UavTask.srv
  UavHold.srv
)

generate_messages()

catkin_package(
  CATKIN_DEPENDS message_runtime
)
