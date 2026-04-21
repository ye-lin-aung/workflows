module Workflows
  module Prospect
    class NoveltyGate
      OVERLAP_RATIO = 0.6
      STOPWORDS = %w[how do i a the is it an of to for my in on you your i'd].freeze

      def initialize
        @history = []
      end

      def record(question)
        @history << question.to_s.downcase.strip
      end

      def novel?(candidate)
        cand = candidate.to_s.downcase.strip
        return false if cand.empty?

        @history.none? do |prior|
          return true if prior.empty?
          cand.include?(prior) || prior.include?(cand) || high_overlap?(cand, prior)
        end
      end

      private

      def high_overlap?(a, b)
        ta = tokens(a)
        tb = tokens(b)
        return false if ta.empty? || tb.empty?
        shared = (ta & tb).size
        denom = [ta.size, tb.size].min
        (shared.to_f / denom) >= OVERLAP_RATIO
      end

      def tokens(str)
        str.scan(/\w+/).map(&:downcase) - STOPWORDS
      end
    end
  end
end
