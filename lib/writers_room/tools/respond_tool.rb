# frozen_string_literal: true

module WritersRoom
  class RespondTool < RobotLab::Tool
    RESPONSE_MUTEX = Mutex.new

    def name = "respond"

    description "Deliver your response to the user's question. " \
                "Use this tool every time you want to answer — " \
                "your response will be shown to the user with your specialist label."

    param :content, type: "string",
          desc: "Your full response to the user (markdown supported)", required: true

    def execute(content:, **)
      robot.responded = true

      robot.instance_variable_get(:@logger)&.info(
        "TOOL[respond]: #{robot.name} publishing response (#{content.length} chars)"
      )

      robot.send_message(
        to: :responses,
        content: content
      )

      memory = robot.shared_memory
      if memory
        RESPONSE_MUTEX.synchronize do
          history = memory.get(:chat_history) || []
          history << {
            from: robot.name,
            content: content,
            type: :response,
            timestamp: Time.now.to_i
          }
          memory.set(:chat_history, history)
        end
      end

      "Response delivered."
    end
  end
end
