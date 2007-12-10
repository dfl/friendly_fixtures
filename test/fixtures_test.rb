require File.expand_path(File.dirname(__FILE__) + "/helper")

class FixturesDependenciesTest < Test::Unit::TestCase
  self.fixture_path = File.dirname(__FILE__) + "/fixtures/yaml"
  self.use_instantiated_fixtures = false

  fixtures :monkeys, :dependencies => true

  def test_dependencies_were_loaded__fruits
    assert fruits(:apple)
  end

  def test_dependencies_were_loaded__pirates
    assert pirates(:redbeard)
  end  

end


class FixturesValidationTest < Test::Unit::TestCase  
  self.fixture_path = File.dirname(__FILE__) + "/fixtures/yaml"
  self.use_instantiated_fixtures = false


  fixtures :monkeys, :dependencies => false, :validate => true

  def test_validation_test_was_created
    assert respond_to?( :validation_test )
  end
  
  alias_method :validation_test, :test_all_monkeys_are_valid
  undef_method :test_all_monkeys_are_valid 


  def test_validation_test_fails_with_bad_fixtures
    begin
      validation_test
    rescue Test::Unit::AssertionFailedError => e
      assert_match /id: "3".+can't be blank/m, e.message
    end
  end

  def test_dependencies_were_not_loaded__fruits
    assert_raises NoMethodError do
      assert fruits(:apple)
    end
  end

  def test_dependencies_were_not_loaded__pirates
    assert_raises NoMethodError do
      assert pirates(:redbeard)
    end
  end

end