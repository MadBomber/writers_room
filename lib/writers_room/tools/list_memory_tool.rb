# frozen_string_literal: true

module WritersRoom
  class ListMemoryTool < RobotLab::Tool
    def name = "list_memory"

    description "List all keys currently in shared scene memory. " \
                "Use to see what information is available."

    def execute(**)
      memory = robot.shared_memory
      return "No shared memory available." unless memory

      keys = memory.keys
      if keys.empty?
        "Shared memory is empty."
      else
        "Keys in shared memory: #{keys.join(', ')}"
      end
    end
  end
end
