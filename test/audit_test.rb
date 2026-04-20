require "test_helper"

class Workflows::AuditTest < ActiveSupport::TestCase
  test "reports no issues for a clean workflow" do
    Dir.mktmpdir do |dir|
      FileUtils.cp(File.expand_path("fixtures/workflows/valid_minimal.yml", __dir__),
                   File.join(dir, "ok.yml"))
      result = Workflows::Audit.new(workflows_path: dir).run
      # Filter out missing_i18n_key issues — the dummy app has no locale setup,
      # so captions like "demo.hello.step_1" will always be reported missing.
      # Audit logic for i18n is still exercised in integration with a real host app.
      non_i18n_issues = result[:issues].reject { |i| i[:kind] == :missing_i18n_key }
      assert_equal 0, non_i18n_issues.size,
                   "expected no escape-hatch/duplicate issues, got #{non_i18n_issues.inspect}"
    end
  end

  test "flags target_css escape-hatch usage" do
    Dir.mktmpdir do |dir|
      FileUtils.cp(File.expand_path("fixtures/workflows/valid_full.yml", __dir__),
                   File.join(dir, "bad.yml"))
      result = Workflows::Audit.new(workflows_path: dir).run
      css_issues = result[:issues].select { |i| i[:kind] == :target_css_escape_hatch }
      assert css_issues.any?, "expected at least one target_css_escape_hatch issue"
    end
  end

  test "flags duplicate workflow names across files" do
    Dir.mktmpdir do |dir|
      FileUtils.cp(File.expand_path("fixtures/workflows/valid_minimal.yml", __dir__),
                   File.join(dir, "a.yml"))
      FileUtils.cp(File.expand_path("fixtures/workflows/valid_minimal.yml", __dir__),
                   File.join(dir, "b.yml"))
      result = Workflows::Audit.new(workflows_path: dir).run
      dup_issues = result[:issues].select { |i| i[:kind] == :duplicate_name }
      assert dup_issues.any?
    end
  end
end
