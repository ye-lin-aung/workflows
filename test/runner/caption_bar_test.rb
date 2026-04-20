require "test_helper"

class Workflows::Runner::CaptionBarTest < ActiveSupport::TestCase
  test "init_script injects the caption bar DOM + styles" do
    js = Workflows::Runner::CaptionBar.init_script
    assert_match /workflow-caption-bar/, js
    assert_match /position:\s*fixed/, js
    assert_match /window\.__workflowSetCaption/, js
  end

  test "update_script returns a JS expression to set caption text" do
    js = Workflows::Runner::CaptionBar.update_script("Hello & goodbye")
    # Caption must be JSON-encoded to survive quotes/special chars when
    # injected as a JS expression.
    assert_match /window\.__workflowSetCaption\("Hello & goodbye"\)/, js
  end

  test "update_script JSON-escapes embedded quotes" do
    js = Workflows::Runner::CaptionBar.update_script(%q{He said "hi"})
    # JSON encoding -> \"hi\" inside a JS string literal
    assert_match /\\"hi\\"/, js
  end
end
