require "test_helper"

class Workflows::Prospect::BudgetTest < ActiveSupport::TestCase
  def default
    Workflows::Prospect::Budget.new(time_cap_ms: 5_000, depth_cap: 3, token_cap: 1_000)
  end

  test "tracks elapsed time and tokens" do
    b = default
    b.record_turn(tokens_used: 100, elapsed_ms_delta: 200)
    b.record_turn(tokens_used: 50,  elapsed_ms_delta: 300)
    assert_equal 150, b.tokens_used
    assert_equal 500, b.elapsed_ms
  end

  test "exceeded? when time cap hit" do
    b = default
    b.record_turn(tokens_used: 0, elapsed_ms_delta: 5_001)
    assert b.exceeded?
    assert_equal :time, b.exhausted_cap
  end

  test "exceeded? when depth cap hit" do
    b = default
    b.incr_depth
    b.incr_depth
    b.incr_depth
    b.incr_depth
    assert b.exceeded?
    assert_equal :depth, b.exhausted_cap
  end

  test "exceeded? when token cap hit" do
    b = default
    b.record_turn(tokens_used: 1_001, elapsed_ms_delta: 0)
    assert b.exceeded?
    assert_equal :token, b.exhausted_cap
  end

  test "not exceeded under all caps" do
    b = default
    b.record_turn(tokens_used: 500, elapsed_ms_delta: 2_500)
    refute b.exceeded?
    assert_nil b.exhausted_cap
  end
end
