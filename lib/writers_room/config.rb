# frozen_string_literal: true

require "myway_config"

module WritersRoom
  class Config < MywayConfig::Base
    config_name :writers_room
    env_prefix  :writers_room
    defaults_path File.expand_path("config/defaults.yml", __dir__)
    auto_configure!
  end
end
