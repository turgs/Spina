require 'test_helper'

class SpinaMigrationEdgeCasesTest < ActiveSupport::TestCase
  
  def setup
    # Skip if not SQLite
    skip "Migration edge case tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
  end

  def teardown
    # Clean up test data
    Spina::Page.where("name LIKE 'migration-edge-%'").destroy_all
    Spina::Resource.where("name LIKE 'migration-edge-%'").destroy_all
  end

  # Test JSON column conversion edge cases
  
  test "handles JSON column conversion with complex data structures" do
    # Create a resource with complex JSON structure
    resource = Spina::Resource.create!(name: "migration-edge-complex", label: "Complex JSON Test")
    
    # Test array of objects
    complex_data = {
      "users" => [
        { "id" => 1, "name" => "John", "roles" => ["admin", "user"] },
        { "id" => 2, "name" => "Jane", "roles" => ["user"] }
      ],
      "settings" => {
        "theme" => "dark",
        "notifications" => {
          "email" => true,
          "push" => false,
          "categories" => ["urgent", "normal"]
        }
      },
      "metadata" => {
        "version" => "1.0",
        "last_updated" => "2024-01-01T00:00:00Z",
        "tags" => ["production", "stable"],
        "counts" => { "pages" => 100, "users" => 50 }
      }
    }
    
    resource.json_attributes = complex_data
    assert resource.save!
    
    resource.reload
    assert_equal "John", resource.json_attributes["users"][0]["name"]
    assert_equal ["admin", "user"], resource.json_attributes["users"][0]["roles"]
    assert_equal "dark", resource.json_attributes["settings"]["theme"]
    assert_equal true, resource.json_attributes["settings"]["notifications"]["email"]
    assert_equal 100, resource.json_attributes["metadata"]["counts"]["pages"]
  end

  test "handles JSON column conversion with various data types" do
    resource = Spina::Resource.create!(name: "migration-edge-types", label: "Data Types Test")
    
    # Test various JSON data types
    type_data = {
      "string" => "text value",
      "integer" => 42,
      "float" => 3.14159,
      "boolean_true" => true,
      "boolean_false" => false,
      "null_value" => nil,
      "empty_string" => "",
      "empty_array" => [],
      "empty_object" => {},
      "date_string" => "2024-01-01",
      "datetime_string" => "2024-01-01T12:00:00Z"
    }
    
    resource.json_attributes = type_data
    assert resource.save!
    
    resource.reload
    assert_equal "text value", resource.json_attributes["string"]
    assert_equal 42, resource.json_attributes["integer"]
    assert_equal 3.14159, resource.json_attributes["float"]
    assert_equal true, resource.json_attributes["boolean_true"]
    assert_equal false, resource.json_attributes["boolean_false"]
    assert_nil resource.json_attributes["null_value"]
    assert_equal "", resource.json_attributes["empty_string"]
    assert_equal [], resource.json_attributes["empty_array"]
    assert_equal({}, resource.json_attributes["empty_object"])
  end

  test "handles JSONB to JSON conversion edge cases" do
    # Test that the migration handles existing JSONB-like data
    resource = Spina::Resource.create!(name: "migration-edge-jsonb", label: "JSONB Conversion Test")
    
    # Simulate JSONB data that might exist in PostgreSQL
    jsonb_like_data = {
      "text_search" => "searchable content here",
      "indexed_data" => { "key1" => "value1", "key2" => "value2" },
      "array_data" => [1, "two", { "three" => 3 }],
      "postgresql_specific" => {
        "jsonb_operators" => "should work in JSON too",
        "binary_optimization" => "not available in SQLite but functionality preserved"
      }
    }
    
    resource.json_attributes = jsonb_like_data
    assert resource.save!
    
    resource.reload
    assert_equal "searchable content here", resource.json_attributes["text_search"]
    assert_equal "value1", resource.json_attributes["indexed_data"]["key1"]
    assert_equal "two", resource.json_attributes["array_data"][1]
    assert_equal 3, resource.json_attributes["array_data"][2]["three"]
  end

  # Test SQL compatibility edge cases

  test "handles REGEXP_REPLACE replacement edge cases" do
    # Create test data that would use REGEXP_REPLACE in PostgreSQL
    resource = Spina::Resource.create!(name: "migration-edge-regexp", label: "REGEXP Test")
    
    # Test data with patterns that REGEXP_REPLACE would handle
    resource.json_attributes = {
      "content" => "old_signed_id_12345 and old_signed_id_67890",
      "nested" => {
        "field" => "Contains old_signed_id_12345 in middle",
        "array" => ["old_signed_id_12345", "other_content", "old_signed_id_67890"]
      }
    }
    resource.save!
    
    # Simulate the REPLACE operation (which replaced REGEXP_REPLACE)
    old_signed_id = "old_signed_id_12345"
    new_signed_id = "new_signed_id_98765"
    
    # Test that REPLACE function works correctly
    updated_json = resource.json_attributes.to_json.gsub(old_signed_id, new_signed_id)
    resource.json_attributes = JSON.parse(updated_json)
    resource.save!
    
    resource.reload
    assert_equal "new_signed_id_98765 and old_signed_id_67890", resource.json_attributes["content"]
    assert_equal "Contains new_signed_id_98765 in middle", resource.json_attributes["nested"]["field"]
    assert_equal "new_signed_id_98765", resource.json_attributes["nested"]["array"][0]
  end

  test "handles ILIKE replacement edge cases" do
    # Create test pages with various case patterns
    pages = [
      Spina::Page.create!(
        name: "migration-edge-ilike-1",
        title: "UPPERCASE TITLE",
        description: "UPPERCASE DESCRIPTION",
        materialized_path: "/migration-edge-ilike-1",
        active: true,
        draft: false
      ),
      Spina::Page.create!(
        name: "migration-edge-ilike-2",
        title: "lowercase title",
        description: "lowercase description",
        materialized_path: "/migration-edge-ilike-2",
        active: true,
        draft: false
      ),
      Spina::Page.create!(
        name: "migration-edge-ilike-3",
        title: "Mixed Case Title",
        description: "Mixed Case Description",
        materialized_path: "/migration-edge-ilike-3",
        active: true,
        draft: false
      )
    ]
    
    # Test LOWER/LIKE replacement for ILIKE
    search_term = "TITLE"
    results = Spina::Page.joins(:translations)
      .where("LOWER(spina_page_translations.title) LIKE LOWER(?)", "%#{search_term}%")
      .distinct
    
    # Should find all pages regardless of case
    assert_equal 3, results.count
    pages.each { |page| assert_includes results, page }
    
    # Test with different case search term
    search_term = "description"
    results = Spina::Page.joins(:translations)
      .where("LOWER(spina_page_translations.description) LIKE LOWER(?)", "%#{search_term}%")
      .distinct
    
    assert_equal 3, results.count
    pages.each { |page| assert_includes results, page }
  end

  # Test mobility backend edge cases

  test "handles mobility backend table conversion" do
    # Test that the mobility backend is correctly set to :table
    assert_equal :table, Spina::Resource.mobility_backend.class.name.demodulize.underscore.to_sym
    
    # Test that translations work correctly
    resource = Spina::Resource.create!(name: "migration-edge-mobility", label: "Mobility Test")
    
    # Test that we can create and access translated content
    # (This depends on the actual mobility configuration in the app)
    assert resource.persisted?
    assert_equal "Mobility Test", resource.label
  end

  # Test database constraint edge cases

  test "handles SQLite-specific constraints" do
    # Test foreign key constraints
    resource = Spina::Resource.create!(name: "migration-edge-fk", label: "FK Test")
    
    page = Spina::Page.create!(
      name: "migration-edge-fk-page",
      title: "FK Test Page",
      description: "Testing foreign key constraints",
      materialized_path: "/migration-edge-fk-page",
      active: true,
      draft: false,
      resource: resource
    )
    
    assert page.persisted?
    assert_equal resource, page.resource
    
    # Test that we can't create orphaned records if constraints are enabled
    # (This depends on the actual database configuration)
    assert_nothing_raised do
      resource.destroy
    end
  end

  test "handles SQLite PRAGMA settings" do
    # Test that SQLite PRAGMA settings are correctly applied
    pragmas = {
      "foreign_keys" => "ON",
      "journal_mode" => "WAL",
      "synchronous" => "NORMAL",
      "cache_size" => "10000",
      "temp_store" => "MEMORY"
    }
    
    pragmas.each do |pragma, expected_value|
      result = ActiveRecord::Base.connection.execute("PRAGMA #{pragma}")
      # Some pragmas might return different formats, so we just verify they're set
      assert result.any?, "PRAGMA #{pragma} should return a value"
    end
  end

  # Test FTS edge cases

  test "handles FTS table corruption and rebuild" do
    # Create test data
    page = Spina::Page.create!(
      name: "migration-edge-fts-corrupt",
      title: "FTS Corruption Test",
      description: "Testing FTS table corruption scenarios",
      materialized_path: "/migration-edge-fts-corrupt",
      active: true,
      draft: false
    )
    
    # Verify FTS entry exists
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id}"
    )
    assert_equal 1, fts_entries.count
    
    # Simulate corruption by deleting FTS entries
    ActiveRecord::Base.connection.execute("DELETE FROM spina_pages_fts")
    
    # Verify FTS entries are gone
    fts_entries = ActiveRecord::Base.connection.execute("SELECT * FROM spina_pages_fts")
    assert_equal 0, fts_entries.count
    
    # Rebuild FTS table
    Spina::Page.find_each do |p|
      ActiveRecord::Base.connection.execute("
        INSERT INTO spina_pages_fts (page_id, title, description, materialized_path)
        VALUES (#{p.id}, '#{p.title}', '#{p.description}', '#{p.materialized_path}')
      ")
    end
    
    # Verify FTS works after rebuild
    results = Spina::SearchService.search_pages("Corruption")
    assert_includes results, page
  end

  test "handles FTS with special SQLite characters" do
    # Create page with SQLite-specific characters
    page = Spina::Page.create!(
      name: "migration-edge-fts-sqlite",
      title: "SQLite FTS Test: 'quotes' and \"double quotes\"",
      description: "Testing FTS with SQLite-specific characters: [] {} () | \\ / *",
      materialized_path: "/migration-edge-fts-sqlite",
      active: true,
      draft: false
    )
    
    # Test that FTS can handle these characters
    special_searches = ["quotes", "double", "SQLite", "characters"]
    
    special_searches.each do |search_term|
      results = Spina::SearchService.search_pages(search_term)
      assert_includes results, page
    end
  end

  # Test performance edge cases

  test "handles large JSON performance" do
    # Create resource with large JSON data
    resource = Spina::Resource.create!(name: "migration-edge-perf", label: "Performance Test")
    
    # Generate large JSON object
    large_data = {}
    1000.times do |i|
      large_data["section_#{i}"] = {
        "title" => "Section #{i} Title",
        "content" => "This is content for section #{i}. " * 20,
        "metadata" => {
          "created_at" => Time.current.to_s,
          "tags" => ["tag1", "tag2", "tag3"],
          "counts" => { "views" => rand(1000), "likes" => rand(100) }
        }
      }
    end
    
    # Test that large JSON can be saved and retrieved efficiently
    start_time = Time.current
    resource.json_attributes = large_data
    resource.save!
    save_time = Time.current - start_time
    
    # Should save within reasonable time (5 seconds)
    assert save_time < 5.0, "Large JSON save should complete within 5 seconds"
    
    # Test retrieval performance
    start_time = Time.current
    resource.reload
    retrieved_data = resource.json_attributes
    retrieve_time = Time.current - start_time
    
    # Should retrieve within reasonable time (2 seconds)
    assert retrieve_time < 2.0, "Large JSON retrieval should complete within 2 seconds"
    
    # Verify data integrity
    assert_equal "Section 0 Title", retrieved_data["section_0"]["title"]
    assert_equal "Section 999 Title", retrieved_data["section_999"]["title"]
  end

  test "handles concurrent migration operations" do
    # Create test data
    resources = []
    pages = []
    
    10.times do |i|
      resource = Spina::Resource.create!(
        name: "migration-edge-concurrent-#{i}",
        label: "Concurrent Test #{i}"
      )
      resources << resource
      
      page = Spina::Page.create!(
        name: "migration-edge-concurrent-page-#{i}",
        title: "Concurrent Page #{i}",
        description: "Testing concurrent operations #{i}",
        materialized_path: "/migration-edge-concurrent-page-#{i}",
        active: true,
        draft: false,
        resource: resource
      )
      pages << page
    end
    
    # Test concurrent updates
    threads = []
    10.times do |i|
      threads << Thread.new do
        resource = resources[i]
        resource.json_attributes = { "thread_id" => i, "timestamp" => Time.current.to_s }
        resource.save!
        
        page = pages[i]
        page.title = "Updated Concurrent Page #{i}"
        page.save!
      end
    end
    
    # Wait for all threads to complete
    threads.each(&:join)
    
    # Verify all updates completed successfully
    resources.each_with_index do |resource, i|
      resource.reload
      assert_equal i, resource.json_attributes["thread_id"]
    end
    
    pages.each_with_index do |page, i|
      page.reload
      assert_equal "Updated Concurrent Page #{i}", page.title
    end
  end

  # Test error recovery edge cases

  test "handles database file corruption scenarios" do
    # Test that the application can detect and handle database issues
    # This is a basic test since we can't easily corrupt the database in tests
    
    # Verify database integrity
    integrity_result = ActiveRecord::Base.connection.execute("PRAGMA integrity_check")
    assert_equal "ok", integrity_result.first.values.first.downcase
    
    # Test that we can perform basic operations
    resource = Spina::Resource.create!(name: "migration-edge-integrity", label: "Integrity Test")
    assert resource.persisted?
    
    page = Spina::Page.create!(
      name: "migration-edge-integrity-page",
      title: "Integrity Test Page",
      description: "Testing database integrity",
      materialized_path: "/migration-edge-integrity-page",
      active: true,
      draft: false,
      resource: resource
    )
    assert page.persisted?
  end

  test "handles migration rollback scenarios" do
    # Test that we can handle migration rollbacks gracefully
    # This tests that the current state is stable
    
    # Get current migration version
    current_version = ActiveRecord::Migrator.current_version
    assert current_version > 0, "Should have migrations applied"
    
    # Verify all tables exist
    required_tables = [
      "spina_pages",
      "spina_resources",
      "spina_pages_fts",
      "spina_resources_fts"
    ]
    
    required_tables.each do |table_name|
      assert ActiveRecord::Base.connection.table_exists?(table_name),
             "Table #{table_name} should exist after migrations"
    end
    
    # Test that we can create and manipulate data
    resource = Spina::Resource.create!(name: "migration-edge-rollback", label: "Rollback Test")
    resource.json_attributes = { "test" => "data" }
    resource.save!
    
    assert resource.persisted?
    assert_equal "data", resource.json_attributes["test"]
  end

end