# frozen_string_literal: true

module WritersRoom
  class WriteMemoryTool < RobotLab::Tool
    description "Write a value to shared scene memory for all characters to see. " \
                "Use to store observations, notes, or scene state."

    param :key, type: "string",
          desc: "Memory key (e.g. scene_state, notes)", required: true
    param :value, type: "string",
          desc: "Content to store", required: true

    def execute(key:, value:)
      memory = robot.shared_memory
      return "No shared memory available." unless memory

      memory.set(key.to_sym, value)
      robot.display&.memory_write(robot.name, key)
      "Stored '#{key}' in shared memory."
    end
  end
end
