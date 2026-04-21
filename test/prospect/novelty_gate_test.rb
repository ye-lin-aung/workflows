require "test_helper"

class Workflows::Prospect::NoveltyGateTest < ActiveSupport::TestCase
  test "allows a first question" do
    g = Workflows::Prospect::NoveltyGate.new
    g.record("How do I create a new school?")
    assert g.novel?("What is a term?")
  end

  test "rejects a substring repeat" do
    g = Workflows::Prospect::NoveltyGate.new
    g.record("How do I create a new school?")
    refute g.novel?("How do I create a new school?")
    refute g.novel?("create a new school")
  end

  test "rejects case-insensitive match" do
    g = Workflows::Prospect::NoveltyGate.new
    g.record("How do I check my grades?")
    refute g.novel?("HOW DO I CHECK MY GRADES?")
  end

  test "rejects high-overlap paraphrase" do
    g = Workflows::Prospect::NoveltyGate.new
    g.record("How do I create a new school?")
    refute g.novel?("How do I make a new school")
  end

  test "allows low-overlap related question" do
    g = Workflows::Prospect::NoveltyGate.new
    g.record("How do I create a new school?")
    assert g.novel?("What does term mean in this school setup?")
  end
end
