# test/playwright_smoke_test.rb
require "test_helper"
require "playwright"

class Workflows::PlaywrightSmokeTest < ActiveSupport::TestCase
  test "playwright can launch Chromium and navigate to about:blank" do
    title = nil
    Playwright.create(playwright_cli_executable_path: "npx playwright") do |playwright|
      playwright.chromium.launch(headless: true) do |browser|
        page = browser.new_page
        page.goto("about:blank")
        title = page.title
      end
    end
    assert_equal "", title
  end
end
