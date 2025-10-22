# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.setup

require_relative "writers_room/version"

module WritersRoom
  class Error < StandardError; end
end

# Shortcut constant for convenience
WR = WritersRoom
