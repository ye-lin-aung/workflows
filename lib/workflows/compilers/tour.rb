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
          route:           workflow.start_at,
          title_key:       workflow.title,
          description_key: workflow.description,
          first_login:     false,
          steps:           workflow.steps.filter_map { |step| project_step(step, workflow) }
        }
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
