# frozen_string_literal: true

module WritersRoom
  # Lightweight message payloads carried inside RobotMessage.content
  # These replace the old SmartMessage subclasses.

  DialogPayload = Data.define(:from, :content, :scene, :emotion, :addressing) do
    def initialize(from:, content:, scene:, emotion: nil, addressing: nil)
      super
    end
  end

  ControlPayload = Data.define(:command, :scene, :parameters) do
    def initialize(command:, scene:, parameters: {})
      super
    end

    def self.start_scene(scene)
      new(command: "start", scene: scene)
    end

    def self.stop_scene(scene)
      new(command: "stop", scene: scene)
    end
  end

  StageDirectionPayload = Data.define(:character, :action, :scene, :beat) do
    def initialize(character:, action:, scene:, beat: nil)
      super
    end
  end

  MetaPayload = Data.define(:message_type, :content, :scene, :source) do
    def initialize(message_type:, content:, scene:, source: nil)
      super
    end
  end
end
