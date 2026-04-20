require "test_helper"

class Workflows::Runner::CursorOverlayTest < ActiveSupport::TestCase
  test "init_script injects an SVG cursor and a click ripple helper" do
    js = Workflows::Runner::CursorOverlay.init_script
    assert_match /workflow-cursor/, js
    assert_match /window\.__workflowMoveCursor/, js
    assert_match /window\.__workflowClickRipple/, js
    # Cursor must be above the caption bar layer to remain visible.
    assert_match /z-index:\s*2147483646/, js
  end

  test "move_script returns JS that positions the cursor" do
    js = Workflows::Runner::CursorOverlay.move_script(200, 300)
    assert_match /window\.__workflowMoveCursor\(200, 300\)/, js
  end

  test "ripple_script fires a click ripple at coordinates" do
    js = Workflows::Runner::CursorOverlay.ripple_script(150, 250)
    assert_match /window\.__workflowClickRipple\(150, 250\)/, js
  end
end
