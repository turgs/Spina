require 'test_helper'

class SpinaSearchServiceTest < ActiveSupport::TestCase
  include Spina::Engine.routes.url_helpers
  
  def setup
    # Skip if not SQLite (FTS tests only work with SQLite)
    skip "FTS tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
    
    # Create test pages
    @page1 = Spina::Page.create!(
      name: "test-page-1",
      title: "Welcome to Spina CMS",
      description: "Content management system for developers",
      materialized_path: "/welcome",
      active: true,
      draft: false
    )
    
    @page2 = Spina::Page.create!(
      name: "test-page-2", 
      title: "About Our Company",
      description: "Learn more about our content management solutions",
      materialized_path: "/about",
      active: true,
      draft: false
    )
    
    # Create test resource
    @resource = Spina::Resource.create!(
      name: "blog",
      label: "Blog Posts"
    )
  end
  
  def teardown
    # Clean up test data
    Spina::Page.where(name: ["test-page-1", "test-page-2"]).destroy_all
    Spina::Resource.where(name: "blog").destroy_all
  end
  
  test "search_pages returns pages matching query" do
    results = Spina::SearchService.search_pages("spina")
    
    assert_includes results, @page1
    assert_not_includes results, @page2
  end
  
  test "search_pages with phrase query" do
    results = Spina::SearchService.search_pages("content management", query_type: :phrase)
    
    assert_includes results, @page1
    assert_includes results, @page2
  end
  
  test "search_pages with prefix query" do
    results = Spina::SearchService.search_pages("comp", query_type: :prefix)
    
    assert_includes results, @page2
    assert_not_includes results, @page1
  end
  
  test "search_resources returns resources matching query" do
    results = Spina::SearchService.search_resources("blog")
    
    assert_includes results, @resource
  end
  
  test "search_pages with filters" do
    results = Spina::SearchService.search_pages("about", active_only: true)
    
    assert_includes results, @page2
  end
  
  test "search_snippets highlights search terms" do
    content = "This is a test about content management systems"
    query = "content management"
    
    result = Spina::SearchService.search_snippets(query, content)
    
    assert_includes result, "<mark>content</mark>"
    assert_includes result, "<mark>management</mark>"
  end
  
  test "empty query returns no results" do
    results = Spina::SearchService.search_pages("")
    
    assert_empty results
  end
  
  test "sqlite_fts_available detects FTS support" do
    # This is a private method, but we can test it via the public interface
    results = Spina::SearchService.search_pages("test")
    
    # Should not raise error if FTS is available
    assert_respond_to results, :each
  end
end