module Workflows
  module Prospect
    class ThreadState
      attr_reader :entry, :depth, :parent_thread_id
      attr_reader :sub_goals, :breadcrumbs, :turn_count
      attr_reader :verdict, :summary, :suggested_fix, :missing_feature

      def initialize(entry:, depth: 0, parent_thread_id: nil)
        @entry = entry
        @depth = depth
        @parent_thread_id = parent_thread_id
        @sub_goals = entry.sub_goals.map { |text| { text: text, status: :pending, notes: nil } }
        @breadcrumbs = []
        @turn_count = 0
        @verdict = nil
        @summary = nil
        @suggested_fix = nil
        @missing_feature = nil
      end

      def record_turn
        @turn_count += 1
      end

      def record_breadcrumb(summary:, url:)
        @breadcrumbs << { turn_no: @turn_count + 1, summary: summary, url: url }
      end

      def complete_sub_goal(index:, notes:)
        sg = @sub_goals.fetch(index)
        sg[:status] = :done
        sg[:notes]  = notes
      end

      def fail_sub_goal(index:, reason:)
        sg = @sub_goals.fetch(index)
        sg[:status] = :failed
        sg[:notes]  = reason
      end

      def set_missing_feature(feature:, evidence:, confidence:, business_value:)
        @missing_feature = { feature: feature, evidence: evidence,
                             confidence: confidence, business_value: business_value }
        @verdict = :not_in_app
      end

      def conclude!(verdict:, summary:, suggested_fix:)
        @verdict ||= derived_verdict_or(verdict)
        @summary = summary
        @suggested_fix = suggested_fix
      end

      def concluded?
        !@verdict.nil?
      end

      def derived_verdict
        if entry.scenario?
          statuses = @sub_goals.map { |sg| sg[:status] }
          return :complete if statuses.all? { |s| s == :done }
          done  = statuses.count(:done)
          total = statuses.size
          failed = statuses.count(:failed)
          return :stuck   if done == 0 && failed == 0
          return :stuck   if done == 1 && failed == 0 && total > 1 && statuses[0] == :done
          return :partial
        end
        nil
      end

      private

      def derived_verdict_or(fallback)
        derived_verdict || fallback
      end
    end
  end
end
