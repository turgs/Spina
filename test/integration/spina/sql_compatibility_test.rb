require 'test_helper'

class SpinaSqlCompatibilityTest < ActiveSupport::TestCase
  
  def setup
    # Skip if not SQLite (SQL compatibility tests only work with SQLite)
    skip "SQL compatibility tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
  end

  def teardown
    # Clean up any test data
    Spina::Page.where("name LIKE 'sql-test-%'").destroy_all
    Spina::Resource.where("name LIKE 'sql-test-%'").destroy_all
  end

  test "ILIKE replacement with LOWER/LIKE works correctly" do
    # Create test pages with different cases
    page1 = Spina::Page.create!(
      name: "sql-test-case1",
      title: "Testing CASE Sensitivity",
      description: "This is a TEST description",
      materialized_path: "/sql-test-case1",
      active: true,
      draft: false
    )
    
    page2 = Spina::Page.create!(
      name: "sql-test-case2",
      title: "lowercase title",
      description: "lowercase description",
      materialized_path: "/sql-test-case2",
      active: true,
      draft: false
    )
    
    # Test case-insensitive search using LOWER/LIKE (replacement for ILIKE)
    results = Spina::Page.joins(:translations)
      .where("LOWER(spina_page_translations.title) LIKE LOWER(?)", "%case%")
      .distinct
    
    assert_includes results, page1
    assert_not_includes results, page2
    
    # Test description search
    results = Spina::Page.joins(:translations)
      .where("LOWER(spina_page_translations.description) LIKE LOWER(?)", "%test%")
      .distinct
    
    assert_includes results, page1
    assert_not_includes results, page2
    
    # Test that the search is truly case-insensitive
    results = Spina::Page.joins(:translations)
      .where("LOWER(spina_page_translations.title) LIKE LOWER(?)", "%TESTING%")
      .distinct
    
    assert_includes results, page1
    
    results = Spina::Page.joins(:translations)
      .where("LOWER(spina_page_translations.title) LIKE LOWER(?)", "%testing%")
      .distinct
    
    assert_includes results, page1
  end

  test "REPLACE function works for JSON operations" do
    # Create test resource with JSON data
    resource = Spina::Resource.create!(
      name: "sql-test-json",
      label: "SQL Test JSON Resource"
    )
    
    # Set JSON attributes with specific values
    resource.json_attributes = {
      "signed_id" => "old_signed_id_123",
      "content" => "This contains old_signed_id_123 in text",
      "nested" => {
        "id" => "old_signed_id_123",
        "data" => "more old_signed_id_123 here"
      }
    }
    resource.save!
    
    # Test REPLACE function (replacement for REGEXP_REPLACE)
    old_signed_id = "old_signed_id_123"
    new_signed_id = "new_signed_id_456"
    
    # Update using REPLACE function
    ActiveRecord::Base.connection.execute(
      "UPDATE spina_resources SET json_attributes = REPLACE(json_attributes, '#{old_signed_id}', '#{new_signed_id}') WHERE id = #{resource.id}"
    )
    
    # Reload and verify changes
    resource.reload
    json_text = resource.json_attributes.to_json
    
    # Should have replaced all occurrences
    assert_not_includes json_text, old_signed_id
    assert_includes json_text, new_signed_id
    
    # Verify specific replacements
    assert_equal "new_signed_id_456", resource.json_attributes["signed_id"]
    assert_includes resource.json_attributes["content"], "new_signed_id_456"
    assert_equal "new_signed_id_456", resource.json_attributes["nested"]["id"]
    assert_includes resource.json_attributes["nested"]["data"], "new_signed_id_456"
  end

  test "JSON LIKE operations work correctly" do
    # Create resources with different JSON content
    resource1 = Spina::Resource.create!(
      name: "sql-test-like1",
      label: "SQL Test LIKE Resource 1"
    )
    
    resource2 = Spina::Resource.create!(
      name: "sql-test-like2",
      label: "SQL Test LIKE Resource 2"
    )
    
    # Set JSON attributes
    resource1.json_attributes = {
      "content" => "This contains the search term",
      "tags" => ["important", "search", "test"]
    }
    resource1.save!
    
    resource2.json_attributes = {
      "content" => "This does not contain the target",
      "tags" => ["unrelated", "different"]
    }
    resource2.save!
    
    # Test JSON LIKE operations (replacement for json_attributes::text LIKE)
    results = Spina::Resource.where("json_attributes LIKE ?", "%search term%")
    assert_includes results, resource1
    assert_not_includes results, resource2
    
    # Test with different patterns
    results = Spina::Resource.where("json_attributes LIKE ?", "%important%")
    assert_includes results, resource1
    assert_not_includes results, resource2
    
    results = Spina::Resource.where("json_attributes LIKE ?", "%unrelated%")
    assert_not_includes results, resource1
    assert_includes results, resource2
  end

  test "SQLite-specific SQL functions work" do
    # Test sqlite_version function
    result = ActiveRecord::Base.connection.execute("SELECT sqlite_version() AS version")
    assert result.any?
    assert_match(/\d+\.\d+\.\d+/, result.first['version'])
    
    # Test JSON functions
    resource = Spina::Resource.create!(
      name: "sql-test-functions",
      label: "SQL Test Functions Resource"
    )
    
    resource.json_attributes = {
      "key1" => "value1",
      "key2" => "value2",
      "nested" => { "inner" => "data" }
    }
    resource.save!
    
    # Test JSON extraction (SQLite JSON functions)
    result = ActiveRecord::Base.connection.execute(
      "SELECT json_extract(json_attributes, '$.key1') AS extracted FROM spina_resources WHERE id = #{resource.id}"
    )
    
    assert_equal "value1", result.first['extracted']
    
    # Test JSON path existence
    result = ActiveRecord::Base.connection.execute(
      "SELECT json_extract(json_attributes, '$.nested.inner') AS nested_value FROM spina_resources WHERE id = #{resource.id}"
    )
    
    assert_equal "data", result.first['nested_value']
  end

  test "complex SQL queries work with SQLite" do
    # Create test data
    pages = []
    5.times do |i|
      pages << Spina::Page.create!(
        name: "sql-test-complex-#{i}",
        title: "Complex Query Test #{i}",
        description: "Description for page #{i}",
        materialized_path: "/sql-test-complex-#{i}",
        active: i.even?, # Alternate active/inactive
        draft: false
      )
    end
    
    # Test complex JOIN with WHERE clauses
    results = Spina::Page.joins(:translations)
      .where("spina_pages.active = ? AND LOWER(spina_page_translations.title) LIKE LOWER(?)", true, "%complex%")
      .distinct
    
    # Should find only active pages
    active_pages = pages.select { |p| p.active? }
    assert_equal active_pages.count, results.count
    
    # Test subquery
    subquery_results = Spina::Page.where(
      "id IN (SELECT page_id FROM spina_page_translations WHERE LOWER(title) LIKE LOWER(?))",
      "%complex%"
    )
    
    assert_equal pages.count, subquery_results.count
    
    # Test aggregation
    count_result = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) as total FROM spina_pages WHERE active = 1"
    )
    
    assert_equal active_pages.count, count_result.first['total']
  end

  test "database constraints work properly" do
    # Test foreign key constraints (should be enabled)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      # Try to create a page translation with invalid page_id
      ActiveRecord::Base.connection.execute(
        "INSERT INTO spina_page_translations (page_id, locale, title) VALUES (99999, 'en', 'Test')"
      )
    end
  end

  test "database transactions work correctly" do
    initial_count = Spina::Page.count
    
    # Test successful transaction
    ActiveRecord::Base.transaction do
      Spina::Page.create!(
        name: "sql-test-transaction1",
        title: "Transaction Test 1",
        description: "First transaction test",
        materialized_path: "/sql-test-transaction1",
        active: true,
        draft: false
      )
      
      Spina::Page.create!(
        name: "sql-test-transaction2",
        title: "Transaction Test 2", 
        description: "Second transaction test",
        materialized_path: "/sql-test-transaction2",
        active: true,
        draft: false
      )
    end
    
    assert_equal initial_count + 2, Spina::Page.count
    
    # Test rollback transaction
    begin
      ActiveRecord::Base.transaction do
        Spina::Page.create!(
          name: "sql-test-rollback1",
          title: "Rollback Test 1",
          description: "First rollback test",
          materialized_path: "/sql-test-rollback1",
          active: true,
          draft: false
        )
        
        # Force an error to trigger rollback
        raise ActiveRecord::Rollback
      end
    rescue ActiveRecord::Rollback
      # Expected
    end
    
    # Count should remain the same
    assert_equal initial_count + 2, Spina::Page.count
  end

  test "date and time operations work correctly" do
    # Create page with specific timestamp
    page = Spina::Page.create!(
      name: "sql-test-datetime",
      title: "DateTime Test",
      description: "Testing date/time operations",
      materialized_path: "/sql-test-datetime",
      active: true,
      draft: false
    )
    
    # Test date queries
    today = Date.current
    results = Spina::Page.where("DATE(created_at) = ?", today)
    assert_includes results, page
    
    # Test time comparisons
    one_hour_ago = 1.hour.ago
    results = Spina::Page.where("created_at > ?", one_hour_ago)
    assert_includes results, page
    
    # Test SQLite date functions
    result = ActiveRecord::Base.connection.execute(
      "SELECT datetime('now') AS current_time"
    )
    assert result.any?
    assert_match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, result.first['current_time'])
  end

  test "text search operations are case-insensitive" do
    # Create resources with mixed case content
    resource1 = Spina::Resource.create!(
      name: "sql-test-search-upper",
      label: "UPPERCASE LABEL"
    )
    
    resource2 = Spina::Resource.create!(
      name: "sql-test-search-lower",
      label: "lowercase label"
    )
    
    resource3 = Spina::Resource.create!(
      name: "sql-test-search-mixed",
      label: "MiXeD cAsE LaBeL"
    )
    
    # Test case-insensitive search
    results = Spina::Resource.where("LOWER(label) LIKE LOWER(?)", "%label%")
    assert_includes results, resource1
    assert_includes results, resource2
    assert_includes results, resource3
    
    # Test with different search terms
    results = Spina::Resource.where("LOWER(label) LIKE LOWER(?)", "%LABEL%")
    assert_equal 3, results.count
    
    results = Spina::Resource.where("LOWER(label) LIKE LOWER(?)", "%uppercase%")
    assert_includes results, resource1
    assert_equal 1, results.count
  end

  test "JSON operations maintain data integrity" do
    # Create resource with complex JSON
    resource = Spina::Resource.create!(
      name: "sql-test-json-integrity",
      label: "JSON Integrity Test"
    )
    
    complex_json = {
      "string" => "test value",
      "number" => 42,
      "float" => 3.14,
      "boolean" => true,
      "null" => nil,
      "array" => [1, "two", { "three" => 3 }],
      "object" => {
        "nested" => {
          "deeply" => {
            "nested" => "value"
          }
        }
      },
      "special_chars" => "Testing: !@#$%^&*()_+-={}[]|\\:;\"'<>?,./"
    }
    
    resource.json_attributes = complex_json
    resource.save!
    
    # Reload and verify data integrity
    resource.reload
    
    assert_equal complex_json["string"], resource.json_attributes["string"]
    assert_equal complex_json["number"], resource.json_attributes["number"]
    assert_equal complex_json["float"], resource.json_attributes["float"]
    assert_equal complex_json["boolean"], resource.json_attributes["boolean"]
    assert_nil resource.json_attributes["null"]
    assert_equal complex_json["array"], resource.json_attributes["array"]
    assert_equal complex_json["object"], resource.json_attributes["object"]
    assert_equal complex_json["special_chars"], resource.json_attributes["special_chars"]
  end

  test "search performance is acceptable with large datasets" do
    # Create larger dataset
    resources = []
    100.times do |i|
      resources << Spina::Resource.create!(
        name: "sql-test-perf-#{i}",
        label: "Performance Test Resource #{i}"
      )
    end
    
    # Test search performance
    start_time = Time.current
    results = Spina::Resource.where("LOWER(label) LIKE LOWER(?)", "%performance%")
    search_time = Time.current - start_time
    
    assert search_time < 1.0, "Search should be fast even with 100 records"
    assert_equal 100, results.count
    
    # Test more complex search
    start_time = Time.current
    results = Spina::Resource.where("LOWER(name) LIKE LOWER(?) AND LOWER(label) LIKE LOWER(?)", "%perf%", "%test%")
    complex_search_time = Time.current - start_time
    
    assert complex_search_time < 1.0, "Complex search should also be fast"
    assert_equal 100, results.count
  end
end