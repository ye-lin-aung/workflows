require "test_helper"

class Workflows::Runner::BaseTest < ActiveSupport::TestCase
  class FakeAdapter
    attr_reader :calls, :values

    def initialize
      @calls = []
      @values = {}
    end

    %i[goto click fill select check uncheck hover upload].each do |m|
      define_method(m) { |*args| @calls << [m, *args] }
    end

    def press(selector, key)       ; @calls << [:press, selector, key] ; end
    def text(sel)                  ; @values[sel] || ""                ; end
    def value(sel)                 ; @values[sel] || ""                ; end
    def wait_for_selector(*a, **k)    ; @calls << [:wait_for_selector, *a, k] ; end
    def wait_for_turbo_frame(*a, **k) ; @calls << [:wait_for_turbo_frame, *a, k] ; end
  end

  def fixture_workflow
    Workflows::YamlLoader.load_file(File.expand_path("../fixtures/workflows/valid_full.yml", __dir__))
  end

  test "dispatches every step through the adapter" do
    adapter = FakeAdapter.new
    adapter.instance_variable_set(:@values, { "[data-tour='success']" => "Welcome stranger" })
    Workflows::Runner::Base.new(adapter: adapter).execute(fixture_workflow)
    actions = adapter.calls.map(&:first)
    # Step 1: wait_for.selector
    assert_equal :wait_for_selector, actions[0]
    # Step 2: fill
    assert_equal :fill, actions[1]
    # Step 3: click (target_css escape hatch)
    assert_equal :click, actions[2]
    # Step 4: assert (which is a wait_for_selector with contains)
    assert_equal :wait_for_selector, actions[3]
  end

  test "passes fill value to the adapter" do
    adapter = FakeAdapter.new
    adapter.instance_variable_set(:@values, { "[data-tour='success']" => "Welcome stranger" })
    Workflows::Runner::Base.new(adapter: adapter).execute(fixture_workflow)
    fill_call = adapter.calls.find { |c| c[0] == :fill }
    assert_equal "[data-tour='name-input']", fill_call[1]
    assert_equal "Alice", fill_call[2]
  end

  test "resolves target_css escape hatch into actual adapter call" do
    adapter = FakeAdapter.new
    adapter.instance_variable_set(:@values, { "[data-tour='success']" => "Welcome stranger" })
    Workflows::Runner::Base.new(adapter: adapter).execute(fixture_workflow)
    click_call = adapter.calls.find { |c| c[0] == :click }
    assert_equal ".submit-button", click_call[1]
  end

  test "yields each step to an optional block (record mode uses this)" do
    adapter = FakeAdapter.new
    adapter.instance_variable_set(:@values, { "[data-tour='success']" => "Welcome stranger" })
    seen = []
    Workflows::Runner::Base.new(adapter: adapter).execute(fixture_workflow) do |step, _idx|
      seen << step.caption
    end
    assert_equal 4, seen.size
    assert_equal "demo.full.step_1", seen.first
  end
end
