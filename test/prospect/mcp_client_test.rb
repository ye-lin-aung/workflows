require "test_helper"

# Integration test against the real @playwright/mcp server. Skipped in CI
# unless PROSPECT_MCP_INTEGRATION=1 is set. Local dev runs always.
class Workflows::Prospect::McpClientTest < ActiveSupport::TestCase
  SKIP_CI = ENV["CI"] && !ENV["PROSPECT_MCP_INTEGRATION"]

  test "starts @playwright/mcp, lists tools, closes cleanly" do
    skip "CI — set PROSPECT_MCP_INTEGRATION=1 to exercise" if SKIP_CI

    client = Workflows::Prospect::McpClient.new(
      command: "npx",
      args: ["--yes", "@playwright/mcp@latest", "--isolated", "--headless"]
    )
    client.start
    tools = client.list_tools
    assert tools.is_a?(Array)
    assert tools.any? { |t| t[:name].start_with?("browser_") }
  ensure
    client&.stop
  end

  test "call_tool returns a well-formed result" do
    skip "CI — set PROSPECT_MCP_INTEGRATION=1 to exercise" if SKIP_CI

    client = Workflows::Prospect::McpClient.new(
      command: "npx",
      args: ["--yes", "@playwright/mcp@latest", "--isolated", "--headless"]
    )
    client.start

    nav = client.call_tool("browser_navigate", { url: "data:text/html,<h1>hi</h1>" })
    assert nav[:content].is_a?(Array)

    snap = client.call_tool("browser_snapshot", {})
    assert snap[:content].any? { |c| c[:text].to_s.include?("hi") }
  ensure
    client&.stop
  end
end
