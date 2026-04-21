module Workflows
  module Runner
    # JS/CSS that injects a visible SVG cursor into the page and exposes
    # helpers for moving it and showing a click ripple. Playwright's built-in
    # cursor is not captured by the video recorder — this overlay gives the
    # viewer a visible pointer.
    module CursorOverlay
      module_function

      def init_script
        <<~JS
          (function () {
            if (document.getElementById("workflow-cursor")) return;
            const style = document.createElement("style");
            style.textContent = `
              #workflow-cursor {
                position: fixed;
                top: 0;
                left: 0;
                width: 24px;
                height: 24px;
                transform: translate(-4px, -2px);
                z-index: 2147483646;
                pointer-events: none;
                transition: top 700ms cubic-bezier(0.2, 0.9, 0.3, 1),
                            left 700ms cubic-bezier(0.2, 0.9, 0.3, 1);
              }
              #workflow-cursor svg { width: 100%; height: 100%; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.5)); }
              .workflow-ripple {
                position: fixed;
                width: 24px;
                height: 24px;
                border-radius: 50%;
                background: rgba(59, 130, 246, 0.45);
                pointer-events: none;
                z-index: 2147483645;
                animation: workflow-ripple-expand 450ms ease-out forwards;
              }
              @keyframes workflow-ripple-expand {
                0%   { transform: scale(0.4); opacity: 0.9; }
                100% { transform: scale(3.0); opacity: 0; }
              }
            `;
            document.head.appendChild(style);

            const cursor = document.createElement("div");
            cursor.id = "workflow-cursor";
            cursor.innerHTML = `
              <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path d="M4 2 L20 12 L13 13.5 L11.5 20 Z" fill="#ffffff" stroke="#0b0b0e" stroke-width="1.2" stroke-linejoin="round"/>
              </svg>
            `;
            document.body.appendChild(cursor);

            window.__workflowMoveCursor = function (x, y) {
              cursor.style.left = x + "px";
              cursor.style.top  = y + "px";
            };

            window.__workflowClickRipple = function (x, y) {
              const r = document.createElement("div");
              r.className = "workflow-ripple";
              r.style.left = (x - 12) + "px";
              r.style.top  = (y - 12) + "px";
              document.body.appendChild(r);
              setTimeout(() => r.remove(), 500);
            };
          })();
        JS
      end

      def move_script(x, y)
        "window.__workflowMoveCursor(#{x}, #{y})"
      end

      def ripple_script(x, y)
        "window.__workflowClickRipple(#{x}, #{y})"
      end
    end
  end
end
