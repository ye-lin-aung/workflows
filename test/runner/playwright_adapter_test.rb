require "test_helper"
require "erb"

class Workflows::Runner::PlaywrightAdapterTest < ActiveSupport::TestCase
  # These tests actually launch Chromium. They are slower than unit tests but
  # exercise the adapter's real dispatch paths against a trivial HTML harness.

  def html_page(body)
    <<~HTML
      <!doctype html>
      <html><body>
        #{body}
      </body></html>
    HTML
  end

  def with_adapter
    adapter = Workflows::Runner::PlaywrightAdapter.new
    adapter.start
    yield adapter
  ensure
    adapter&.stop
  end

  test "navigates to a data URL and returns page title" do
    with_adapter do |a|
      a.goto("data:text/html;charset=utf-8," + ERB::Util.url_encode(html_page("<title>Hi</title><h1>ok</h1>")))
      assert_equal "Hi", a.title
    end
  end

  test "clicks a target selector" do
    with_adapter do |a|
      a.goto("data:text/html;charset=utf-8," + ERB::Util.url_encode(html_page(<<~HTML)))
        <button data-tour="x" onclick="this.textContent='clicked'">press</button>
      HTML
      a.click("[data-tour='x']")
      assert_equal "clicked", a.text("[data-tour='x']")
    end
  end

  test "fills a form input" do
    with_adapter do |a|
      a.goto("data:text/html;charset=utf-8," + ERB::Util.url_encode(html_page(<<~HTML)))
        <input data-tour="n" value="">
      HTML
      a.fill("[data-tour='n']", "hello")
      assert_equal "hello", a.value("[data-tour='n']")
    end
  end

  test "wait_for_selector returns when the selector appears" do
    with_adapter do |a|
      a.goto("data:text/html;charset=utf-8," + ERB::Util.url_encode(html_page(<<~HTML)))
        <div id="delayed"></div>
        <script>setTimeout(() => document.querySelector('#delayed').textContent = 'here', 100)</script>
      HTML
      a.wait_for_selector("#delayed", contains: "here", timeout_ms: 2000)
      assert_equal "here", a.text("#delayed")
    end
  end
end
