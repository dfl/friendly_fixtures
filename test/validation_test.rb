class ValidationTest < Test::Unit::TestCase  
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
      assert pirates(:redbeard)
    end
  end

end