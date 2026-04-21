require "ostruct"

module Workflows
  module Prospect
    class Explorer
      INTERNAL_TOOLS = %w[conclude spawn_followup complete_sub_goal fail_sub_goal report_missing_feature].freeze

      attr_reader :mcp_client

      def initialize(anthropic_client:, mcp_client:)
        @anthropic_client = anthropic_client
        @mcp_client = mcp_client
        @novelty = NoveltyGate.new
      end

      def explore(entry:, target_url:)
        @novelty.record(entry.question)
        state = ThreadState.new(entry: entry)
        budget = Budget.new(**entry.budget)
        transcript = []
        tools = compose_tools

        until state.concluded? || budget.exceeded?
          started = Time.now
          system = PromptBuilder.system_prompt(state: state, target_url: target_url)

          response = @anthropic_client.messages.create(
            model: "claude-sonnet-4-6",
            max_tokens: 4096,
            system: system,
            messages: transcript,
            tools: tools
          )

          record_usage(budget, response, started)
          state.record_turn

          assistant_msg = { role: "assistant", content: response.content }
          transcript << assistant_msg

          tool_results = response.content.select { |c| c.type == "tool_use" }.map do |tu|
            handle_tool_call(state: state, name: tu.name, input: tu.input, call_id: tu.id)
          end

          if tool_results.any?
            transcript << { role: "user", content: tool_results }
          end

          break if response.stop_reason == "end_turn"
        end

        state
      end

      private

      def compose_tools
        mcp_tools = @mcp_client.list_tools.map do |t|
          { name: t[:name], description: t[:description], input_schema: t[:input_schema] }
        end

        internal = [
          {
            name: "conclude",
            description: "End this thread with a verdict.",
            input_schema: {
              "type" => "object",
              "properties" => {
                "verdict"       => { "type" => "string", "enum" => %w[easy struggle failed complete partial stuck] },
                "summary"       => { "type" => "string" },
                "suggested_fix" => { "type" => "string" }
              },
              "required" => ["verdict", "summary"]
            }
          },
          {
            name: "complete_sub_goal",
            description: "Scenario: mark a sub-goal as done.",
            input_schema: {
              "type" => "object",
              "properties" => {
                "index" => { "type" => "integer" },
                "notes" => { "type" => "string" }
              },
              "required" => ["index"]
            }
          },
          {
            name: "fail_sub_goal",
            description: "Scenario: mark a sub-goal as failed (and continue).",
            input_schema: {
              "type" => "object",
              "properties" => {
                "index"  => { "type" => "integer" },
                "reason" => { "type" => "string" }
              },
              "required" => ["index"]
            }
          },
          {
            name: "report_missing_feature",
            description: "Confident the feature does not exist in the app. Sets verdict=not_in_app.",
            input_schema: {
              "type" => "object",
              "properties" => {
                "feature"        => { "type" => "string" },
                "evidence"       => { "type" => "string" },
                "confidence"     => { "type" => "string", "enum" => %w[high medium low] },
                "business_value" => { "type" => "string" }
              },
              "required" => ["feature", "evidence", "confidence"]
            }
          },
          {
            name: "spawn_followup",
            description: "Start a child thread for a new question that emerged during exploration.",
            input_schema: {
              "type" => "object",
              "properties" => {
                "question" => { "type" => "string" },
                "reason"   => { "type" => "string" }
              },
              "required" => ["question"]
            }
          },
        ]

        mcp_tools + internal
      end

      def handle_tool_call(state:, name:, input:, call_id:)
        if INTERNAL_TOOLS.include?(name.to_s)
          handle_internal_tool(state: state, name: name.to_s, input: input)
          return { type: "tool_result", tool_use_id: call_id, content: "ok" }
        end
        result = @mcp_client.call_tool(name.to_s, (input.respond_to?(:to_h) ? input.to_h : input))
        text = Array(result[:content]).map { |c| c[:text] }.join("\n")
        { type: "tool_result", tool_use_id: call_id, content: text, is_error: !!result[:is_error] }
      end

      def handle_internal_tool(state:, name:, input:)
        case name
        when "conclude"
          verdict_sym = input["verdict"].to_sym
          state.conclude!(verdict: verdict_sym, summary: input["summary"], suggested_fix: input["suggested_fix"])
        when "complete_sub_goal"
          state.complete_sub_goal(index: input["index"], notes: input["notes"].to_s)
        when "fail_sub_goal"
          state.fail_sub_goal(index: input["index"], reason: input["reason"].to_s)
        when "report_missing_feature"
          state.set_missing_feature(
            feature: input["feature"],
            evidence: input["evidence"],
            confidence: input["confidence"],
            business_value: input["business_value"]
          )
        when "spawn_followup"
          candidate = input["question"].to_s
          if @novelty.novel?(candidate)
            @novelty.record(candidate)
            state.record_breadcrumb(summary: "spawn_followup: #{candidate}", url: nil)
          else
            state.record_breadcrumb(summary: "follow-up rejected (not novel): #{candidate}", url: nil)
          end
        end
      end

      def record_usage(budget, response, started)
        elapsed = ((Time.now - started) * 1000).to_i
        tokens = (response.usage&.input_tokens || 0) + (response.usage&.output_tokens || 0)
        budget.record_turn(tokens_used: tokens, elapsed_ms_delta: elapsed)
      end
    end
  end
end
