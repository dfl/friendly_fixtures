class MultipleValidationTest < Test::Unit::TestCase  

  # this statement is the crux of this test
  fixtures :monkeys, :dependencies => true, :validate => :all

  alias_method :validation_test_1, :test_all_pirates_are_valid
  undef_method :test_all_pirates_are_valid 

  alias_method :validation_test_2, :test_all_fruits_are_valid
  undef_method :test_all_fruits_are_valid 

  alias_method :validation_test_3, :test_all_monkeys_are_valid
  undef_method :test_all_monkeys_are_valid 

  def test_validation_tests_were_created
    assert respond_to?( :validation_test_1 )
    assert respond_to?( :validation_test_2 )
    assert respond_to?( :validation_test_3 )
  end

  def test_accessor_methods
    assert respond_to?( :monkeys )
    assert respond_to?( :fruits )
    assert respond_to?( :pirates )
  end


  
end
