require "json"

module Workflows
  module Runner
    # JS/CSS that injects a fixed-position caption bar into the page DOM.
    # Runner::RecordMode adds the init script to the Playwright context so the
    # bar is present on every page load; update_script is evaluated per step
    # to change the displayed text.
    module CaptionBar
      module_function

      def init_script
        <<~JS
          (function () {
            if (document.getElementById("workflow-caption-bar")) return;
            const style = document.createElement("style");
            style.textContent = `
              #workflow-caption-bar {
                position: fixed;
                bottom: 0;
                left: 0;
                right: 0;
                padding: 18px 32px;
                background: rgba(12, 12, 16, 0.78);
                color: #fff;
                font-family: "Inter", system-ui, -apple-system, sans-serif;
                font-size: 18px;
                font-weight: 500;
                line-height: 1.35;
                text-align: center;
                z-index: 2147483647;
                opacity: 0;
                transition: opacity 180ms ease-out;
                pointer-events: none;
              }
              #workflow-caption-bar.visible { opacity: 1; }
            `;
            document.head.appendChild(style);

            const bar = document.createElement("div");
            bar.id = "workflow-caption-bar";
            document.body.appendChild(bar);

            window.__workflowSetCaption = function (text) {
              bar.textContent = text;
              bar.classList.add("visible");
            };
          })();
        JS
      end

      def update_script(text)
        # Use JSON.generate (not #to_json) so ActiveSupport's HTML-safe
        # override does not escape characters like & into \u0026 — the text
        # is being injected into a JS string literal, not HTML.
        "window.__workflowSetCaption(#{JSON.generate(text)})"
      end
    end
  end
end
