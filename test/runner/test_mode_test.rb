require "test_helper"

class Workflows::Runner::TestModeTest < ActiveSupport::TestCase
  class FakeAdapter
    attr_reader :calls
    def initialize; @calls = []; end
    %i[goto click fill select check uncheck hover upload press].each do |m|
      define_method(m) { |*a| @calls << [m, *a] }
    end
    def text(_)  ; "ok" ; end
    def value(_) ; "ok" ; end
    def wait_for_selector(*a, **k)    ; @calls << [:wait_for_selector, *a, k] ; end
    def wait_for_turbo_frame(*a, **k) ; @calls << [:wait_for_turbo_frame, *a, k] ; end
    def start ; end
    def stop  ; end
  end

  class FakeSystemTest
    attr_reader :host, :port
    def initialize
      @host = "127.0.0.1"
      @port = 3000
    end
    def assertions
      []
    end
  end

  # Minitest 6 no longer ships the `stub` helper from minitest/mock.
  # Replace the singleton method on the given object with one that returns
  # `value`, run the block, then remove the singleton override so the
  # original method (defined on the class) is called again.
  def with_stub(obj, method, value)
    obj.define_singleton_method(method) { |*_args, **_kwargs| value }
    yield
  ensure
    obj.singleton_class.send(:remove_method, method) if obj.singleton_class.method_defined?(method)
  end

  test "raises when persona cannot be resolved" do
    wf = Workflows::YamlLoader.load_file(File.expand_path("../fixtures/workflows/valid_minimal.yml", __dir__))
    Workflows.config.persona_resolver = ->(_k) { nil }
    Workflows.config.sign_in_adapter  = ->(_page, _user) { }

    err = assert_raises(Workflows::Runner::TestMode::PersonaNotFound) do
      runner = Workflows::Runner::TestMode.new("demo/hello")
      with_stub(runner, :build_adapter, FakeAdapter.new) do
        with_stub(runner, :load_workflow, wf) do
          runner.run(FakeSystemTest.new)
        end
      end
    end
    assert_match(/demo_user/, err.message)
  end
end
