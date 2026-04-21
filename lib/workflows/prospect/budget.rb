module Workflows
  module Prospect
    class Budget
      attr_reader :time_cap_ms, :depth_cap, :token_cap
      attr_reader :elapsed_ms, :tokens_used, :depth

      def initialize(time_cap_ms:, depth_cap:, token_cap:)
        @time_cap_ms = time_cap_ms
        @depth_cap   = depth_cap
        @token_cap   = token_cap
        @elapsed_ms  = 0
        @tokens_used = 0
        @depth       = 0
      end

      def record_turn(tokens_used:, elapsed_ms_delta:)
        @tokens_used += tokens_used
        @elapsed_ms  += elapsed_ms_delta
      end

      def incr_depth
        @depth += 1
      end

      def exceeded?
        !exhausted_cap.nil?
      end

      def exhausted_cap
        return :time  if @elapsed_ms  > @time_cap_ms
        return :depth if @depth       > @depth_cap
        return :token if @tokens_used > @token_cap
        nil
      end
    end
  end
end
