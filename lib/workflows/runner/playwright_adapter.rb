require "playwright"

module Workflows
  module Runner
    # Thin wrapper around playwright-ruby-client that the runner uses. Exposes
    # exactly the surface the workflow actions need — no more. Keeps the
    # runner testable by making this class easy to stub in tests that don't
    # want to launch a browser.
    class PlaywrightAdapter
      attr_reader :page, :browser

      def initialize(headless: true, viewport: { width: 1440, height: 900 }, record_video_dir: nil)
        @headless         = headless
        @viewport         = viewport
        @record_video_dir = record_video_dir
      end

      def start
        @playwright_instance = Playwright.create(playwright_cli_executable_path: "npx playwright")
        @playwright          = @playwright_instance.playwright
        launch_opts          = { headless: @headless }
        @browser             = @playwright.chromium.launch(**launch_opts)

        context_opts = { viewport: @viewport }
        context_opts[:record_video_dir] = @record_video_dir if @record_video_dir
        context_opts[:record_video_size] = @viewport        if @record_video_dir
        @context = @browser.new_context(**context_opts)
        @page    = @context.new_page
      end

      def stop
        @context&.close
        @browser&.close
        @playwright_instance&.stop
      end

      def video_path
        @page&.video&.path
      end

      # Navigation
      def goto(url)           ; @page.goto(url)           ; end
      def title               ; @page.title               ; end
      def current_url         ; @page.url                 ; end

      # Text/value accessors
      def text(selector)      ; @page.text_content(selector) ; end
      def value(selector)     ; @page.input_value(selector)  ; end

      # Actions
      def click(selector)     ; @page.click(selector)          ; end
      def fill(selector, val) ; @page.fill(selector, val)      ; end
      def select(selector, v) ; @page.select_option(selector, value: v) ; end
      def check(selector)     ; @page.check(selector)          ; end
      def uncheck(selector)   ; @page.uncheck(selector)        ; end
      def hover(selector)     ; @page.hover(selector)          ; end
      def press(selector, k)  ; @page.press(selector, k)       ; end
      def upload(selector, path) ; @page.set_input_files(selector, path) ; end

      # Waits
      def wait_for_selector(selector, contains: nil, timeout_ms: 10_000)
        @page.wait_for_selector(selector, timeout: timeout_ms)
        return unless contains
        @page.wait_for_function(
          "([sel, txt]) => (document.querySelector(sel)?.textContent || '').includes(txt)",
          arg: [selector, contains],
          timeout: timeout_ms
        )
      end

      def wait_for_turbo_frame(id, contains: nil, timeout_ms: 10_000)
        wait_for_selector("turbo-frame##{id}", contains: contains, timeout_ms: timeout_ms)
      end

      # Inject a JS/CSS snippet into the page — used for caption bar & cursor overlay.
      def add_init_script(js)
        @context.add_init_script(script: js)
      end

      def evaluate(js, arg = nil)
        arg.nil? ? @page.evaluate(js) : @page.evaluate(js, arg: arg)
      end
    end
  end
end
