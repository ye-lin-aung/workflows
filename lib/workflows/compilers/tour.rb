module Workflows
  module Compilers
    # Projects a Workflow into the hash shape the tutorials gem's Tour.load_hash
    # consumes. Rules:
    #   - drops action/value/wait_for/assert/setup/viewport/hold_ms — driver.js
    #     doesn't use them
    #   - skips caption-only steps (no target / target_css) — driver.js requires
    #     an element to highlight
    #   - preserves i18n keys verbatim (tutorials resolves them at render time)
    #   - route is taken from start_at as-is (Phase 2 may add a route_override)
    module Tour
      module_function

      def call(workflow)
        {
          id:              workflow.tour_id,
          route:           compile_route(workflow),
          title_key:       workflow.title,
          description_key: workflow.description,
          first_login:     false,
          steps:           workflow.steps.filter_map { |step| project_step(step, workflow) }
        }
      end

      # The tutorials gem's PathMatcher compiles the `route` string into a
      # regex and refuses segments that mix literals with `:name` or `*name`
      # tokens. Workflow `start_at` values are free-form Ruby expressions
      # evaluated against url_helpers (e.g. `assessment_path(Assessment.find_by!(title: "..."))`),
      # which can legitimately contain `:` from keyword-arg hashes and
      # confuse the PathMatcher compiler. When the expression isn't obviously
      # a plain URL path, fall back to a synthetic route that identifies the
      # workflow by name — in-app tour availability matching on these
      # programmatic start_ats would never work anyway (Phase 2 may add a
      # separate route_override).
      def compile_route(workflow)
        raw = workflow.start_at.to_s
        return raw if safe_route?(raw)
        "/__workflow__/#{workflow.tour_id}"
      end

      def safe_route?(str)
        return false if str.include?("(")
        return false if str.include?('"') || str.include?("'")
        return false if str.include?(" ")
        return false if str.match?(/[^\/\w:\*\-]/)
        true
      end

      def project_step(step, workflow)
        element = step.resolved_target
        return nil if element.nil?
        {
          element: element,
          title_key: workflow.title,
          body_key:  step.caption
        }
      end
    end
  end
end
