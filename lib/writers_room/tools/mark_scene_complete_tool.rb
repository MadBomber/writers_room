# frozen_string_literal: true

module WritersRoom
  class MarkSceneCompleteTool < RobotLab::Tool
    description "Signal that the scene is done. " \
                "Only use when the scene has reached a natural conclusion " \
                "or the director has indicated it should end."

    def execute
      memory = robot.shared_memory
      return "No shared memory available." unless memory

      memory.set(:scene_complete, true)
      robot.display&.complete(robot.name)
      "Scene marked as complete."
    end
  end
end
