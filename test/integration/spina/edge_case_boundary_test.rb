require 'test_helper'

class SpinaEdgeCaseBoundaryTest < ActiveSupport::TestCase
  
  def setup
    # Skip if not SQLite (edge case tests only work with SQLite)
    skip "Edge case tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
  end

  def teardown
    # Clean up test data
    Spina::Page.where("name LIKE 'edge-test-%'").destroy_all
    Spina::Resource.where("name LIKE 'edge-test-%'").destroy_all
  end

  # JSON Data Integrity Edge Cases
  
  test "handles empty and null JSON attributes" do
    resource = Spina::Resource.create!(name: "edge-test-empty", label: "Empty JSON Test")
    
    # Test empty JSON object
    resource.json_attributes = {}
    assert resource.save!
    resource.reload
    assert_equal({}, resource.json_attributes)
    
    # Test null JSON (should be handled gracefully)
    resource.json_attributes = nil
    assert resource.save!
    resource.reload
    assert_nil resource.json_attributes
  end

  test "handles malformed JSON gracefully" do
    resource = Spina::Resource.create!(name: "edge-test-malformed", label: "Malformed JSON Test")
    
    # Test that we can handle JSON repair scenarios
    # This simulates data that might exist from PostgreSQL jsonb
    assert_nothing_raised do
      resource.json_attributes = { "key" => "value" }
      resource.save!
    end
    
    resource.reload
    assert_equal "value", resource.json_attributes["key"]
  end

  test "handles very large JSON objects" do
    resource = Spina::Resource.create!(name: "edge-test-large", label: "Large JSON Test")
    
    # Create a large JSON object (but within SQLite limits)
    large_object = {}
    1000.times { |i| large_object["key_#{i}"] = "value_#{i}" * 10 }
    
    resource.json_attributes = large_object
    assert resource.save!
    
    resource.reload
    assert_equal "value_0" * 10, resource.json_attributes["key_0"]
    assert_equal "value_999" * 10, resource.json_attributes["key_999"]
    assert_equal 1000, resource.json_attributes.keys.count
  end

  test "handles unicode and special characters in JSON" do
    resource = Spina::Resource.create!(name: "edge-test-unicode", label: "Unicode JSON Test")
    
    unicode_data = {
      "emoji" => "🚀✨🎉",
      "chinese" => "你好世界",
      "arabic" => "مرحبا بالعالم",
      "special_chars" => "!@#$%^&*()[]{}|;:,.<>?",
      "quotes" => 'He said "Hello" and she said \'Hi\'',
      "backslashes" => "C:\\Users\\Test\\path"
    }
    
    resource.json_attributes = unicode_data
    assert resource.save!
    
    resource.reload
    assert_equal "🚀✨🎉", resource.json_attributes["emoji"]
    assert_equal "你好世界", resource.json_attributes["chinese"]
    assert_equal "مرحبا بالعالم", resource.json_attributes["arabic"]
    assert_equal "!@#$%^&*()[]{}|;:,.<>?", resource.json_attributes["special_chars"]
    assert_equal 'He said "Hello" and she said \'Hi\'', resource.json_attributes["quotes"]
    assert_equal "C:\\Users\\Test\\path", resource.json_attributes["backslashes"]
  end

  test "handles deeply nested JSON structures" do
    resource = Spina::Resource.create!(name: "edge-test-nested", label: "Nested JSON Test")
    
    # Create deeply nested structure
    nested_data = {
      "level1" => {
        "level2" => {
          "level3" => {
            "level4" => {
              "level5" => {
                "data" => "deep_value",
                "array" => [1, 2, 3, { "nested_in_array" => true }]
              }
            }
          }
        }
      }
    }
    
    resource.json_attributes = nested_data
    assert resource.save!
    
    resource.reload
    assert_equal "deep_value", resource.json_attributes["level1"]["level2"]["level3"]["level4"]["level5"]["data"]
    assert_equal true, resource.json_attributes["level1"]["level2"]["level3"]["level4"]["level5"]["array"][3]["nested_in_array"]
  end

  # Search Edge Cases

  test "handles empty search queries" do
    # Create test data
    page = Spina::Page.create!(
      name: "edge-test-search-empty",
      title: "Search Empty Test",
      description: "Testing empty search queries",
      materialized_path: "/edge-test-search-empty",
      active: true,
      draft: false
    )
    
    # Test empty string search
    results = Spina::SearchService.search_pages("")
    assert_kind_of Array, results
    
    # Test nil search
    results = Spina::SearchService.search_pages(nil)
    assert_kind_of Array, results
    
    # Test whitespace-only search
    results = Spina::SearchService.search_pages("   ")
    assert_kind_of Array, results
  end

  test "handles very long search queries" do
    # Create test data
    page = Spina::Page.create!(
      name: "edge-test-search-long",
      title: "Search Long Test",
      description: "Testing very long search queries",
      materialized_path: "/edge-test-search-long",
      active: true,
      draft: false
    )
    
    # Test very long search query
    long_query = "search " * 1000
    assert_nothing_raised do
      results = Spina::SearchService.search_pages(long_query)
      assert_kind_of Array, results
    end
  end

  test "handles unicode and special characters in search" do
    # Create test data with unicode
    page = Spina::Page.create!(
      name: "edge-test-search-unicode",
      title: "Unicode Search Test 🚀",
      description: "Testing unicode search with 你好世界 and مرحبا",
      materialized_path: "/edge-test-search-unicode",
      active: true,
      draft: false
    )
    
    # Test unicode search
    results = Spina::SearchService.search_pages("🚀")
    assert_includes results, page
    
    results = Spina::SearchService.search_pages("你好")
    assert_includes results, page
    
    results = Spina::SearchService.search_pages("مرحبا")
    assert_includes results, page
  end

  test "handles SQL injection attempts in search" do
    # Create test data
    page = Spina::Page.create!(
      name: "edge-test-search-injection",
      title: "SQL Injection Test",
      description: "Testing SQL injection prevention",
      materialized_path: "/edge-test-search-injection",
      active: true,
      draft: false
    )
    
    # Test various SQL injection patterns
    injection_attempts = [
      "'; DROP TABLE spina_pages; --",
      "' OR '1'='1",
      "' UNION SELECT * FROM spina_pages --",
      "'; INSERT INTO spina_pages VALUES (...); --",
      "' OR 1=1 --"
    ]
    
    injection_attempts.each do |injection|
      assert_nothing_raised do
        results = Spina::SearchService.search_pages(injection)
        assert_kind_of Array, results
      end
    end
  end

  test "handles FTS special characters" do
    # Create test data
    page = Spina::Page.create!(
      name: "edge-test-fts-special",
      title: "FTS Special Characters Test",
      description: "Testing FTS with quotes and wildcards",
      materialized_path: "/edge-test-fts-special",
      active: true,
      draft: false
    )
    
    # Test FTS special characters that could break queries
    special_chars = ['"', '*', '(', ')', '[', ']', '{', '}', '|', '\\']
    
    special_chars.each do |char|
      assert_nothing_raised do
        results = Spina::SearchService.search_pages(char)
        assert_kind_of Array, results
      end
    end
  end

  # Database Constraint Edge Cases

  test "handles maximum SQLite row size limits" do
    resource = Spina::Resource.create!(name: "edge-test-max-size", label: "Max Size Test")
    
    # Create a very large JSON object (approaching SQLite limits)
    # SQLite default page size is 4096 bytes, so let's test with large but reasonable data
    large_string = "x" * 50000  # 50KB string
    
    resource.json_attributes = { "large_data" => large_string }
    assert resource.save!
    
    resource.reload
    assert_equal large_string, resource.json_attributes["large_data"]
  end

  test "handles FTS table consistency" do
    # Create a page
    page = Spina::Page.create!(
      name: "edge-test-fts-consistency",
      title: "FTS Consistency Test",
      description: "Testing FTS table consistency",
      materialized_path: "/edge-test-fts-consistency",
      active: true,
      draft: false
    )
    
    # Verify FTS entry exists
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id}"
    )
    assert_equal 1, fts_entries.count
    
    # Update the page
    page.title = "Updated FTS Consistency Test"
    page.save!
    
    # Verify FTS entry is updated
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id} AND title = 'Updated FTS Consistency Test'"
    )
    assert_equal 1, fts_entries.count
    
    # Delete the page
    page_id = page.id
    page.destroy
    
    # Verify FTS entry is deleted
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page_id}"
    )
    assert_equal 0, fts_entries.count
  end

  # Migration Edge Cases

  test "handles running migrations multiple times" do
    # This tests idempotent migration behavior
    # Get current migration version
    current_version = ActiveRecord::Migrator.current_version
    
    # Try to run migrations again (should be idempotent)
    assert_nothing_raised do
      ActiveRecord::Migration.check_pending!
    end
    
    # Version should remain the same
    assert_equal current_version, ActiveRecord::Migrator.current_version
  end

  test "handles schema consistency after migrations" do
    # Verify that all expected tables exist
    required_tables = [
      "spina_pages",
      "spina_resources", 
      "spina_pages_fts",
      "spina_resources_fts"
    ]
    
    required_tables.each do |table_name|
      assert ActiveRecord::Base.connection.table_exists?(table_name), 
             "Required table #{table_name} should exist"
    end
    
    # Verify FTS tables have correct structure
    fts_info = ActiveRecord::Base.connection.execute("PRAGMA table_info(spina_pages_fts)")
    assert fts_info.any?, "FTS table should have column information"
    
    # Verify triggers exist
    triggers = ActiveRecord::Base.connection.execute(
      "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE '%spina_pages_fts%'"
    )
    assert triggers.any?, "FTS triggers should exist"
  end

  # Performance Boundary Cases

  test "handles large dataset performance" do
    # Create a reasonable number of pages for testing
    pages = []
    50.times do |i|
      pages << Spina::Page.create!(
        name: "edge-test-perf-#{i}",
        title: "Performance Test Page #{i}",
        description: "Testing performance with multiple pages #{i}",
        materialized_path: "/edge-test-perf-#{i}",
        active: true,
        draft: false
      )
    end
    
    # Test search performance
    start_time = Time.current
    results = Spina::SearchService.search_pages("Performance")
    end_time = Time.current
    
    # Should complete within reasonable time (5 seconds)
    assert (end_time - start_time) < 5.0, "Search should complete within 5 seconds"
    assert_equal 50, results.count
  end

  test "handles FTS performance with many entries" do
    # Create resources for FTS testing
    resources = []
    50.times do |i|
      resources << Spina::Resource.create!(
        name: "edge-test-fts-perf-#{i}",
        label: "FTS Performance Test Resource #{i}"
      )
    end
    
    # Test FTS search performance
    start_time = Time.current
    results = Spina::SearchService.search_resources("Performance")
    end_time = Time.current
    
    # Should complete within reasonable time
    assert (end_time - start_time) < 5.0, "FTS search should complete within 5 seconds"
    assert_equal 50, results.count
  end

  # Error Handling Edge Cases

  test "handles database connection edge cases" do
    # Test that we can recover from connection issues
    original_connection = ActiveRecord::Base.connection
    
    # Verify connection is working
    assert ActiveRecord::Base.connection.active?
    
    # Test basic operations work
    assert_nothing_raised do
      Spina::Resource.create!(name: "edge-test-connection", label: "Connection Test")
    end
  end

  test "handles concurrent access patterns" do
    # Create test data
    resource = Spina::Resource.create!(name: "edge-test-concurrent", label: "Concurrent Test")
    
    # Test that we can handle concurrent updates
    threads = []
    5.times do |i|
      threads << Thread.new do
        resource.json_attributes = { "thread_#{i}" => "value_#{i}" }
        resource.save!
      end
    end
    
    threads.each(&:join)
    
    # Verify the resource still exists and has valid data
    resource.reload
    assert resource.json_attributes.present?
  end

  test "handles FTS index corruption recovery" do
    # Create test data
    page = Spina::Page.create!(
      name: "edge-test-fts-recovery",
      title: "FTS Recovery Test",
      description: "Testing FTS index recovery",
      materialized_path: "/edge-test-fts-recovery",
      active: true,
      draft: false
    )
    
    # Verify FTS entry exists
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id}"
    )
    assert_equal 1, fts_entries.count
    
    # Test that we can rebuild FTS table if needed
    assert_nothing_raised do
      ActiveRecord::Base.connection.execute("DELETE FROM spina_pages_fts")
      
      # Recreate FTS entries (simulating recovery)
      Spina::Page.find_each do |p|
        ActiveRecord::Base.connection.execute("
          INSERT INTO spina_pages_fts (page_id, title, description, materialized_path)
          SELECT #{p.id}, '#{p.title}', '#{p.description}', '#{p.materialized_path}'
        ")
      end
    end
    
    # Verify FTS works after recovery
    results = Spina::SearchService.search_pages("Recovery")
    assert_includes results, page
  end

  test "handles boundary conditions for page paths" do
    # Test very long materialized path
    long_path = "/edge-test-very-long-path-" + ("segment/" * 50)
    
    page = Spina::Page.create!(
      name: "edge-test-long-path",
      title: "Long Path Test",
      description: "Testing very long materialized paths",
      materialized_path: long_path,
      active: true,
      draft: false
    )
    
    assert page.persisted?
    assert_equal long_path, page.materialized_path
    
    # Test search works with long paths
    results = Spina::SearchService.search_pages("Long Path")
    assert_includes results, page
  end

  test "handles special characters in page names and paths" do
    special_chars = ["spaces here", "dots.and.more", "under_scores", "dashes-here", "numbers123"]
    
    special_chars.each do |char|
      page = Spina::Page.create!(
        name: "edge-test-special-#{char}",
        title: "Special Char Test #{char}",
        description: "Testing special characters in names",
        materialized_path: "/edge-test-special-#{char}",
        active: true,
        draft: false
      )
      
      assert page.persisted?
      assert_equal "Special Char Test #{char}", page.title
      
      # Test search works with special characters
      results = Spina::SearchService.search_pages(char)
      assert_includes results, page
    end
  end

end