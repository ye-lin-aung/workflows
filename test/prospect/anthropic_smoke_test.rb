require "test_helper"
require "anthropic"

module Workflows
  module Prospect
  end
end

class Workflows::Prospect::AnthropicSmokeTest < ActiveSupport::TestCase
  test "anthropic client builds without requiring a real api key" do
    client = Anthropic::Client.new(api_key: "sk-test-not-real")
    assert client
  end

  test "anthropic defines Anthropic::Client" do
    assert defined?(Anthropic::Client)
  end
end
