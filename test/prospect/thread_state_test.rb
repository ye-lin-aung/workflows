require "test_helper"

class Workflows::Prospect::ThreadStateTest < ActiveSupport::TestCase
  def entry(type = "question")
    Workflows::Prospect::CatalogEntry.new(
      "id" => "test", "type" => type, "persona" => "admin_dr_kim",
      "question" => "q", "start_route" => "root_path",
      "sub_goals" => (type == "scenario" ? ["goal a", "goal b"] : [])
    )
  end

  test "initializes pending sub_goals for scenarios" do
    s = Workflows::Prospect::ThreadState.new(entry: entry("scenario"))
    assert_equal 2, s.sub_goals.size
    s.sub_goals.each { |sg| assert_equal :pending, sg[:status] }
  end

  test "no sub_goals for simple questions" do
    s = Workflows::Prospect::ThreadState.new(entry: entry("question"))
    assert_equal [], s.sub_goals
  end

  test "complete_sub_goal marks status done with notes" do
    s = Workflows::Prospect::ThreadState.new(entry: entry("scenario"))
    s.complete_sub_goal(index: 0, notes: "done")
    assert_equal :done, s.sub_goals.first[:status]
    assert_equal "done", s.sub_goals.first[:notes]
  end

  test "fail_sub_goal marks status failed with reason" do
    s = Workflows::Prospect::ThreadState.new(entry: entry("scenario"))
    s.fail_sub_goal(index: 1, reason: "no UI found")
    assert_equal :failed, s.sub_goals[1][:status]
    assert_equal "no UI found", s.sub_goals[1][:notes]
  end

  test "derived_verdict for scenarios" do
    s = Workflows::Prospect::ThreadState.new(entry: entry("scenario"))
    assert_equal :stuck, s.derived_verdict
    s.complete_sub_goal(index: 0, notes: "ok")
    assert_equal :stuck, s.derived_verdict
    s.complete_sub_goal(index: 1, notes: "ok")
    assert_equal :complete, s.derived_verdict
  end

  test "derived_verdict partial when some done some failed" do
    s = Workflows::Prospect::ThreadState.new(entry: entry("scenario"))
    s.complete_sub_goal(index: 0, notes: "ok")
    s.fail_sub_goal(index: 1, reason: "x")
    assert_equal :partial, s.derived_verdict
  end

  test "record_breadcrumb appends with turn_no + summary + url" do
    s = Workflows::Prospect::ThreadState.new(entry: entry)
    s.record_breadcrumb(summary: "clicked Save", url: "/teach/gradebook")
    b = s.breadcrumbs.first
    assert_equal 1, b[:turn_no]
    assert_equal "clicked Save", b[:summary]
    assert_equal "/teach/gradebook", b[:url]
  end

  test "record_turn increments turn count" do
    s = Workflows::Prospect::ThreadState.new(entry: entry)
    assert_equal 0, s.turn_count
    s.record_turn
    s.record_turn
    assert_equal 2, s.turn_count
  end

  test "set_missing_feature stamps verdict not_in_app" do
    s = Workflows::Prospect::ThreadState.new(entry: entry)
    s.set_missing_feature(feature: "Bulk SMS", evidence: "searched", confidence: "high", business_value: "...")
    assert_equal :not_in_app, s.verdict
    assert_equal "Bulk SMS", s.missing_feature[:feature]
  end

  test "conclude! stamps verdict and summary when not already set" do
    s = Workflows::Prospect::ThreadState.new(entry: entry)
    s.conclude!(verdict: :easy, summary: "found via nav", suggested_fix: nil)
    assert_equal :easy, s.verdict
    assert_equal "found via nav", s.summary
    assert s.concluded?
  end
end
