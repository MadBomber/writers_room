# frozen_string_literal: true

module WritersRoom
  class ReactTool < RobotLab::Tool
    REACTION_MUTEX = Mutex.new

    def name = "react"

    description "Add a brief reaction to another specialist's response. " \
                "Use only when you disagree, want to add a critical detail, " \
                "or catch something important. Keep reactions to 1-2 sentences."

    param :content, type: "string",
          desc: "Your brief reaction (1-2 sentences max)", required: true

    def execute(content:, **)
      robot.send_message(
        to: :responses,
        content: content
      )

      memory = robot.shared_memory
      if memory
        REACTION_MUTEX.synchronize do
          history = memory.get(:chat_history) || []
          history << {
            from: robot.name,
            content: content,
            type: :reaction,
            timestamp: Time.now.to_i
          }
          memory.set(:chat_history, history)
        end
      end

      "Reaction delivered."
    end
  end
end
