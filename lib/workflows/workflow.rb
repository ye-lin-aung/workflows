module Workflows
  # In-memory representation of a workflow loaded from a YAML file.
  # Value object — immutable after construction. Built by YamlLoader.
  class Workflow
    DEFAULT_VIEWPORT = { width: 1440, height: 900 }.freeze

    attr_reader :name, :title, :description, :host, :persona, :start_at,
                :viewport, :setup, :steps

    def initialize(name:, title:, description:, host:, persona:, start_at:,
                   steps:, viewport: nil, setup: nil)
      @name        = name
      @title       = title
      @description = description
      @host        = host
      @persona     = persona
      @start_at    = start_at
      @steps       = steps
      @viewport    = viewport || DEFAULT_VIEWPORT
      @setup       = setup || []
    end

    # Transforms "teacher/grade_assignment" into the dotted tour id form
    # "teacher.grade_assignment" expected by the tutorials gem.
    def tour_id
      name.to_s.tr("/", ".")
    end

    def host_sym
      host.to_sym
    end
  end
end
