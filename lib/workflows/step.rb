module Workflows
  # A single step inside a workflow. Value object — immutable after construction.
  # Each step has a required caption (i18n key or inline string) and an optional
  # action (default "none" for caption-only steps). Actions drive Playwright
  # dispatch; caption is displayed as a subtitle in record mode and used as
  # popover body in the projected tour.
  class Step
    ALLOWED_ACTIONS = %w[none click fill select check uncheck hover press upload visit].freeze

    attr_reader :caption, :action, :target, :target_css, :value,
                :wait_for, :assert, :hold_ms

    def initialize(caption:, action: "none", target: nil, target_css: nil,
                   value: nil, wait_for: nil, assert: nil, hold_ms: nil)
      @caption    = caption
      @action     = action.to_s
      @target     = target
      @target_css = target_css
      @value      = value
      @wait_for   = wait_for
      @assert     = assert
      @hold_ms    = hold_ms
    end

    def value?;    !@value.nil? end
    def wait_for?; !@wait_for.nil? end
    def assert?;   !@assert.nil? end

    # True when the step is using the target_css escape hatch rather than a
    # [data-tour='...'] selector. The audit flags these.
    def escape_hatch?
      @target.nil? && !@target_css.nil?
    end

    # The actual selector to pass to Playwright — target wins over target_css.
    def resolved_target
      @target || @target_css
    end
  end
end
