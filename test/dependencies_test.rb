require File.expand_path(File.dirname(__FILE__) + "/helper")

class DependenciesTest < Test::Unit::TestCase
  fixtures :monkeys, :dependencies => true

  def test_parent_fixture_was_loaded
    assert monkeys(:george)
  end
  
  def test_dependencies_were_loaded
    assert fruits(:apple)
    assert pirates(:redbeard)
  end
  
  def test_polymoprhic_dependencies_were_not_loaded
    # TODO ?
  end
  
  
end
