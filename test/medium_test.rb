# frozen_string_literal: true

require "test_helper"

class MediumTest < Minitest::Test
  def test_initialize_with_keyword_args
    medium = WritersRoom::Medium.new(
      id: "novel",
      label: "Novel",
      universal_elements: %w[story characters arcs],
      specific_elements: { "chapters" => { "dir" => "chapters" } },
      scaffolded_dirs: %w[characters chapters],
      workflows: %w[outlining drafting],
      statuses: %w[outline draft final]
    )

    assert_equal :novel, medium.id
    assert_equal "Novel", medium.label
    assert_equal [:story, :characters, :arcs], medium.universal_elements
    assert_equal({ "chapters" => { "dir" => "chapters" } }, medium.specific_elements)
    assert_equal %w[characters chapters], medium.scaffolded_dirs
    assert_equal [:outlining, :drafting], medium.workflows
    assert_equal %w[outline draft final], medium.statuses
  end

  def test_id_coerced_to_symbol
    medium = WritersRoom::Medium.new(id: "novel", label: "Novel")
    assert_equal :novel, medium.id
  end

  def test_universal_elements_coerced_to_symbols
    medium = WritersRoom::Medium.new(
      id: "test",
      label: "Test",
      universal_elements: ["story", "characters"]
    )
    assert_equal [:story, :characters], medium.universal_elements
  end

  def test_workflows_coerced_to_symbols
    medium = WritersRoom::Medium.new(
      id: "test",
      label: "Test",
      workflows: ["drafting", "revision"]
    )
    assert_equal [:drafting, :revision], medium.workflows
  end

  def test_defaults_to_empty_collections
    medium = WritersRoom::Medium.new(id: "bare", label: "Bare")
    assert_equal [], medium.universal_elements
    assert_equal({}, medium.specific_elements)
    assert_equal [], medium.scaffolded_dirs
    assert_equal [], medium.workflows
    assert_equal [], medium.statuses
  end

  def test_from_yaml
    yaml_hash = {
      "id" => "novel",
      "label" => "Novel",
      "universal_elements" => %w[story characters],
      "specific_elements" => { "chapters" => { "dir" => "chapters" } },
      "scaffolded_dirs" => %w[characters chapters],
      "workflows" => %w[outlining drafting],
      "statuses" => %w[outline draft final]
    }

    medium = WritersRoom::Medium.from_yaml(yaml_hash)

    assert_equal :novel, medium.id
    assert_equal "Novel", medium.label
    assert_equal [:story, :characters], medium.universal_elements
    assert_equal %w[characters chapters], medium.scaffolded_dirs
  end

  def test_to_s_returns_label
    medium = WritersRoom::Medium.new(id: "novel", label: "Novel")
    assert_equal "Novel", medium.to_s
  end

  def test_inspect
    medium = WritersRoom::Medium.new(id: "novel", label: "Novel")
    assert_match(/Medium/, medium.inspect)
    assert_match(/:novel/, medium.inspect)
    assert_match(/"Novel"/, medium.inspect)
  end
end
