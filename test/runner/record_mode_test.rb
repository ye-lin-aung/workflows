require "test_helper"

class Workflows::Runner::RecordModeTest < ActiveSupport::TestCase
  # Records a workflow against a data: URL so the test does not need a
  # running Rails server. Validates MP4 + VTT are produced and non-empty.

  setup do
    @output_dir = Dir.mktmpdir
  end

  teardown do
    FileUtils.rm_rf(@output_dir) if @output_dir && File.directory?(@output_dir)
  end

  test "records a trivial workflow and produces mp4 + vtt" do
    workflow = Workflows::Workflow.new(
      name: "demo/record_smoke",
      title: "demo.record.title",
      description: "demo.record.desc",
      host: "lms",
      persona: "any",
      start_at: "data:text/html;charset=utf-8,<!doctype html><title>T</title><body><h1 data-tour='hero'>Hello</h1><button data-tour='btn' onclick=\"document.querySelector('[data-tour=hero]').textContent='done'\">Press</button>",
      viewport: { width: 800, height: 600 },
      setup: [],
      steps: [
        Workflows::Step.new(caption: "Open", wait_for: { selector: "[data-tour='hero']" }, hold_ms: 200),
        Workflows::Step.new(caption: "Click the button", action: "click", target: "[data-tour='btn']", hold_ms: 200),
        Workflows::Step.new(caption: "See result", assert: { selector: "[data-tour='hero']", contains: "done" })
      ]
    )

    result = Workflows::Runner::RecordMode.new(
      workflow: workflow,
      output_dir: @output_dir,
      navigate_direct: true # bypass Rails URL resolution
    ).run

    assert File.exist?(result[:mp4]), "expected mp4 at #{result[:mp4]}"
    assert File.size(result[:mp4]) > 5_000, "expected mp4 to be non-trivial"
    assert File.exist?(result[:vtt]), "expected vtt at #{result[:vtt]}"
    assert_match /WEBVTT/, File.read(result[:vtt])
    assert_match /Click the button/, File.read(result[:vtt])
  end
end
