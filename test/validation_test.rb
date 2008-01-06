class ValidationTest < Test::Unit::TestCase  

  # this statement is the crux of this test
  fixtures :monkeys, :validate => true #,:dependencies => false (implied)

  def test_accessor_method
    assert respond_to?( :monkeys )
    assert !respond_to?( :fruits )
    assert !respond_to?( :pirates )
  end

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

  
end