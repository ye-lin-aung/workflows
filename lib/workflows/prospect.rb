module Workflows
  # Local dev tool — drives a browser via Playwright MCP, has Claude explore
  # the app as a new user, writes UX reports. Not loaded in production runtime
  # of host apps; only pulled in by the rake task.
  module Prospect
    # Classes autoloaded by Zeitwerk via the engine's lib/workflows/ root.
  end
end
