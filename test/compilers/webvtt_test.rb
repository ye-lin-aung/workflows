require "test_helper"

class Workflows::Compilers::WebvttTest < ActiveSupport::TestCase
  test "emits a valid WEBVTT header" do
    cues = [
      { start_ms: 0,    end_ms: 1500, text: "Open the gradebook" },
      { start_ms: 1500, end_ms: 3000, text: "Click Jordan's row" }
    ]
    vtt = Workflows::Compilers::Webvtt.call(cues)
    assert vtt.start_with?("WEBVTT\n\n")
  end

  test "each cue is formatted HH:MM:SS.mmm --> HH:MM:SS.mmm" do
    cues = [{ start_ms: 1234, end_ms: 5678, text: "Hello" }]
    vtt = Workflows::Compilers::Webvtt.call(cues)
    assert_match %r{00:00:01\.234 --> 00:00:05\.678}, vtt
    assert_match /^Hello$/, vtt
  end

  test "handles longer durations (hours)" do
    cues = [{ start_ms: 3_723_456, end_ms: 3_800_000, text: "Long" }]
    vtt = Workflows::Compilers::Webvtt.call(cues)
    assert_match %r{01:02:03\.456 --> 01:03:20\.000}, vtt
  end

  test "separates cues with blank lines" do
    cues = [
      { start_ms: 0,    end_ms: 1000, text: "One" },
      { start_ms: 1000, end_ms: 2000, text: "Two" }
    ]
    vtt = Workflows::Compilers::Webvtt.call(cues)
    # There must be a blank line between the two cues.
    assert_match /One\n\n00:00:01/, vtt
  end

  test "escapes caption text safely (no VTT special chars remain raw)" do
    cues = [{ start_ms: 0, end_ms: 1000, text: "Click <Save>" }]
    vtt = Workflows::Compilers::Webvtt.call(cues)
    # VTT allows <>, but we want to HTML-escape for safety against future HTML rendering.
    assert_match /&lt;Save&gt;/, vtt
  end
end
