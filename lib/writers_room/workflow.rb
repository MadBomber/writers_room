# frozen_string_literal: true

module WritersRoom
  # Manages workflow progression for a medium type.
  # Validates status transitions and tracks current stage.
  class Workflow
    attr_reader :medium

    # Universal status progression order
    STATUS_ORDER = %w[outline draft revision polish final].freeze

    def initialize(medium)
      @medium = medium
    end

    def statuses
      @medium.statuses
    end

    def workflows
      @medium.workflows
    end

    def valid_status_transition?(from, to)
      from_idx = statuses.index(from.to_s)
      to_idx   = statuses.index(to.to_s)

      return false unless from_idx && to_idx

      # Can move forward, or back one step (revision)
      to_idx >= from_idx || (from_idx - to_idx) == 1
    end

    def next_status(current)
      idx = statuses.index(current.to_s)
      return nil unless idx
      statuses[idx + 1]
    end

    def current_stage(project_path)
      state = ProjectState.new(project_path, medium: @medium)
      state.workflow_stage
    end

    def next_steps(project_path)
      stage = current_stage(project_path)
      steps = []

      case stage
      when :empty
        steps << "Define your project concept"
        steps << "Create initial characters"
      when :concept_only
        steps << "Create characters to populate your story"
        steps << "Define your setting and locations"
      when :populating
        steps << "Continue adding story elements"
        steps << "Begin outlining your structure"
        steps << "Define character relationships and arcs"
      when :developing
        steps << "Review and revise existing elements"
        steps << "Begin drafting content"
        steps << "Update your story bible: wr bible regenerate"
      end

      steps
    end
  end
end
