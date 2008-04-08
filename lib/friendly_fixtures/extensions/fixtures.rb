
# add the magic label stuff

class Fixtures < YAML::Omap

  # example use:  $LABEL.titleize.downcase
  def interpolate_magic_label string, label
    case string
    when /\$LABEL(\.(\w+))?(\s.*)?/
      "#{$2 ? label.send($2) : label}#{$3}"
    # TODO: this part allows chained method calls
    # when /\$LABEL((\.\w+)+)(\s.*)?/
    #   methods, comment = $1, $3
    #   methods = methods.split('.')
    #   methods.shift # remove empty first element
    #   methods.each do |method|
    #     if label.respond_to?(method)
    #       label = label.send( method )
    #     else
    #       raise "Fixtures error on $LABEL: #{label} ; doesn't respond to :#{method}!"
    #     end
    #   end
    #   label += comment if comment
    else
      string
    end
  end

  # this nastiness is required so that when active_record/fixtures gets loaded after the plugin (during the test suite),
  # the desired behavior will not be clobbered. The idea came from the foxy_fixtures plugin.
  def self.method_added(method)
    if method == :insert_fixtures  # if we're defining the original rails version
      unless method_defined?(:insert_fixtures_without_magic_label)  # if this hasn't been called before
        class_eval do # this will only be done once
          alias_method_chain :insert_fixtures, :magic_label
          alias_method :insert_fixtures, :insert_fixtures_with_magic_label   # alias original as magic
        end
      end
    end
  end


  def insert_fixtures_with_magic_label
    now = ActiveRecord::Base.default_timezone == :utc ? Time.now.utc : Time.now
    now = now.to_s(:db)

    # allow a standard key to be used for doing defaults in YAML
    delete(assoc("DEFAULTS"))

    # track any join tables we need to insert later
    habtm_fixtures = Hash.new do |h, habtm|
      h[habtm] = HabtmFixtures.new(@connection, habtm.options[:join_table], nil, nil)
    end

    each do |label, fixture|
      row = fixture.to_hash

      if model_class && model_class < ActiveRecord::Base
        # fill in timestamp columns if they aren't specified and the model is set to record_timestamps
        if model_class.record_timestamps
          timestamp_column_names.each do |name|
            row[name] = now unless row.key?(name)
          end
        end

        # interpolate the fixture label
        row.each do |key, value|
          # row[key] = label if value == "$LABEL"   #OLD
          row[key] = interpolate_magic_label( value, label ) if value =~ /\$LABEL/  #NEW
        end

        # generate a primary key if necessary
        if has_primary_key_column? && !row.include?(primary_key_name)
          row[primary_key_name] = Fixtures.identify(label)
        end

        # If STI is used, find the correct subclass for association reflection
        reflection_class =
        if row.include?(inheritance_column_name)
          row[inheritance_column_name].constantize rescue model_class
        else
          model_class
        end

        reflection_class.reflect_on_all_associations.each do |association|
          case association.macro
          when :belongs_to
            # Do not replace association name with association foreign key if they are named the same
            fk_name = (association.options[:foreign_key] || "#{association.name}_id").to_s

            if association.name.to_s != fk_name && value = row.delete(association.name.to_s)
              if association.options[:polymorphic]
                if value.sub!(/\s*\(([^\)]*)\)\s*$/, "")
                  #                  target_type = $1  # OLD
                  target_type = interpolate_magic_label($1, label ) #NEW
                  target_type_name = (association.options[:foreign_type] || "#{association.name}_type").to_s

                  # support polymorphic belongs_to as "label (Type)"
                  row[target_type_name] = target_type
                end
              end

              row[fk_name] = Fixtures.identify(value)
            end
          when :has_and_belongs_to_many
            if (targets = row.delete(association.name.to_s))
              targets = targets.is_a?(Array) ? targets : targets.split(/\s*,\s*/)
              join_fixtures = habtm_fixtures[association]

              targets.each do |target|
                join_fixtures["#{label}_#{target}"] = Fixture.new(
                { association.primary_key_name => row[primary_key_name],
                  association.association_foreign_key => Fixtures.identify(target) }, nil)
                end
              end
            end
          end
        end

        @connection.insert_fixture(fixture, @table_name)
      end

      # insert any HABTM join tables we discovered
      habtm_fixtures.values.each do |fixture|
        fixture.delete_existing_fixtures
        fixture.insert_fixtures
      end
    end

  def read_fixture_files
    if File.file?(yaml_file_path)
      # YAML fixtures
      begin
        yaml_string = ""
        Dir["#{@fixture_path}/**/*.yml"].select {|f| test(?f,f) }.each do |subfixture_path|
          yaml_string << IO.read(subfixture_path)
        end
        yaml_string << IO.read(yaml_file_path)

        if yaml = YAML::load(erb_render(yaml_string))
          yaml = yaml.value if yaml.respond_to?(:type_id) and yaml.respond_to?(:value)
          yaml.each do |name, data|
            self[name] = Fixture.new(data, @class_name)
          end
        end
      rescue Exception=>boom
        raise Fixture::FormatError, "a YAML error occured parsing #{yaml_file_path}. Please note that YAML must be consistently indented using spaces. Tabs are not allowed. Please have a look at http://www.yaml.org/faq.html\nThe exact error was:\n  #{boom.class}: #{boom}"
      end
    elsif File.file?(csv_file_path)
      # CSV fixtures
      reader = CSV::Reader.create(erb_render(IO.read(csv_file_path)))
      header = reader.shift
      i = 0
      reader.each do |row|
        data = {}
        # INTERNAUT: Modified the following line for nil values and removed the puts
        row.each_with_index { |cell, j| data[header[j].to_s.strip] = cell.nil? ? cell : cell.to_s.strip }
        self["#{Inflector::underscore(@class_name)}_#{i+=1}"]= Fixture.new(data, @class_name)
      end
    elsif File.file?(deprecated_yaml_file_path)
      raise Fixture::FormatError, ".yml extension required: rename #{deprecated_yaml_file_path} to #{yaml_file_path}"
    else
      # Standard fixtures
      Dir.entries(@fixture_path).each do |file|
        path = File.join(@fixture_path, file)
        if File.file?(path) and file !~ @file_filter
          self[file] = Fixture.new(path, @class_name)
        end
      end
    end
    
  end

end





module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:


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
            model_name = table.classify
            class_eval <<-RUBY
            def test_all_#{table}_are_valid
              #{model_name}.find(:all).each do |obj|
                assert_valid obj
                #assert obj.valid?, obj.to_yaml
              end
            # rescue Exception => e
            #   puts e.inspect
            #   puts "you have an invalid object in table #{table}, and for some unknown reason YAML could not be written to stdout"
            #   puts "ensure that your validations (validates_presence_of) refers to a foreign key and not an association" if e.is_a?(TypeError) && e.message = "wrong argument type nil (expected Data)"
            end
            RUBY
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
  end
end


module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:


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
            model_name = table.classify
            class_eval <<-RUBY
            def test_all_#{table}_are_valid
              #{model_name}.find(:all).each do |obj|
                assert obj.valid?, obj.to_yaml
              end
            rescue Exception => e
              puts e.inspect
              puts "you have an invalid object in table #{table}, and for some unknown reason YAML could not be written to stdout"
              puts "ensure that your validations (validates_presence_of) refers to a foreign key and not an association" if e.is_a?(TypeError) && e.message = "wrong argument type nil (expected Data)"
            end
            RUBY
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
  end
end