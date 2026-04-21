require "fileutils"

module Workflows
  module Prospect
    class ReportWriter
      def initialize(root_dir:, target_url:)
        @root_dir   = root_dir
        @target_url = target_url
        FileUtils.mkdir_p(@root_dir)
      end

      def write_thread(state)
        dir = File.join(@root_dir, state.entry.id)
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "report.md"), render_thread(state))
      end

      def write_index(threads)
        File.write(File.join(@root_dir, "index.md"), render_index(threads))
      end

      private

      def render_thread(state)
        entry = state.entry
        entry.scenario? ? render_scenario(state) : render_question(state)
      end

      def render_question(state)
        entry = state.entry
        verdict_label = verdict_emoji(state.verdict) + " " + state.verdict.to_s
        workflow_ref =
          if entry.expected_workflow
            "**Reference:** Workflow `#{entry.expected_workflow}` demonstrates this flow. " \
              "[▶ Watch](#{@target_url}/videos/)"
          else
            "**Reference:** No workflow video exists for this flow. Gap: undocumented."
          end

        missing = state.missing_feature
        missing_section =
          if missing
            <<~MD

              ## Missing feature
              - **Feature:** #{missing[:feature]}
              - **Confidence:** #{missing[:confidence]}
              - **Evidence:** #{missing[:evidence]}
              - **Business value:** #{missing[:business_value]}
            MD
          else
            ""
          end

        <<~MD
          # #{entry.question}

          **Persona:** #{entry.persona}
          **Target:** #{@target_url}
          **Verdict:** #{verdict_label}
          **Turns:** #{state.turn_count}

          ## Summary
          #{state.summary || "(no summary)"}

          ## Suggested fix
          #{state.suggested_fix || "_none captured_"}

          #{missing_section}
          ## Breadcrumbs
          #{render_breadcrumbs(state)}

          #{workflow_ref}
        MD
      end

      def render_scenario(state)
        entry = state.entry
        verdict_label = verdict_emoji(state.verdict) + " " + state.verdict.to_s
        done  = state.sub_goals.count { |sg| sg[:status] == :done }
        total = state.sub_goals.size

        rows = state.sub_goals.each_with_index.map do |sg, i|
          status_cell =
            case sg[:status]
            when :done   then "✅ done"
            when :failed then "❌ failed"
            else              "⚠️ pending"
            end
          "| #{i + 1} | #{sg[:text]} | #{status_cell} | #{sg[:notes].to_s.gsub("|", "\\|")} |"
        end.join("\n")

        workflow_ref =
          if entry.expected_workflow
            "**Reference:** Workflow `#{entry.expected_workflow}` covers this scenario. " \
              "[▶ Watch](#{@target_url}/videos/)"
          else
            "**Reference:** No workflow video covers this scenario. Gap: undocumented."
          end

        <<~MD
          # #{entry.question}

          **Persona:** #{entry.persona}
          **Target:** #{@target_url}
          **Verdict:** #{verdict_label} (#{done}/#{total} sub-goals)
          **Turns:** #{state.turn_count}

          ## Sub-goals

          | # | Sub-goal | Status | Notes |
          |---|---|---|---|
          #{rows}

          ## Summary
          #{state.summary || "(no summary)"}

          ## Suggested fix
          #{state.suggested_fix || "_none captured_"}

          #{workflow_ref}
        MD
      end

      def render_index(threads)
        counts = Hash.new(0)
        threads.each { |t| counts[t.verdict] += 1 }

        by_group = threads.group_by { |t| t.entry.group || "Uncategorized" }
        groups_md = by_group.map do |group, ts|
          rows = ts.map do |t|
            verdict_label = verdict_emoji(t.verdict) + " " + t.verdict.to_s
            sub = t.entry.scenario? ? " (#{t.sub_goals.count { |sg| sg[:status] == :done }}/#{t.sub_goals.size})" : ""
            "| #{t.entry.id} | #{t.entry.persona} | #{verdict_label}#{sub} |"
          end.join("\n")
          "### #{group}\n| ID | Persona | Verdict |\n|---|---|---|\n#{rows}"
        end.join("\n\n")

        missing = threads.map(&:missing_feature).compact
        missing_md =
          if missing.any?
            rows = missing
              .sort_by { |m| -confidence_weight(m[:confidence]) }
              .map { |m| "| #{m[:feature]} | #{m[:confidence]} | #{m[:evidence]} | #{m[:business_value]} |" }
              .join("\n")
            "\n\n## Missing features (prioritized)\n| Feature | Confidence | Evidence | Business value |\n|---|---|---|---|\n#{rows}"
          else
            ""
          end

        <<~MD
          # Prospect exploration

          **Target:** #{@target_url}
          **Questions:** #{threads.size}

          ## Summary
          - ✅ easy: #{counts[:easy] + counts[:complete]}
          - ⚠ struggle: #{counts[:struggle]}
          - 🟡 partial: #{counts[:partial]}
          - ❌ failed/stuck: #{counts[:failed] + counts[:stuck]}
          - 🚫 not in app: #{counts[:not_in_app]}

          #{groups_md}#{missing_md}
        MD
      end

      def render_breadcrumbs(state)
        return "_none recorded_" if state.breadcrumbs.empty?
        state.breadcrumbs.each_with_index.map do |b, i|
          url = b[:url] ? " — `#{b[:url]}`" : ""
          "#{i + 1}. #{b[:summary]}#{url}"
        end.join("\n")
      end

      def verdict_emoji(v)
        {
          easy: "✅", complete: "✅",
          struggle: "⚠️",
          partial: "🟡",
          failed: "❌", stuck: "❌",
          not_in_app: "🚫"
        }.fetch(v, "•")
      end

      def confidence_weight(c)
        { "high" => 3, "medium" => 2, "low" => 1 }.fetch(c.to_s, 0)
      end
    end
  end
end
