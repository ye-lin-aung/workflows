require "test_helper"

class Workflows::Prospect::PromptBuilderTest < ActiveSupport::TestCase
  def question_entry
    Workflows::Prospect::CatalogEntry.new(
      "id" => "admin_create_school", "type" => "question",
      "persona" => "admin_new_marisol",
      "question" => "How do I create a new school?",
      "start_route" => "root_path"
    )
  end

  def scenario_entry
    Workflows::Prospect::CatalogEntry.new(
      "id" => "admin_transfer_student", "type" => "scenario",
      "persona" => "admin_dr_kim",
      "question" => "How do I onboard a transfer student?",
      "start_route" => "admin_dashboard_path",
      "sub_goals" => ["Locate record", "Set prior school"]
    )
  end

  test "system prompt names the persona and question for a simple question" do
    state = Workflows::Prospect::ThreadState.new(entry: question_entry)
    sys = Workflows::Prospect::PromptBuilder.system_prompt(state: state, target_url: "https://x.test")
    assert_match(/admin_new_marisol/, sys)
    assert_match(/How do I create a new school\?/, sys)
    assert_match(%r{https://x\.test}, sys)
  end

  test "system prompt lists sub_goals for a scenario" do
    state = Workflows::Prospect::ThreadState.new(entry: scenario_entry)
    sys = Workflows::Prospect::PromptBuilder.system_prompt(state: state, target_url: "https://x.test")
    assert_match(/Locate record/, sys)
    assert_match(/Set prior school/, sys)
    assert_match(/mark each one done or failed/, sys)
  end

  test "system prompt tells the agent to use not_in_app when appropriate" do
    state = Workflows::Prospect::ThreadState.new(entry: question_entry)
    sys = Workflows::Prospect::PromptBuilder.system_prompt(state: state, target_url: "https://x.test")
    assert_match(/report_missing_feature/, sys)
    assert_match(/not_in_app/, sys)
  end
end
