require "test_helper"
require "ostruct"

class Workflows::Prospect::ExplorerTest < ActiveSupport::TestCase
  class FakeAnthropic
    attr_accessor :scripted_turns

    def initialize(turns)
      @scripted_turns = turns
      @call_index = 0
    end

    def messages
      self
    end

    def create(**_opts)
      turn = @scripted_turns[@call_index] || raise("FakeAnthropic ran out of scripted turns")
      @call_index += 1
      turn
    end
  end

  class FakeMcp
    attr_reader :calls

    def initialize
      @calls = []
    end

    def list_tools
      [
        { name: "browser_navigate", description: "", input_schema: { "type" => "object" } },
        { name: "browser_snapshot", description: "", input_schema: { "type" => "object" } }
      ]
    end

    def call_tool(name, args)
      @calls << { name: name, args: args }
      { content: [{ type: "text", text: "(stub result for #{name})" }], is_error: false }
    end

    def start; self; end
    def stop; end
  end

  def simple_entry
    Workflows::Prospect::CatalogEntry.new(
      "id" => "t",  "type" => "question",
      "persona" => "admin_dr_kim",
      "question" => "How do I X?",
      "start_route" => "root_path"
    )
  end

  # Anthropic::Messages::Message-shaped duck for what Explorer reads
  def turn(tool_uses: [], text: nil, stop_reason: "tool_use", input_tokens: 100, output_tokens: 50)
    content = []
    content << OpenStruct.new(type: "text", text: text) if text
    tool_uses.each do |tu|
      content << OpenStruct.new(type: "tool_use", id: tu[:id], name: tu[:name], input: tu[:input])
    end
    OpenStruct.new(
      content: content,
      stop_reason: stop_reason,
      usage: OpenStruct.new(input_tokens: input_tokens, output_tokens: output_tokens)
    )
  end

  test "runs one tool-use turn then a conclude turn" do
    anthropic = FakeAnthropic.new([
      turn(tool_uses: [{ id: "a", name: "browser_snapshot", input: {} }]),
      turn(tool_uses: [{ id: "b", name: "conclude",
                        input: { "verdict" => "easy", "summary" => "found it", "suggested_fix" => nil } }])
    ])
    mcp = FakeMcp.new

    exp = Workflows::Prospect::Explorer.new(
      anthropic_client: anthropic, mcp_client: mcp
    )
    state = exp.explore(entry: simple_entry, target_url: "http://localhost:3000")

    assert state.concluded?
    assert_equal :easy, state.verdict
    assert_equal "found it", state.summary
    assert_equal 1, mcp.calls.size
    assert_equal "browser_snapshot", mcp.calls.first[:name]
  end
end
