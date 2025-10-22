# frozen_string_literal: true

require "test_helper"

class WritersRoomTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil WritersRoom::VERSION
  end

  def test_error_class_is_defined
    assert_kind_of Class, WritersRoom::Error
    assert_operator WritersRoom::Error, :<, StandardError
  end

  def test_wr_shortcut_constant
    assert_equal WritersRoom, WR
  end

  def test_wr_shortcut_provides_access_to_constants
    assert_equal WritersRoom::VERSION, WR::VERSION
    assert_equal WritersRoom::Error, WR::Error
  end
end
