require "fileutils"

module Workflows
  module Runner
    # Records a workflow to MP4 + WebVTT. Launches a new Playwright context
    # with record_video_dir set, injects caption bar + cursor overlay on
    # every page load, runs the steps with caption updates and hold_ms
    # pauses, then transcodes the resulting .webm to .mp4 via ffmpeg.
    class RecordMode
      DEFAULT_HOLD_MS = 400

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
            # page has loaded so window.__workflowSetCaption is defined.
            adapter.evaluate(CaptionBar.init_script)
            adapter.evaluate(CursorOverlay.init_script)
            start_at = Time.now
            Base.new(adapter: adapter).execute(@workflow) do |step, _idx|
              cue_start_ms = ((Time.now - start_at) * 1000).to_i
              caption_text = resolve_caption(step.caption)
              adapter.evaluate(CaptionBar.update_script(caption_text))
              sleep(((step.hold_ms || DEFAULT_HOLD_MS) / 1000.0))
              cue_end_ms = ((Time.now - start_at) * 1000).to_i
              cues << { start_ms: cue_start_ms, end_ms: cue_end_ms, text: caption_text }
            end
            # Grab the video path while the page is still alive. The file itself
            # is not finalized until the context closes (in adapter.stop below),
            # but Playwright requires us to read the path before close.
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
