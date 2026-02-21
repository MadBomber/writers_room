# frozen_string_literal: true

require "logger"

module WritersRoom
  # Multi-specialist chat room container. Analogous to Room but for
  # interactive chat mode. Creates the message bus, shared memory,
  # instantiates specialists from the medium config, and wires up
  # the Showrunner dispatcher.
  class ChatRoom
    attr_reader :bus, :memory, :specialists, :showrunner, :medium, :logger

    # @param medium [Medium] project medium with chat_specialists defined
    # @param project_context [Hash] project info (name, concept, state, etc.)
    # @param project_path [String] path to project directory
    # @param config [RobotLab::RunConfig] shared LLM configuration
    def initialize(medium:, project_context:, project_path:, config:)
      @medium          = medium
      @project_context = project_context
      @project_path    = project_path
      @config          = config
      @logger          = build_logger(project_path)

      @bus    = TypedBus::MessageBus.new
      @memory = RobotLab::Memory.new(enable_cache: false)

      @bus.add_channel(:responses)

      @specialists = {}
      load_specialists

      dispatch_channels = @specialists.keys.map { |id| ":dispatch_#{id}" }.join(", ")
      @logger.info("BUS: channels created — #{dispatch_channels}, :responses")

      @showrunner = Showrunner.new(
        medium:          medium,
        project_context: project_context,
        bus:             @bus,
        shared_memory:   @memory,
        specialists:     @specialists,
        config:          config,
        logger:          @logger
      )

      @logger.info("ROOM: chat room ready — #{@specialists.size} specialist(s), showrunner initialized")
    end

    # Send a user message through the Showrunner for classification and dispatch.
    # Returns the collected responses for this round.
    #
    # @param message [String] user input
    # @return [Array<Hash>] responses with :from, :content, :label keys
    def send_user_message(message)
      @showrunner.dispatch(message)
    end

    # Returns a displayable list of specialists.
    #
    # @return [Array<Hash>] each with :id, :label, :description, :domains
    def specialist_roster
      @medium.chat_specialists.map do |spec|
        {
          id:          spec[:id],
          label:       spec[:label],
          description: spec[:description],
          domains:     Array(spec[:domains]),
        }
      end
    end

    # Check if the reaction window is currently open.
    def reaction_window_open?
      @showrunner.reaction_window_open?
    end

    # Disconnect all specialists and close the bus.
    def shutdown
      @logger.info("ROOM: shutting down")
      @specialists.each_value(&:disconnect)
      @showrunner.shutdown
      @bus.close_all
      @specialists.clear
      @logger.info("ROOM: shutdown complete")
    end

    private

    def build_logger(project_path)
      if project_path
        log_path = File.join(project_path, "wr.log")
        logger = Logger.new(log_path, "weekly")
      else
        logger = Logger.new($stderr)
      end

      logger.formatter = proc { |severity, datetime, _progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
      }
      logger
    end

    def load_specialists
      @medium.chat_specialists.each do |spec_config|
        @bus.add_channel(:"dispatch_#{spec_config[:id]}")

        specialist = Specialist.new(
          spec_config:     spec_config,
          project_context: @project_context,
          project_path:    @project_path,
          bus:             @bus,
          shared_memory:   @memory,
          config:          @config,
          logger:          @logger
        )
        specialist.chat_room = self
        @specialists[spec_config[:id].to_s] = specialist
        @logger.info("ROOM: loaded specialist '#{spec_config[:id]}' (#{spec_config[:label]})")
      end
    end
  end
end
