module SortableTable
  module Shoulda

    def should_sort_by(attribute, options = {}, &block)
      collection       = get_collection_name(options[:collection])
      model_under_test = get_model_under_test(attribute, options[:model_name])

      block  = block || default_sorting_block(model_under_test, attribute)
      action = options[:action] || default_sorting_action

      %w(ascending descending).each do |direction|
        should "sort by #{attribute.to_s} #{direction}" do
          # sanity checks
          assert_attribute_defined(attribute, model_under_test)
          assert_db_records_exist_for(model_under_test)

          # exercise
          action.bind(self).call(attribute.to_s, direction)

          # sanity check
          assert_collection_can_be_tested_for_sorting(collection, attribute)

          # verification
          assert_collection_is_sorted(collection, direction, &block)
        end
      end
    end

    def should_sort_by_attributes(*attributes, &block)
      attributes.each do |attr|
        should_sort_by attr, :action => block
      end
    end

    def should_display_sortable_table_header_for(*valid_sorts)
      valid_sorts.each do |attr|
        should "have a link to sort by #{attr}" do
          assert_select 'a[href*=?]', "sort=#{attr}", true,  
            "link not found to sort by #{attr}. Try adding this to the view: " <<
            "<%= sortable_table_header :name => '#{attr}', :sort => '#{attr}' %>"
        end
      end

      should "not link to any invalid sorting options" do
        assert_select 'a[href*=?]', 'sort=' do |elements|
          sortings = elements.collect {|element|
            element.attributes['href'].match(/sort=([^&]*)/)[1]
          }
          sortings.each {|sorting|
            assert !valid_sorts.include?(sorting), 
              "link found for sortion option which is not in valid list: #{sorting}."
          }
        end
      end
    end

    def should_display_highlighted_sortable_table_header_for column, order = "ascending"
      should "have the #{order} class on the #{column} table header" do
        assert_select('th[class=?]', order) do |tr|
          assert_select 'a[href*=?]', "sort=#{column}"
        end
      end
    end
    
    protected
    
    def get_collection_name(override)
      collection = get_collection_name_from_test_name
      (override || collection).to_sym
    end
    
    def get_collection_name_from_test_name
      collection = self.name.underscore.gsub(/_controller_test/, '')
      collection = remove_namespacing(collection)
    end

    def get_model_under_test(attribute, override)
      if override
        model_name = override
      else
        model_name = if attribute_includes_table?(attribute)
          get_model_from_attribute(attribute)
        else
          get_model_under_test_from_test_name
        end
      end
      model_name.singularize.camelize.constantize
    end
    
    def get_model_under_test_from_test_name
      model_name_from_test_name = self.name.gsub(/ControllerTest/, '')
      remove_namespacing(model_name_from_test_name)
    end
    
    def attribute_includes_table?(attribute)
      attribute.to_s.include?(".")
    end
    
    def get_model_from_attribute(attribute)
      if attribute.is_a?(Hash)
        attribute.values.first.split(".").first
      else
        attribute.split(".").first
      end
    end

    def remove_namespacing(string)
      while string.include?('/')
        string.slice!(0..string.rindex('/')) 
      end
      while string.include?('::')
        string.slice!(0..string.rindex('::')+1) 
      end
      string
    end
    
    def default_sorting_block(model_under_test, attribute)
      block = handle_boolean_attribute(model_under_test, attribute)
      block ||= lambda { |model_instance| model_instance.send(attribute) } 
    end
    
    def handle_boolean_attribute(model_under_test, attribute)
      if attribute_is_boolean?(model_under_test, attribute)
        lambda { |model_instance| model_instance.send(attribute).to_s } 
      end
    end
    
    def attribute_is_boolean?(model_under_test, attribute)
      db_column = model_under_test.columns.select { |each| each.name == attribute.to_s }.first
      db_column && db_column.type == :boolean
    end
    
    def default_sorting_action
      lambda do |sort, direction|
        get :index, :sort => sort, :order => direction
      end
    end
  end
end

module SortableTable
  module ShouldaHelpers
    def assert_db_records_exist_for(model_under_test)
      assert model_under_test.count >= 2,
        "need at least 2 #{model_under_test} records in the db to test sorting"
    end
    
    def assert_collection_can_be_tested_for_sorting(collection, attribute)
      assert_not_nil assigns(collection), 
        "assigns(:#{collection}) is nil"
      assert assigns(collection).size >= 2, 
        "cannot test sorting without at least 2 sortable objects. " <<
        "assigns(:#{collection}) is #{assigns(collection).inspect}"
      values = assigns(collection).collect(&attribute).uniq
      assert values.size >= 2,
             "need at least 2 distinct #{attribute} values to test sorting\n" <<
             "found values: #{values.inspect}"
    end
    
    def assert_collection_is_sorted(collection, direction, &block)
      expected = assigns(collection).sort_by(&block)
      expected = expected.reverse if direction == 'descending'

      assert expected.collect(&block) == assigns(collection).collect(&block), 
        "expected - #{expected.collect(&block).inspect}," <<
        " but was - #{assigns(collection).collect(&block).inspect}"
    end

    def assert_attribute_defined(attribute, model_under_test)
      column = model_under_test.
        columns.
        detect {|column| column.name == attribute.to_s }
      assert_not_nil column, "No such column: #{model_under_test}##{attribute}"
    end
  end
end
 
Test::Unit::TestCase.extend(SortableTable::Shoulda)
Test::Unit::TestCase.send(:include, SortableTable::ShouldaHelpers)
