module Workflows
  module Prospect
    # One entry from config/prospect_questions.yml. Two shapes share this class:
    #   - "question" — simple "how do I X" single-turn goal
    #   - "scenario" — compound multi-step task with named sub-goals
    class CatalogEntry
      TYPES = %w[question scenario].freeze
      REQUIRED = %w[id persona question].freeze

      DEFAULT_BUDGET = {
        "question" => { time_cap_ms: 480_000, depth_cap: 4, token_cap: 40_000 },
        "scenario" => { time_cap_ms: 900_000, depth_cap: 5, token_cap: 80_000 }
      }.freeze

      attr_reader :id, :type, :group, :persona, :question, :start_route,
                  :expected_workflow, :setup, :sub_goals, :budget

      def initialize(hash)
        @type = (hash["type"] || "question").to_s
        raise ArgumentError, "unknown type #{@type.inspect}" unless TYPES.include?(@type)

        missing = REQUIRED - hash.keys
        raise ArgumentError, "missing required fields: #{missing.join(", ")}" if missing.any?

        @id                = hash.fetch("id")
        @group             = hash["group"]
        @persona           = hash.fetch("persona").to_sym
        @question          = hash.fetch("question")
        @start_route       = hash["start_route"]
        @expected_workflow = hash["expected_workflow"]
        @setup             = (hash["setup"] || []).map { |s| symbolize(s) }
        @sub_goals         = (hash["sub_goals"] || [])
        @budget            = build_budget(hash["budget"])
      end

      def question?; @type == "question"; end
      def scenario?; @type == "scenario"; end

      private

      def build_budget(overrides)
        base = DEFAULT_BUDGET.fetch(@type)
        return base unless overrides.is_a?(Hash)
        base.merge(overrides.transform_keys(&:to_sym))
      end

      def symbolize(hash)
        hash.transform_keys(&:to_sym).transform_values do |v|
          v.is_a?(Hash) ? v.transform_keys(&:to_sym) : v
        end
      end
    end
  end
end
