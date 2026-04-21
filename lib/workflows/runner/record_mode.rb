require "fileutils"

module Workflows
  module Runner
    # Records a workflow to MP4 + WebVTT. Launches a new Playwright context
    # with record_video_dir set, injects caption bar + cursor overlay on
    # every page load, runs the steps with:
    #
    #   1. Caption update + short settle pause
    #   2. Smooth cursor travel to the target element
    #   3. Target highlight (click ripple + outline halo)
    #   4. Animated action (fills type char-by-char; clicks pause pre/post)
    #   5. Post-action hold so the viewer sees the result
    #
    # then transcodes the resulting .webm to .mp4 via ffmpeg.
    class RecordMode
      # Milliseconds to hold on each step AFTER the action fires. Tuned for
      # readability — users need time to read the caption + see the outcome.
      DEFAULT_HOLD_MS = 1200

      # Typing delay per character, in ms. 60ms/char ≈ 17 chars/sec — slow
      # enough to be visibly animated but not painfully so.
      TYPE_DELAY_MS = 60

      # Pause while the cursor travels to a target before the action fires.
      # Matches the CSS transition time in CursorOverlay#init_script (260ms)
      # plus headroom so the cursor visibly arrives.
      CURSOR_SETTLE_MS = 400

      # Short extra pause after a click so the ripple/highlight is visible
      # before the next step starts.
      POST_CLICK_MS = 350

      def initialize(workflow:, output_dir:, navigate_direct: false)
        @workflow        = workflow
        @output_dir      = output_dir
        @navigate_direct = navigate_direct
      end

      def run
        I18n.with_locale(ENV["LOCALE"] || I18n.default_locale) do
          FileUtils.mkdir_p(raw_dir)
          adapter = build_adapter
          adapter.start
          # Register overlays as init scripts so they run on every navigation.
          inject_overlays(adapter)

          cues = []
          webm_path = nil
          begin
            sign_in_persona(adapter)
            goto_start(adapter)
            # The init scripts run at document start when <body> may not yet
            # exist. Also run them here (idempotent via IIFE guards) after the
            # page has loaded so overlays are guaranteed active.
            adapter.evaluate(CaptionBar.init_script)
            adapter.evaluate(CursorOverlay.init_script)
            execute_animated(adapter, cues)
            # Grab the video path while the page is still alive. The file itself
            # is not finalized until the context closes (in adapter.stop below).
            webm_path = adapter.video_path
          ensure
            adapter.stop
          end

          mp4_path = File.join(@output_dir, "#{flat_name}.mp4")
          vtt_path = File.join(@output_dir, "#{flat_name}.vtt")
          transcode_webm_to_mp4(webm_path, mp4_path) if webm_path
          File.write(vtt_path, Workflows::Compilers::Webvtt.call(cues))

          { mp4: mp4_path, vtt: vtt_path }
        end
      end

      private

      def flat_name
        @workflow.name.tr("/", "_")
      end

      def raw_dir
        File.join(@output_dir, "raw")
      end

      def build_adapter
        PlaywrightAdapter.new(headless: true, viewport: @workflow.viewport, record_video_dir: raw_dir)
      end

      def inject_overlays(adapter)
        adapter.add_init_script(CaptionBar.init_script)
        adapter.add_init_script(CursorOverlay.init_script)
      end

      # Step loop with cursor animation + element highlighting. Replaces the
      # plain Base#execute pass used by TestMode. The sequence per step is:
      #   1. Caption + short settle
      #   2. Move visible cursor to the target element (if any)
      #   3. Run wait_for precondition (e.g. wait for container to appear)
      #   4. Fire the action with animation (typed fill, highlight+ripple click)
      #   5. Run assertions / post-action wait_for
      #   6. hold_ms pause so the viewer can read the result
      def execute_animated(adapter, cues)
        start_at = Time.now

        @workflow.steps.each do |step|
          cue_start_ms = ((Time.now - start_at) * 1000).to_i
          caption_text = resolve_caption(step.caption)
          adapter.evaluate(CaptionBar.update_script(caption_text))
          sleep 0.3 # caption settle

          coords = move_cursor_to_target(adapter, step) if step.resolved_target
          run_wait_for(adapter, step.wait_for) if step.wait_for?
          dispatch_animated(adapter, step, coords)
          run_assert(adapter, step.assert) if step.assert?

          hold_ms = step.hold_ms || DEFAULT_HOLD_MS
          sleep(hold_ms / 1000.0)

          cue_end_ms = ((Time.now - start_at) * 1000).to_i
          cues << { start_ms: cue_start_ms, end_ms: cue_end_ms, text: caption_text }
        end
      end

      # Smoothly moves the SVG cursor over the target element's center and
      # returns the screen coordinates so callers can fire a ripple at the
      # same point. Returns nil if the element can't be located (falls back
      # to no cursor animation but the action still fires).
      def move_cursor_to_target(adapter, step)
        selector = step.resolved_target
        box = adapter.bounding_box(selector)
        return nil unless box

        x = (box[:x] + box[:width] / 2.0).round
        y = (box[:y] + box[:height] / 2.0).round
        adapter.evaluate(CursorOverlay.move_script(x, y))
        sleep(CURSOR_SETTLE_MS / 1000.0)
        [x, y]
      end

      def dispatch_animated(adapter, step, coords)
        target = step.resolved_target
        case step.action.to_s
        when "none"
          # Caption-only step — nothing to do.
        when "click"
          apply_highlight(adapter, target)
          adapter.evaluate(CursorOverlay.ripple_script(coords[0], coords[1])) if coords
          sleep 0.15 # ripple visible before the actual click
          adapter.click(target)
          sleep(POST_CLICK_MS / 1000.0)
          remove_highlight(adapter, target)
        when "fill"
          apply_highlight(adapter, target)
          # Clear any pre-existing value, then type for visible animation.
          adapter.fill(target, "")
          adapter.type(target, step.value.to_s, delay_ms: TYPE_DELAY_MS)
          remove_highlight(adapter, target)
        when "check"
          apply_highlight(adapter, target)
          adapter.evaluate(CursorOverlay.ripple_script(coords[0], coords[1])) if coords
          sleep 0.15
          adapter.check(target)
          sleep(POST_CLICK_MS / 1000.0)
          remove_highlight(adapter, target)
        when "uncheck"
          apply_highlight(adapter, target)
          adapter.evaluate(CursorOverlay.ripple_script(coords[0], coords[1])) if coords
          sleep 0.15
          adapter.uncheck(target)
          sleep(POST_CLICK_MS / 1000.0)
          remove_highlight(adapter, target)
        when "select"
          adapter.select(target, step.value)
        when "hover"
          adapter.hover(target)
        when "press"
          adapter.press(target, step.value || "Enter")
        when "upload"
          adapter.upload(target, step.value)
        when "visit"
          adapter.goto(step.value)
        else
          raise "unknown action #{step.action.inspect}"
        end
      end

      def run_wait_for(adapter, spec)
        if spec[:turbo_frame]
          adapter.wait_for_turbo_frame(spec[:turbo_frame], contains: spec[:contains])
        else
          adapter.wait_for_selector(spec[:selector], contains: spec[:contains])
        end
      end

      def run_assert(adapter, spec)
        adapter.wait_for_selector(spec[:selector], contains: spec[:contains])
      end

      # Apply a 3px blue outline + soft halo around the target. Purely visual —
      # the element's inline style is bumped, then cleared in remove_highlight.
      def apply_highlight(adapter, selector)
        adapter.evaluate(<<~JS)
          (function () {
            var el = document.querySelector(#{selector.to_json});
            if (!el) return;
            el.dataset.workflowPrevOutline = el.style.outline || "";
            el.dataset.workflowPrevBoxShadow = el.style.boxShadow || "";
            el.dataset.workflowPrevTransition = el.style.transition || "";
            el.style.transition = "outline 120ms ease-out, box-shadow 120ms ease-out";
            el.style.outline = "3px solid rgba(59, 130, 246, 0.9)";
            el.style.boxShadow = "0 0 0 6px rgba(59, 130, 246, 0.25)";
          })();
        JS
      end

      def remove_highlight(adapter, selector)
        adapter.evaluate(<<~JS)
          (function () {
            var el = document.querySelector(#{selector.to_json});
            if (!el) return;
            el.style.outline = el.dataset.workflowPrevOutline || "";
            el.style.boxShadow = el.dataset.workflowPrevBoxShadow || "";
            el.style.transition = el.dataset.workflowPrevTransition || "";
            delete el.dataset.workflowPrevOutline;
            delete el.dataset.workflowPrevBoxShadow;
            delete el.dataset.workflowPrevTransition;
          })();
        JS
      end

      def goto_start(adapter)
        url = @navigate_direct ? @workflow.start_at : build_url_from_helper
        adapter.goto(url)
      end

      # Record mode renders against a live Rails server, so the persona needs
      # to be authenticated against that server before we goto the
      # start_at URL. We resolve the persona through the host's resolver
      # (same one used by TestMode) and drive the host's sign_in_adapter.
      # Self-test runs (navigate_direct = true) skip this because they hit
      # pre-rendered static HTML.
      def sign_in_persona(adapter)
        return if @navigate_direct
        resolver = Workflows.config.persona_resolver
        signer   = Workflows.config.sign_in_adapter
        return unless resolver && signer
        user = resolver.call(@workflow.persona)
        return unless user
        signer.call(adapter, user)
      end

      def build_url_from_helper
        path = Rails.application.routes.url_helpers.instance_eval(@workflow.start_at)
        base = ENV["WORKFLOWS_RECORD_HOST"] || "http://127.0.0.1:3000"
        "#{base}#{path}"
      end

      def resolve_caption(caption)
        return caption unless caption.is_a?(String) && caption.match?(/\A[a-z0-9_]+(\.[a-z0-9_]+)+\z/i)
        I18n.t(caption, default: caption)
      end

      def transcode_webm_to_mp4(webm_path, mp4_path)
        cmd = [
          "ffmpeg", "-y", "-i", webm_path,
          "-c:v", "libx264", "-pix_fmt", "yuv420p",
          "-movflags", "+faststart",
          mp4_path
        ]
        ok = system(*cmd, out: File::NULL, err: File::NULL)
        raise "ffmpeg transcode failed for #{webm_path}" unless ok
      end
    end
  end
end
