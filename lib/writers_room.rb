# frozen_string_literal: true

require "robot_lab"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/writers_room/config/")
loader.ignore("#{__dir__}/writers_room/scene_messages.rb")
loader.setup

require_relative "writers_room/version"
require_relative "writers_room/scene_messages"

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
