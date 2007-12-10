module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:

      def self.fixtures_with_friendliness(*table_names)
        if table_names.first == :all          # from Rails 2.0
          table_names = Dir["#{fixture_path}/*.yml"] + Dir["#{fixture_path}/*.csv"]
          table_names.map! { |f| File.basename(f).split('.')[0..-2].join('.') }
        else
          if table_names.last.is_a? Hash
            opts = table_names.pop
            if opts[:dependencies]
              table_names.map! do |table|
                model_name   = table.to_s.classify
                model_class  = model_name.constantize
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
          table_names = table_names.flatten.map { |n| n.to_s }
        end

        self.fixture_table_names |= table_names
        require_fixture_classes(table_names)
        setup_fixture_accessors(table_names)

      end

      # this nastiness is required so that if active_record/fixtures gets loaded after the plugin (during the test suite),
      # the desired behavior will not be clobbered. The idea came from the foxy_fixtures plugin.
      def self.singleton_method_added(method)
        if method == :fixtures
          class << self
            unless method_defined?(:fixtures_without_friendliness)
              alias_method_chain :fixtures, :friendliness
              self.class_eval{ alias_method :fixtures, :fixtures_with_friendliness }
            end
          end
        end
      end
   
    end
  end
end