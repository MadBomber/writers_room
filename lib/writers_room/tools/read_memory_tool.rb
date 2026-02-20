# frozen_string_literal: true

require "json"

module WritersRoom
  class ReadMemoryTool < RobotLab::Tool
    description "Read a value from shared scene memory. " \
                "Use to check dialog history, scene state, or notes from other characters."

    param :key, type: "string",
          desc: "Memory key to read (e.g. dialog_history, scene_state, notes)", required: true

    def execute(key:)
      memory = robot.shared_memory
      return "No shared memory available." unless memory

      value = memory.get(key.to_sym)
      if value.nil?
        "Key '#{key}' is not set yet."
      elsif value.is_a?(Array) || value.is_a?(Hash)
        JSON.pretty_generate(value)
      else
        value.to_s
      end
    end
  end
end
