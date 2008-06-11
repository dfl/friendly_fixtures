Test::Unit::TestCase.class_eval do

  def self.table_name_to_associations( table )
    model_name   = table.to_s.classify
    model_class  = model_name.constantize
    model_class.reflect_on_all_associations
  end

  def self.fixtures_with_friendliness(*table_args)
    opts = table_args.last.is_a?(Hash) ? table_args.pop : {}

    all_fixtures = Dir[ "#{fixture_path}/*.yml", "#{fixture_path}/*.csv" ].map! { |f| File.basename(f).split('.')[0..-2].join('.') }

    if table_args.first == :all          # from Rails 2.0
      table_names = table_args = all_fixtures
    elsif opts[:dependencies]
      table_names = table_args.map { |table|
        polymorphic, singular = table_name_to_associations( table ).partition{ |a| a.options[:polymorphic] }
        dependencies = singular.map(&:class_name).map(&:tableize) # convert class to table name
        unless polymorphic.empty?
          polymorphic_names = polymorphic.map(&:name)
          # puts "polymorpmhic: #{polymorphic_names.inspect}"
          dependencies << all_fixtures.select do |m|  # find all models with a polymorphic belongs to on this name
            table_name_to_associations( m ).select { |a| polymorphic_names.include?( a.options[:as] ) }.any?
          end
        end
        dependencies << table # don't forget the parent object
        }.flatten.uniq
      else
        table_names = table_args
      end

      table_names = table_names.map(&:to_s) # convert all symbols to strings
      # puts "table_names: #{table_names.inspect}"

      if opts[:validate]
        validations = case opts[:validate]
        when true
          table_args
        when :all
          table_names
        else            
          opts[:validate]
        end
        validations.each do |table|
          table = table.to_s
          raise ArgumentError, "#{table} table was not loaded, but was asked to be validated!" unless table_names.include?( table )
          model = ActiveRecord::Base.const_get( table.classify )
          self.send :define_method, :"test_all_#{table}_are_valid" do
            model.find(:all).each do |obj|
              #assert_valid obj
              assert obj.valid?, obj.to_yaml
            end
          rescue Exception => e
            puts e.inspect
            puts "you have an invalid object in table #{table}, and for some unknown reason YAML could not be written to stdout"
            puts "ensure that your validations (validates_presence_of) refers to a foreign key and not an association" if e.is_a?(TypeError) && e.message = "wrong argument type nil (expected Data)"
          end
        end

        self.fixture_table_names |= table_names
        require_fixture_classes(table_names)
        setup_fixture_accessors(table_names)

      end

      # this nastiness is required so that when active_record/fixtures gets loaded after the plugin (during the test suite),
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
