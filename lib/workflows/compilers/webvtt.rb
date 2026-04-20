require "cgi"

module Workflows
  module Compilers
    # Emits a WebVTT subtitle document from a list of cues.
    # Each cue is a hash: { start_ms:, end_ms:, text: }.
    # Caption text is HTML-escaped to be safe in HTML5 video players.
    module Webvtt
      module_function

      def call(cues)
        body = cues.map { |c| format_cue(c) }.join("\n")
        "WEBVTT\n\n#{body}"
      end

      def format_cue(cue)
        "#{ts(cue[:start_ms])} --> #{ts(cue[:end_ms])}\n#{CGI.escapeHTML(cue[:text].to_s)}\n"
      end

      def ts(ms)
        hours   = ms / 3_600_000
        minutes = (ms / 60_000) % 60
        seconds = (ms / 1000) % 60
        millis  = ms % 1000
        format("%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
      end
    end
  end
end
