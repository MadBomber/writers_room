# frozen_string_literal: true

module WritersRoom
  class SpeakTool < RobotLab::Tool
    DIALOG_MUTEX = Mutex.new

    description "Speak dialog to the scene. All other characters will hear you. " \
                "Use this to say your line in character."

    param :dialog, type: "string",
          desc: "The dialog to speak (in character, no quotes or name prefix)", required: true
    param :emotion, type: "string",
          desc: "Emotional tone (e.g. excited, nervous, sarcastic)", required: false

    def execute(dialog:, emotion: nil)
      robot.send_message(
        to: :scene,
        content: dialog
      )

      # Record in shared memory (mutex protects read-modify-write)
      memory = robot.shared_memory
      if memory
        DIALOG_MUTEX.synchronize do
          history = memory.get(:dialog_history) || []
          history << {
            from: robot.name,
            content: dialog,
            emotion: emotion,
            timestamp: Time.now.to_i
          }
          memory.set(:dialog_history, history)
        end
      end

      robot.display&.dialog(robot.name, dialog, emotion: emotion)
      "You said: #{dialog}"
    end
  end
end
