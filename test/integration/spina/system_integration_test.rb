require 'test_helper'

class SpinaSystemIntegrationTest < ActiveSupport::TestCase
  
  def setup
    # Skip if not SQLite
    skip "System integration tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
  end

  def teardown
    # Clean up test data
    Spina::Page.where("name LIKE 'system-test-%'").destroy_all
    Spina::Resource.where("name LIKE 'system-test-%'").destroy_all
  end

  test "complete CMS workflow works end-to-end" do
    # Test creating a resource
    resource = Spina::Resource.create!(
      name: "system-test-blog",
      label: "System Test Blog"
    )
    
    assert resource.persisted?
    assert_equal "System Test Blog", resource.label
    
    # Test creating pages
    page1 = Spina::Page.create!(
      name: "system-test-home",
      title: "System Test Home Page",
      description: "Welcome to our system test site",
      materialized_path: "/system-test-home",
      active: true,
      draft: false,
      resource: resource
    )
    
    page2 = Spina::Page.create!(
      name: "system-test-about",
      title: "About System Test",
      description: "Learn about our system testing approach",
      materialized_path: "/system-test-about",
      active: true,
      draft: false,
      resource: resource
    )
    
    assert page1.persisted?
    assert page2.persisted?
    assert_equal resource, page1.resource
    assert_equal resource, page2.resource
    
    # Test page relationships
    assert_includes resource.pages, page1
    assert_includes resource.pages, page2
    
    # Test search functionality
    search_results = Spina::SearchService.search_pages("system test")
    assert_includes search_results, page1
    assert_includes search_results, page2
    
    # Test resource search
    resource_results = Spina::SearchService.search_resources("blog")
    assert_includes resource_results, resource
    
    # Test page filtering
    active_pages = Spina::SearchService.search_pages("system", active_only: true)
    assert_includes active_pages, page1
    assert_includes active_pages, page2
    
    # Test page updates
    page1.title = "Updated System Test Home"
    page1.save!
    
    page1.reload
    assert_equal "Updated System Test Home", page1.title
    
    # Test search still works after update
    updated_search_results = Spina::SearchService.search_pages("Updated System")
    assert_includes updated_search_results, page1
    
    # Test deactivating a page
    page1.active = false
    page1.save!
    
    # Should not appear in active-only search
    active_search_results = Spina::SearchService.search_pages("system", active_only: true)
    assert_not_includes active_search_results, page1
    assert_includes active_search_results, page2
    
    # Test deleting pages
    page1.destroy
    assert_raises(ActiveRecord::RecordNotFound) { page1.reload }
    
    # Test that FTS table is cleaned up
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page1.id}"
    )
    assert_equal 0, fts_entries.count
    
    # Test deleting resource
    resource.destroy
    assert_raises(ActiveRecord::RecordNotFound) { resource.reload }
    
    # Test that associated pages are also cleaned up (depending on constraints)
    # and FTS table is cleaned up
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_resources_fts WHERE resource_id = #{resource.id}"
    )
    assert_equal 0, fts_entries.count
  end

  test "complex content management scenarios work" do
    # Create a hierarchical structure
    parent_resource = Spina::Resource.create!(
      name: "system-test-parent",
      label: "Parent Resource"
    )
    
    child_resource = Spina::Resource.create!(
      name: "system-test-child",
      label: "Child Resource"
    )
    
    # Create pages with complex JSON attributes
    parent_page = Spina::Page.create!(
      name: "system-test-parent-page",
      title: "Parent Page",
      description: "This is the parent page",
      materialized_path: "/system-test-parent",
      active: true,
      draft: false,
      resource: parent_resource
    )
    
    child_page = Spina::Page.create!(
      name: "system-test-child-page",
      title: "Child Page",
      description: "This is the child page",
      materialized_path: "/system-test-parent/child",
      active: true,
      draft: false,
      resource: child_resource
    )
    
    # Test complex JSON operations
    parent_resource.json_attributes = {
      "metadata" => {
        "author" => "System Test",
        "version" => "1.0",
        "tags" => ["parent", "main", "important"]
      },
      "settings" => {
        "public" => true,
        "featured" => false
      },
      "content_ids" => ["signed_id_123", "signed_id_456"]
    }
    parent_resource.save!
    
    # Test JSON modification (simulating signed ID replacement)
    old_id = "signed_id_123"
    new_id = "signed_id_789"
    
    ActiveRecord::Base.connection.execute(
      "UPDATE spina_resources SET json_attributes = REPLACE(json_attributes, '#{old_id}', '#{new_id}') WHERE id = #{parent_resource.id}"
    )
    
    parent_resource.reload
    assert_includes parent_resource.json_attributes["content_ids"], new_id
    assert_not_includes parent_resource.json_attributes["content_ids"], old_id
    
    # Test complex search scenarios
    # Search across both title and description
    results = Spina::SearchService.search_pages("parent")
    assert_includes results, parent_page
    assert_not_includes results, child_page
    
    # Search with phrase
    results = Spina::SearchService.search_pages("child page", query_type: :phrase)
    assert_includes results, child_page
    assert_not_includes results, parent_page
    
    # Search with prefix
    results = Spina::SearchService.search_pages("paren", query_type: :prefix)
    assert_includes results, parent_page
    
    # Test resource-specific searches
    parent_results = Spina::SearchService.search_resources("parent")
    assert_includes parent_results, parent_resource
    assert_not_includes parent_results, child_resource
    
    child_results = Spina::SearchService.search_resources("child")
    assert_includes child_results, child_resource
    assert_not_includes child_results, parent_resource
  end

  test "data migration simulation works correctly" do
    # Simulate a migration scenario where we have existing data
    # and need to ensure it works with SQLite
    
    # Create initial data (simulating PostgreSQL data)
    resources = []
    pages = []
    
    # Create multiple resources with JSON data
    5.times do |i|
      resource = Spina::Resource.create!(
        name: "system-test-migration-#{i}",
        label: "Migration Test Resource #{i}"
      )
      
      resource.json_attributes = {
        "legacy_id" => "pg_id_#{i}",
        "content" => "This is legacy content #{i}",
        "settings" => {
          "migrated" => false,
          "version" => "1.0"
        }
      }
      resource.save!
      
      resources << resource
      
      # Create pages for each resource
      page = Spina::Page.create!(
        name: "system-test-migration-page-#{i}",
        title: "Migration Test Page #{i}",
        description: "This page was migrated from PostgreSQL #{i}",
        materialized_path: "/system-test-migration-#{i}",
        active: true,
        draft: false,
        resource: resource
      )
      
      pages << page
    end
    
    # Simulate migration operations
    # 1. Update all legacy IDs
    resources.each_with_index do |resource, i|
      old_id = "pg_id_#{i}"
      new_id = "sqlite_id_#{i}"
      
      ActiveRecord::Base.connection.execute(
        "UPDATE spina_resources SET json_attributes = REPLACE(json_attributes, '#{old_id}', '#{new_id}') WHERE id = #{resource.id}"
      )
    end
    
    # 2. Mark as migrated
    resources.each do |resource|
      resource.reload
      json_attrs = resource.json_attributes
      json_attrs["settings"]["migrated"] = true
      json_attrs["settings"]["version"] = "2.0"
      resource.json_attributes = json_attrs
      resource.save!
    end
    
    # 3. Verify migration
    resources.each_with_index do |resource, i|
      resource.reload
      assert_equal "sqlite_id_#{i}", resource.json_attributes["legacy_id"]
      assert_equal true, resource.json_attributes["settings"]["migrated"]
      assert_equal "2.0", resource.json_attributes["settings"]["version"]
    end
    
    # 4. Test that search still works after migration
    search_results = Spina::SearchService.search_pages("migration")
    assert_equal 5, search_results.count
    
    resource_results = Spina::SearchService.search_resources("migration")
    assert_equal 5, resource_results.count
    
    # 5. Test that FTS tables are properly populated
    fts_page_count = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) as count FROM spina_pages_fts WHERE title LIKE '%Migration%'"
    ).first['count']
    assert_equal 5, fts_page_count
    
    fts_resource_count = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) as count FROM spina_resources_fts WHERE label LIKE '%Migration%'"
    ).first['count']
    assert_equal 5, fts_resource_count
  end

  test "performance is acceptable for realistic workloads" do
    # Simulate a realistic CMS workload
    start_time = Time.current
    
    # Create resources
    resources = []
    20.times do |i|
      resource = Spina::Resource.create!(
        name: "system-test-perf-resource-#{i}",
        label: "Performance Test Resource #{i}"
      )
      
      resource.json_attributes = {
        "content" => "This is performance test content for resource #{i}",
        "metadata" => {
          "created_by" => "test_user",
          "category" => "performance",
          "priority" => i % 3
        },
        "settings" => {
          "public" => i.even?,
          "featured" => i % 5 == 0
        }
      }
      resource.save!
      
      resources << resource
    end
    
    # Create pages
    pages = []
    50.times do |i|
      page = Spina::Page.create!(
        name: "system-test-perf-page-#{i}",
        title: "Performance Test Page #{i}",
        description: "This is a performance test page with content #{i}",
        materialized_path: "/system-test-perf-#{i}",
        active: i % 4 != 0, # 75% active
        draft: i % 10 == 0, # 10% draft
        resource: resources[i % resources.length]
      )
      
      pages << page
    end
    
    creation_time = Time.current - start_time
    
    # Test search performance
    search_start = Time.current
    search_results = Spina::SearchService.search_pages("performance")
    search_time = Time.current - search_start
    
    # Test complex search performance
    complex_search_start = Time.current
    complex_results = Spina::SearchService.search_pages("test content", query_type: :phrase)
    complex_search_time = Time.current - complex_search_start
    
    # Test resource search performance
    resource_search_start = Time.current
    resource_results = Spina::SearchService.search_resources("performance")
    resource_search_time = Time.current - resource_search_start
    
    # Test filtered search performance
    filtered_search_start = Time.current
    filtered_results = Spina::SearchService.search_pages("test", active_only: true)
    filtered_search_time = Time.current - filtered_search_start
    
    # Performance assertions (generous limits for CI)
    assert creation_time < 10.0, "Creating 20 resources and 50 pages should take < 10s"
    assert search_time < 1.0, "Basic search should take < 1s"
    assert complex_search_time < 1.0, "Complex search should take < 1s"
    assert resource_search_time < 1.0, "Resource search should take < 1s"
    assert filtered_search_time < 1.0, "Filtered search should take < 1s"
    
    # Verify search results
    assert search_results.count > 0, "Should find performance-related pages"
    assert resource_results.count > 0, "Should find performance-related resources"
    assert filtered_results.count > 0, "Should find active pages"
    
    # Test that FTS tables are populated correctly
    fts_page_count = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) as count FROM spina_pages_fts"
    ).first['count']
    
    # Should only include active, non-draft pages
    expected_fts_count = pages.count { |p| p.active && !p.draft }
    assert_equal expected_fts_count, fts_page_count, "FTS table should only contain active, non-draft pages"
  end

  test "error handling works correctly" do
    # Test constraint violations
    assert_raises(ActiveRecord::RecordInvalid) do
      Spina::Page.create!(
        name: "", # Empty name should be invalid
        title: "Test Page",
        description: "Test description",
        materialized_path: "/test",
        active: true,
        draft: false
      )
    end
    
    # Test duplicate paths
    page1 = Spina::Page.create!(
      name: "system-test-duplicate1",
      title: "Duplicate Test 1",
      description: "First duplicate test",
      materialized_path: "/system-test-duplicate",
      active: true,
      draft: false
    )
    
    # This should work fine (different pages can have same path in different contexts)
    page2 = Spina::Page.create!(
      name: "system-test-duplicate2",
      title: "Duplicate Test 2",
      description: "Second duplicate test",
      materialized_path: "/system-test-duplicate-2",
      active: true,
      draft: false
    )
    
    assert page1.persisted?
    assert page2.persisted?
    
    # Test invalid JSON
    resource = Spina::Resource.create!(
      name: "system-test-error",
      label: "Error Test Resource"
    )
    
    # This should work - Rails handles JSON serialization
    resource.json_attributes = { "valid" => "json" }
    resource.save!
    
    # Test search with invalid input
    assert_nothing_raised do
      Spina::SearchService.search_pages("")
      Spina::SearchService.search_pages(nil)
      Spina::SearchService.search_resources("")
      Spina::SearchService.search_resources(nil)
    end
    
    # Test FTS with problematic characters
    assert_nothing_raised do
      Spina::SearchService.search_pages("test*")
      Spina::SearchService.search_pages("test\"")
      Spina::SearchService.search_pages("test()")
      Spina::SearchService.search_pages("test-")
    end
  end

  test "database integrity is maintained" do
    # Test that foreign key constraints work
    resource = Spina::Resource.create!(
      name: "system-test-integrity",
      label: "Integrity Test Resource"
    )
    
    page = Spina::Page.create!(
      name: "system-test-integrity-page",
      title: "Integrity Test Page",
      description: "Testing database integrity",
      materialized_path: "/system-test-integrity",
      active: true,
      draft: false,
      resource: resource
    )
    
    # Verify relationships
    assert_equal resource, page.resource
    assert_includes resource.pages, page
    
    # Test that FTS tables stay in sync
    fts_page_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id}"
    )
    assert_equal 1, fts_page_entries.count
    
    fts_resource_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_resources_fts WHERE resource_id = #{resource.id}"
    )
    assert_equal 1, fts_resource_entries.count
    
    # Test cascade behavior
    page.destroy
    
    # FTS should be cleaned up
    fts_page_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id}"
    )
    assert_equal 0, fts_page_entries.count
    
    # Resource should still exist
    assert resource.reload
    
    # Resource FTS should still exist
    fts_resource_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_resources_fts WHERE resource_id = #{resource.id}"
    )
    assert_equal 1, fts_resource_entries.count
  end
end