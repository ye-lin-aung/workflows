require "test_helper"
require "tempfile"
require "tmpdir"

class Workflows::Prospect::ReportWriterTest < ActiveSupport::TestCase
  def simple_entry
    Workflows::Prospect::CatalogEntry.new(
      "id" => "admin_create_school", "type" => "question",
      "group" => "Onboarding",
      "persona" => "admin_new_marisol",
      "question" => "How do I create a new school?",
      "start_route" => "root_path",
      "expected_workflow" => "admin/onboard_school"
    )
  end

  def scenario_entry
    Workflows::Prospect::CatalogEntry.new(
      "id" => "admin_offboard_student", "type" => "scenario",
      "group" => "Admissions",
      "persona" => "admin_dr_kim",
      "question" => "How do I offboard a student?",
      "start_route" => "admin_dashboard_path",
      "sub_goals" => ["Find student", "Mark withdrawn", "Handle grades", "Notify parent"]
    )
  end

  def build_state_with_verdict(entry:, verdict:, summary: "done", suggested_fix: nil)
    s = Workflows::Prospect::ThreadState.new(entry: entry)
    if entry.scenario?
      s.complete_sub_goal(index: 0, notes: "found student")
      s.complete_sub_goal(index: 1, notes: "clicked withdraw")
      s.fail_sub_goal(index: 2, reason: "no grade prompt")
      s.fail_sub_goal(index: 3, reason: "no parent flow")
    end
    s.conclude!(verdict: verdict, summary: summary, suggested_fix: suggested_fix)
    s
  end

  test "writes a report.md for a simple-question thread" do
    Dir.mktmpdir do |dir|
      s = build_state_with_verdict(entry: simple_entry, verdict: :struggle,
                                   summary: "Found via Getting Started card",
                                   suggested_fix: "Redirect admins with no school to onboarding")

      writer = Workflows::Prospect::ReportWriter.new(root_dir: dir, target_url: "http://localhost:3000")
      writer.write_thread(s)

      path = File.join(dir, "admin_create_school", "report.md")
      body = File.read(path)
      assert_match(/How do I create a new school\?/, body)
      assert_match(/Verdict:\*\* .*struggle/, body)
      assert_match(/admin_new_marisol/, body)
      assert_match(/Redirect admins with no school to onboarding/, body)
      assert_match(%r{admin/onboard_school}, body)
    end
  end

  test "writes a scenario report with sub_goal table" do
    Dir.mktmpdir do |dir|
      s = build_state_with_verdict(entry: scenario_entry, verdict: :partial, summary: "halfway")
      writer = Workflows::Prospect::ReportWriter.new(root_dir: dir, target_url: "http://localhost:3000")
      writer.write_thread(s)

      body = File.read(File.join(dir, "admin_offboard_student", "report.md"))
      assert_match(/Sub-goals/, body)
      assert_match(/Find student/, body)
      assert_match(/done/, body)
      assert_match(/failed/, body)
      assert_match(/no parent flow/, body)
    end
  end

  test "writes index.md with grouped rows + missing features summary" do
    Dir.mktmpdir do |dir|
      s1 = build_state_with_verdict(entry: simple_entry, verdict: :struggle, summary: "x")
      s2 = build_state_with_verdict(entry: scenario_entry, verdict: :partial, summary: "y")
      s3 = Workflows::Prospect::ThreadState.new(entry: simple_entry)
      s3.set_missing_feature(feature: "Bulk SMS", evidence: "searched nav",
                             confidence: "high", business_value: "critical alerts")

      writer = Workflows::Prospect::ReportWriter.new(root_dir: dir, target_url: "http://localhost:3000")
      writer.write_thread(s1)
      writer.write_thread(s2)
      writer.write_thread(s3)
      writer.write_index([s1, s2, s3])

      idx = File.read(File.join(dir, "index.md"))
      assert_match(/## Onboarding/, idx)
      assert_match(/## Admissions/, idx)
      assert_match(/Missing features/, idx)
      assert_match(/Bulk SMS/, idx)
      assert_match(/high/, idx)
    end
  end
end
