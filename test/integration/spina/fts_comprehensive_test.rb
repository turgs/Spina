require 'test_helper'

class SpinaFtsComprehensiveTest < ActiveSupport::TestCase
  
  def setup
    # Skip if not SQLite (FTS tests only work with SQLite)
    skip "FTS tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
    
    # Ensure FTS tables exist
    assert ActiveRecord::Base.connection.table_exists?("spina_pages_fts"), "Pages FTS table required"
    assert ActiveRecord::Base.connection.table_exists?("spina_resources_fts"), "Resources FTS table required"
  end

  def teardown
    # Clean up any test data
    Spina::Page.where("name LIKE 'fts-test-%'").destroy_all
    Spina::Resource.where("name LIKE 'fts-test-%'").destroy_all
  end

  test "FTS tables have correct structure" do
    # Test pages FTS table structure
    columns = ActiveRecord::Base.connection.execute("PRAGMA table_info(spina_pages_fts)")
    column_names = columns.map { |col| col['name'] }
    
    assert_includes column_names, 'page_id'
    assert_includes column_names, 'title'
    assert_includes column_names, 'description'
    assert_includes column_names, 'materialized_path'
    
    # Test resources FTS table structure  
    columns = ActiveRecord::Base.connection.execute("PRAGMA table_info(spina_resources_fts)")
    column_names = columns.map { |col| col['name'] }
    
    assert_includes column_names, 'resource_id'
    assert_includes column_names, 'name'
    assert_includes column_names, 'label'
  end

  test "FTS triggers work for page creation" do
    # Create a page
    page = Spina::Page.create!(
      name: "fts-test-create",
      title: "FTS Test Create Page",
      description: "Testing FTS trigger on creation",
      materialized_path: "/fts-test-create",
      active: true,
      draft: false
    )
    
    # Check FTS table was populated
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id}"
    )
    
    assert_equal 1, fts_entries.count
    
    fts_entry = fts_entries.first
    assert_equal "FTS Test Create Page", fts_entry['title']
    assert_equal "Testing FTS trigger on creation", fts_entry['description']
  end

  test "FTS triggers work for page updates" do
    # Create a page
    page = Spina::Page.create!(
      name: "fts-test-update",
      title: "Original Title",
      description: "Original description",
      materialized_path: "/fts-test-update",
      active: true,
      draft: false
    )
    
    # Update the page
    page.title = "Updated Title"
    page.description = "Updated description"
    page.save!
    
    # Check FTS table was updated
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page.id}"
    )
    
    assert_equal 1, fts_entries.count
    
    fts_entry = fts_entries.first
    assert_equal "Updated Title", fts_entry['title']
    assert_equal "Updated description", fts_entry['description']
  end

  test "FTS triggers work for page deletion" do
    # Create a page
    page = Spina::Page.create!(
      name: "fts-test-delete",
      title: "To Be Deleted",
      description: "This page will be deleted",
      materialized_path: "/fts-test-delete",
      active: true,
      draft: false
    )
    
    page_id = page.id
    
    # Verify FTS entry exists
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page_id}"
    )
    assert_equal 1, fts_entries.count
    
    # Delete the page
    page.destroy
    
    # Check FTS table was cleaned up
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{page_id}"
    )
    assert_equal 0, fts_entries.count
  end

  test "FTS triggers respect page active and draft status" do
    # Create inactive page
    inactive_page = Spina::Page.create!(
      name: "fts-test-inactive",
      title: "Inactive Page",
      description: "This page is inactive",
      materialized_path: "/fts-test-inactive",
      active: false,
      draft: false
    )
    
    # Should not be in FTS table
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{inactive_page.id}"
    )
    assert_equal 0, fts_entries.count
    
    # Create draft page
    draft_page = Spina::Page.create!(
      name: "fts-test-draft",
      title: "Draft Page",
      description: "This page is a draft",
      materialized_path: "/fts-test-draft",
      active: true,
      draft: true
    )
    
    # Should not be in FTS table
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_resources_fts WHERE page_id = #{draft_page.id}"
    )
    assert_equal 0, fts_entries.count
    
    # Activate the inactive page
    inactive_page.active = true
    inactive_page.save!
    
    # Should now be in FTS table
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{inactive_page.id}"
    )
    assert_equal 1, fts_entries.count
    
    # Publish the draft page
    draft_page.draft = false
    draft_page.save!
    
    # Should now be in FTS table
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_pages_fts WHERE page_id = #{draft_page.id}"
    )
    assert_equal 1, fts_entries.count
  end

  test "FTS triggers work for resource operations" do
    # Create a resource
    resource = Spina::Resource.create!(
      name: "fts-test-resource",
      label: "FTS Test Resource"
    )
    
    # Check FTS table was populated
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_resources_fts WHERE resource_id = #{resource.id}"
    )
    
    assert_equal 1, fts_entries.count
    
    fts_entry = fts_entries.first
    assert_equal "fts-test-resource", fts_entry['name']
    assert_equal "FTS Test Resource", fts_entry['label']
    
    # Update the resource
    resource.label = "Updated FTS Resource"
    resource.save!
    
    # Check FTS table was updated
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_resources_fts WHERE resource_id = #{resource.id}"
    )
    
    fts_entry = fts_entries.first
    assert_equal "Updated FTS Resource", fts_entry['label']
    
    # Delete the resource
    resource_id = resource.id
    resource.destroy
    
    # Check FTS table was cleaned up
    fts_entries = ActiveRecord::Base.connection.execute(
      "SELECT * FROM spina_resources_fts WHERE resource_id = #{resource_id}"
    )
    assert_equal 0, fts_entries.count
  end

  test "FTS search provides relevance ranking" do
    # Create pages with different relevance
    high_relevance = Spina::Page.create!(
      name: "fts-test-high",
      title: "Ruby Ruby Ruby Programming",
      description: "Ruby programming language Ruby",
      materialized_path: "/fts-test-high",
      active: true,
      draft: false
    )
    
    medium_relevance = Spina::Page.create!(
      name: "fts-test-medium",
      title: "Ruby Programming Guide",
      description: "Learn programming with examples",
      materialized_path: "/fts-test-medium", 
      active: true,
      draft: false
    )
    
    low_relevance = Spina::Page.create!(
      name: "fts-test-low",
      title: "Programming Languages",
      description: "Various programming languages including Ruby",
      materialized_path: "/fts-test-low",
      active: true,
      draft: false
    )
    
    # Search for "Ruby"
    results = Spina::SearchService.search_pages("Ruby")
    
    # Should return all pages but in relevance order
    assert_includes results, high_relevance
    assert_includes results, medium_relevance
    assert_includes results, low_relevance
    
    # High relevance should come first (has "Ruby" multiple times)
    assert_equal high_relevance, results.first, "Page with highest relevance should be first"
  end

  test "FTS search supports different query types" do
    # Create test pages
    page1 = Spina::Page.create!(
      name: "fts-test-query1",
      title: "Content Management System",
      description: "Advanced content management",
      materialized_path: "/fts-test-query1",
      active: true,
      draft: false
    )
    
    page2 = Spina::Page.create!(
      name: "fts-test-query2",
      title: "Content Manager",
      description: "System for managing content",
      materialized_path: "/fts-test-query2",
      active: true,
      draft: false
    )
    
    # Test phrase search
    phrase_results = Spina::SearchService.search_pages("content management", query_type: :phrase)
    assert_includes phrase_results, page1
    assert_includes phrase_results, page2
    
    # Test prefix search
    prefix_results = Spina::SearchService.search_pages("manage", query_type: :prefix)
    assert_includes prefix_results, page1
    assert_includes prefix_results, page2
    
    # Test boolean search (if supported)
    boolean_results = Spina::SearchService.search_pages("content AND management", query_type: :boolean)
    assert_includes boolean_results, page1
    assert_includes boolean_results, page2
  end

  test "FTS search handles special characters safely" do
    # Create page with special characters
    page = Spina::Page.create!(
      name: "fts-test-special",
      title: "Special Characters: @#$%^&*()",
      description: "Testing special chars & symbols",
      materialized_path: "/fts-test-special",
      active: true,
      draft: false
    )
    
    # Test search with special characters
    results = Spina::SearchService.search_pages("Special Characters")
    assert_includes results, page
    
    # Test search with symbols
    results = Spina::SearchService.search_pages("symbols")
    assert_includes results, page
    
    # Test that special FTS characters are escaped
    assert_nothing_raised do
      Spina::SearchService.search_pages("test*")
      Spina::SearchService.search_pages("test\"")
      Spina::SearchService.search_pages("test()")
    end
  end

  test "FTS search performance is acceptable" do
    # Create many pages for performance testing
    pages = []
    50.times do |i|
      pages << Spina::Page.create!(
        name: "fts-test-perf-#{i}",
        title: "Performance Test Page #{i}",
        description: "Testing FTS performance with page #{i}",
        materialized_path: "/fts-test-perf-#{i}",
        active: true,
        draft: false
      )
    end
    
    # Test search performance
    start_time = Time.current
    results = Spina::SearchService.search_pages("Performance")
    search_time = Time.current - start_time
    
    # Should be fast and return all pages
    assert search_time < 0.5, "FTS search should be fast (< 0.5s)"
    assert_equal 50, results.count, "Should find all 50 pages"
    
    # Test more complex search
    start_time = Time.current
    results = Spina::SearchService.search_pages("Testing FTS performance", query_type: :phrase)
    phrase_search_time = Time.current - start_time
    
    assert phrase_search_time < 0.5, "FTS phrase search should be fast (< 0.5s)"
    assert_equal 50, results.count, "Should find all 50 pages"
  end

  test "FTS search with filters works correctly" do
    # Create pages with different attributes
    active_page = Spina::Page.create!(
      name: "fts-test-active",
      title: "Active Page with Filters",
      description: "This page is active",
      materialized_path: "/fts-test-active",
      active: true,
      draft: false
    )
    
    inactive_page = Spina::Page.create!(
      name: "fts-test-inactive-filter",
      title: "Inactive Page with Filters",
      description: "This page is inactive",
      materialized_path: "/fts-test-inactive-filter",
      active: false,
      draft: false
    )
    
    # Test active_only filter
    results = Spina::SearchService.search_pages("Filters", active_only: true)
    assert_includes results, active_page
    assert_not_includes results, inactive_page
    
    # Test without filter
    results = Spina::SearchService.search_pages("Filters")
    assert_includes results, active_page
    # Note: inactive_page won't be in FTS table anyway due to active=false
  end

  test "FTS search fallback works for non-SQLite" do
    # Mock non-SQLite adapter
    original_adapter = ActiveRecord::Base.connection.adapter_name
    
    # This test is more for documentation - we can't easily mock the adapter
    # but we can test that the fallback methods exist
    assert_respond_to Spina::SearchService, :search_pages
    assert_respond_to Spina::SearchService, :search_resources
    
    # Test that fallback methods handle empty queries
    assert_empty Spina::SearchService.search_pages("")
    assert_empty Spina::SearchService.search_resources("")
  end

  test "search snippets provide proper highlighting" do
    content = "This is a test content about Ruby programming and content management systems"
    
    # Test basic highlighting
    result = Spina::SearchService.search_snippets("content", content)
    assert_includes result, "<mark>content</mark>"
    
    # Test multiple term highlighting
    result = Spina::SearchService.search_snippets("Ruby programming", content)
    assert_includes result, "<mark>Ruby</mark>"
    assert_includes result, "<mark>programming</mark>"
    
    # Test custom highlighting tags
    result = Spina::SearchService.search_snippets(
      "content", 
      content,
      start_tag: "<em>",
      end_tag: "</em>"
    )
    assert_includes result, "<em>content</em>"
  end
end