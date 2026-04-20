module Workflows
  module Runner
    # Dispatches each step in a Workflow through a PlaywrightAdapter (real or fake).
    # Mode-specific behavior (assertion style, video overlay timing) is handled by
    # subclasses that pass a block to #execute and wrap each step.
    class Base
      def initialize(adapter:)
        @adapter = adapter
      end

      # Run every step. Yields (step, index) to the caller if a block is given —
      # record mode uses the hook to update caption bar and apply hold_ms pauses.
      def execute(workflow)
        workflow.steps.each_with_index do |step, idx|
          yield(step, idx) if block_given?
          dispatch(step)
          run_wait_for(step.wait_for) if step.wait_for?
          run_assert(step.assert)     if step.assert?
        end
      end

      private

      def dispatch(step)
        case step.action
        when "none"    then nil
        when "click"   then @adapter.click(step.resolved_target)
        when "fill"    then @adapter.fill(step.resolved_target, step.value)
        when "select"  then @adapter.select(step.resolved_target, step.value)
        when "check"   then @adapter.check(step.resolved_target)
        when "uncheck" then @adapter.uncheck(step.resolved_target)
        when "hover"   then @adapter.hover(step.resolved_target)
        when "press"   then @adapter.press(step.resolved_target, step.value || "Enter")
        when "upload"  then @adapter.upload(step.resolved_target, step.value)
        when "visit"   then @adapter.goto(resolve_visit_url(step.value))
        else raise "unknown action #{step.action.inspect}"
        end
      end

      # Workflow authors write relative URLs in `visit` steps (e.g.
      # "/teach/courses/foo") so they don't have to know the host/port at
      # author time — but Playwright's Page.goto rejects anything that
      # isn't an absolute URL. Resolve against the current page's origin.
      def resolve_visit_url(url)
        return url if url.to_s =~ %r{\A[a-z]+://}i
        current = @adapter.current_url.to_s
        base = current[%r{\A[a-z]+://[^/]+}i]
        return url unless base
        url.to_s.start_with?("/") ? "#{base}#{url}" : "#{base}/#{url}"
      end

      def run_wait_for(spec)
        if spec[:turbo_frame]
          @adapter.wait_for_turbo_frame(spec[:turbo_frame], contains: spec[:contains])
        else
          @adapter.wait_for_selector(spec[:selector], contains: spec[:contains])
        end
      end

      def run_assert(spec)
        # TestMode subclass overrides this with real Minitest assertions.
        # Base implementation uses wait_for_selector as a de-facto assertion —
        # if the expected content never appears, wait_for raises.
        @adapter.wait_for_selector(spec[:selector], contains: spec[:contains])
      end
    end
  end
end
