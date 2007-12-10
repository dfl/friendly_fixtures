module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:

      def self.fixtures(*table_names)

        if table_names.last.is_a? Hash
          opts = table_names.pop
          if opts[:dependencies]
            table_names.map! do |table|
              model_name = table.to_s.classify
              model_class = model_name.constantize
              dependencies = model_class.reflect_on_all_associations.map(&:class_name).map(&:tableize)
              dependencies << table
            end.flatten!.uniq!
          end
          if opts[:validate]
            table_names.each do |table|
              model_name = table.to_s.classify
              class_eval <<-RUBY
              def test_all_#{table}_are_valid
                #{model_name}.find(:all).each do |obj|
                  assert obj.valid?, obj.to_yaml
                end
              end
              RUBY
            end            
          end
          
        end

        # original rails code follows
        table_names = table_names.flatten.map { |n| n.to_s }
        self.fixture_table_names |= table_names
        require_fixture_classes(table_names)
        setup_fixture_accessors(table_names)
      end
    end
  end
end
