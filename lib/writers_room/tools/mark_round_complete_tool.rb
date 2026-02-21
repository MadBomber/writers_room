# frozen_string_literal: true

module WritersRoom
  class MarkRoundCompleteTool < RobotLab::Tool
    def name = "mark_round_complete"

    description "Signal that you have finished responding for this round. " \
                "Call this after using respond or react to indicate you are done."

    def execute(**)
      memory = robot.shared_memory
      return "No shared memory available." unless memory

      memory.set(:round_complete, true)
      "Round marked as complete."
    end
  end
end
