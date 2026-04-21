module Workflows
  module Prospect
    module PromptBuilder
      module_function

      def system_prompt(state:, target_url:)
        entry = state.entry
        base = <<~PROMPT
          You are playing the role of `#{entry.persona}`, a real user of a web application
          exploring it for the first time. You perceive the page only through the accessibility
          tree (snapshot tool) and, when blocked, screenshots. You do NOT have access to source
          code, database state beyond what the UI shows, or developer documentation.

          Target URL: #{target_url}
          Question: "#{entry.question}"

          Rules:
          - Use browser_* tools to navigate, click, fill, and read the page.
          - Prefer the accessibility snapshot over screenshots. Use screenshots only when stuck.
          - Try retries (same question, different approach) before spawning a follow-up.
          - If you spawn a follow-up, call spawn_followup(question:, reason:) — one short sentence
            for the follow-up question. It must be a new, distinct question, not a rephrase
            of a prior one.
          - When you've found the answer OR hit a dead end, call conclude(verdict:, summary:, suggested_fix:).
            - For simple questions: verdict ∈ {"easy", "struggle", "failed"}.
            - For scenarios: verdict is derived from sub_goal statuses; still call conclude
              with a summary once done.
          - If after thorough exploration you're confident the feature does not exist in the
            app at all, call report_missing_feature(feature:, evidence:, confidence:, business_value:)
            BEFORE conclude. This sets verdict=not_in_app. Distinguish this from "failed" —
            "failed" means you couldn't find it; "not_in_app" means it isn't here.
          - Exhaustive evidence for not_in_app: cite what you searched (nav items, search bar,
            likely URLs, settings sections). A real prospect checks email + settings + search
            before concluding the feature isn't supported.
        PROMPT

        if entry.scenario?
          base += <<~SCENARIO

            This is a multi-step scenario. Sub-goals (pursue in order,
            mark each one done or failed as you go):
            #{entry.sub_goals.each_with_index.map { |t, i| "  #{i + 1}. #{t}" }.join("\n")}

            Tools:
              - complete_sub_goal(index:, notes:)  — mark a sub-goal done (index is 0-based).
              - fail_sub_goal(index:, reason:)     — mark a sub-goal failed and continue.

            Don't short-circuit by claiming the whole scenario is done after one click —
            each sub-goal must be addressed individually.
          SCENARIO
        end

        base
      end
    end
  end
end
