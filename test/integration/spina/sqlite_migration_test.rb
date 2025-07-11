require 'test_helper'

class SpinaRestrictedMigrationTest < ActiveSupport::TestCase
  
  def setup
    # Skip if not SQLite (migration tests only work with SQLite)
    skip "Migration tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
  end

  test "database adapter is SQLite" do
    assert_equal "SQLite", ActiveRecord::Base.connection.adapter_name
  end

  test "jsonb columns are properly converted to json" do
    # Test that json_attributes column exists and works
    resource = Spina::Resource.create!(name: "test", label: "Test Resource")
    
    # Test that we can store JSON data
    resource.json_attributes = { "key" => "value", "nested" => { "data" => "test" } }
    resource.save!
    
    resource.reload
    assert_equal "value", resource.json_attributes["key"]
    assert_equal "test", resource.json_attributes["nested"]["data"]
  end

  test "mobility backend is set to table" do
    # Test that Resource model uses table-based mobility backend
    assert_equal :table, Spina::Resource.mobility_backend.class.name.demodulize.underscore.to_sym
  end

  test "all migrations run successfully" do
    # Get list of all migrations
    migrations = Dir.glob(Rails.root.join("../../db/migrate/*.rb"))
    
    # Ensure we have migrations
    assert migrations.any?, "No migration files found"
    
    # Test that migrations can be run (this tests SQL compatibility)
    assert_nothing_raised do
      ActiveRecord::Migration.check_pending!
    end
  end

  test "FTS tables are created correctly" do
    # Test that FTS tables exist
    assert ActiveRecord::Base.connection.table_exists?("spina_pages_fts"), "Pages FTS table should exist"
    assert ActiveRecord::Base.connection.table_exists?("spina_resources_fts"), "Resources FTS table should exist"
  end

  test "FTS triggers maintain data synchronization" do
    # Test page FTS synchronization
    page = Spina::Page.create!(
      name: "test-fts-page",
      title: "Test FTS Page",
      description: "This is a test page for FTS",
      materialized_path: "/test-fts",
      active: true,
      draft: false
    )
    
    # Check that FTS table was populated
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id}"
    )
    
    assert_equal 1, fts_entries.count, "FTS table should have entry for new page"
    
    # Test resource FTS synchronization
    resource = Spina::Resource.create!(
      name: "test-fts-resource",
      label: "Test FTS Resource"
    )
    
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_resources_fts WHERE resource_id = #{resource.id}"
    )
    
    assert_equal 1, fts_entries.count, "FTS table should have entry for new resource"
    
    # Cleanup
    page.destroy
    resource.destroy
  end

  test "SQL operations work with SQLite" do
    # Test LIKE operations (replacement for ILIKE)
    page = Spina::Page.create!(
      name: "test-search-page",
      title: "Test Search Page",
      description: "This is a test page",
      materialized_path: "/test-search",
      active: true,
      draft: false
    )
    
    # Test case-insensitive search using LOWER/LIKE
    results = Spina::Page.joins(:translations)
      .where("LOWER(spina_page_translations.title) LIKE LOWER(?)", "%search%")
      .distinct
    
    assert_includes results, page
    
    # Test JSON operations
    resource = Spina::Resource.create!(
      name: "test-json-resource",
      label: "Test JSON Resource"
    )
    
    resource.json_attributes = { "search_term" => "findme" }
    resource.save!
    
    # Test REPLACE function (replacement for REGEXP_REPLACE)
    ActiveRecord::Base.connection.execute(
      "UPDATE spina_resources SET json_attributes = REPLACE(json_attributes, 'findme', 'foundyou') WHERE id = #{resource.id}"
    )
    
    resource.reload
    assert_equal "foundyou", resource.json_attributes["search_term"]
    
    # Cleanup
    page.destroy
    resource.destroy
  end

  test "database pragmas are properly configured" do
    # Test that SQLite is configured with proper pragmas
    pragmas = {}
    
    # Check key pragmas
    %w[journal_mode foreign_keys synchronous cache_size temp_store].each do |pragma|
      result = ActiveRecord::Base.connection.execute("PRAGMA #{pragma}")
      pragmas[pragma] = result.first[pragma] if result.any?
    end
    
    # Assert expected configurations (these match Rails 8 defaults)
    assert_equal "wal", pragmas["journal_mode"], "Should use WAL mode"
    assert_equal 1, pragmas["foreign_keys"], "Should have foreign keys enabled"
    assert pragmas["cache_size"].to_i < 0, "Should have negative cache_size (memory-based)"
  end

  test "search functionality works correctly" do
    # Create test data
    page1 = Spina::Page.create!(
      name: "search-test-1",
      title: "SQLite Search Test",
      description: "Testing search functionality",
      materialized_path: "/search-test-1",
      active: true,
      draft: false
    )
    
    page2 = Spina::Page.create!(
      name: "search-test-2",
      title: "Another Page",
      description: "Different content",
      materialized_path: "/search-test-2",
      active: true,
      draft: false
    )
    
    # Test FTS search
    results = Spina::SearchService.search_pages("SQLite")
    assert_includes results, page1
    assert_not_includes results, page2
    
    # Test phrase search
    results = Spina::SearchService.search_pages("search functionality", query_type: :phrase)
    assert_includes results, page1
    
    # Test prefix search
    results = Spina::SearchService.search_pages("SQL", query_type: :prefix)
    assert_includes results, page1
    
    # Cleanup
    page1.destroy
    page2.destroy
  end

  test "data types are compatible with SQLite" do
    # Test various data types that might have been affected by migration
    resource = Spina::Resource.create!(
      name: "datatype-test",
      label: "Data Type Test"
    )
    
    # Test JSON storage
    complex_json = {
      "string" => "test",
      "number" => 42,
      "boolean" => true,
      "null" => nil,
      "array" => [1, 2, 3],
      "object" => { "nested" => "value" }
    }
    
    resource.json_attributes = complex_json
    resource.save!
    
    resource.reload
    assert_equal complex_json["string"], resource.json_attributes["string"]
    assert_equal complex_json["number"], resource.json_attributes["number"]
    assert_equal complex_json["boolean"], resource.json_attributes["boolean"]
    assert_equal complex_json["array"], resource.json_attributes["array"]
    assert_equal complex_json["object"], resource.json_attributes["object"]
    
    # Cleanup
    resource.destroy
  end

  test "performance is acceptable for basic operations" do
    # Create test data
    start_time = Time.current
    
    # Create multiple pages
    pages = []
    20.times do |i|
      pages << Spina::Page.create!(
        name: "perf-test-#{i}",
        title: "Performance Test Page #{i}",
        description: "Testing performance with multiple pages",
        materialized_path: "/perf-test-#{i}",
        active: true,
        draft: false
      )
    end
    
    creation_time = Time.current - start_time
    
    # Test search performance
    search_start = Time.current
    results = Spina::SearchService.search_pages("Performance")
    search_time = Time.current - search_start
    
    # Basic performance assertions (these are generous limits)
    assert creation_time < 5.0, "Creating 20 pages should take less than 5 seconds"
    assert search_time < 1.0, "Search should take less than 1 second"
    assert_equal 20, results.count, "Should find all 20 pages"
    
    # Cleanup
    pages.each(&:destroy)
  end
end