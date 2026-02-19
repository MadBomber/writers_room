# frozen_string_literal: true

require "robot_lab"
require "zeitwerk"

# Set template path so RobotLab's prompt_manager finds our .md templates
ENV["ROBOT_LAB_TEMPLATE_PATH"] ||= File.expand_path("writers_room/prompts", __dir__)

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("llm_setup" => "LLMSetup")
loader.ignore("#{__dir__}/writers_room/config/")
loader.collapse("#{__dir__}/writers_room/tools")
loader.setup

require_relative "writers_room/version"

module WritersRoom
  class Error < StandardError; end

  class << self
    def config
      @config ||= Config.new
    end

    def reset_config!
      @config = nil
    end
  end
end

# Shortcut constant for convenience
WR = WritersRoom
