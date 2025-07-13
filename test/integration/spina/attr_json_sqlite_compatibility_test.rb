require 'test_helper'

class AttrJsonSqliteCompatibilityTest < ActiveSupport::TestCase
  
  def setup
    # Skip if not SQLite
    skip "AttrJson compatibility tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
    
    # Create test models for AttrJson testing
    setup_test_models
  end

  def setup_test_models
    # Create temporary tables for testing
    ActiveRecord::Migration.create_table :test_attr_json_pages, force: true do |t|
      t.string :title
      t.json :json_attributes
      t.timestamps
    end
    
    ActiveRecord::Migration.create_table :test_attr_json_accounts, force: true do |t|
      t.string :name
      t.json :json_attributes
      t.timestamps
    end
    
    # Define test models
    unless defined?(TestAttrJsonPage)
      Object.const_set(:TestTextPart, Class.new do
        include AttrJson::Model
        attr_json_config(unknown_key: :strip)
        attr_json :name, :string
        attr_json :content, :string, default: ""
      end)
      
      Object.const_set(:TestImagePart, Class.new do
        include AttrJson::Model
        attr_json_config(unknown_key: :strip)
        attr_json :name, :string
        attr_json :image_id, :integer, default: nil
        attr_json :alt, :string, default: ""
        attr_json :filename, :string, default: ""
      end)
      
      Object.const_set(:TestAttrJsonPage, Class.new(ActiveRecord::Base) do
        self.table_name = "test_attr_json_pages"
        include AttrJson::Record
        include AttrJson::NestedAttributes
        
        attr_json :simple_text, :string
        attr_json :simple_integer, :integer
        attr_json :text_part, TestTextPart.to_type
        attr_json :image_part, TestImagePart.to_type
        attr_json :text_parts, TestTextPart.to_type, array: true
        
        attr_json_accepts_nested_attributes_for :text_part, :image_part, :text_parts
      end)
      
      Object.const_set(:TestAttrJsonAccount, Class.new(ActiveRecord::Base) do
        self.table_name = "test_attr_json_accounts"
        include AttrJson::Record
        
        attr_json :preferences, TestTextPart.to_type
        attr_json :settings, ActiveModel::Type::Value.new
      end)
    end
  end

  def teardown
    # Clean up test tables
    ActiveRecord::Migration.drop_table :test_attr_json_pages if ActiveRecord::Base.connection.table_exists?(:test_attr_json_pages)
    ActiveRecord::Migration.drop_table :test_attr_json_accounts if ActiveRecord::Base.connection.table_exists?(:test_attr_json_accounts)
  end

  test "basic AttrJson::Model storage and retrieval" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      simple_text: "Hello World",
      simple_integer: 42
    )
    
    page.reload
    assert_equal "Hello World", page.simple_text
    assert_equal 42, page.simple_integer
    assert_equal "Hello World", page.json_attributes["simple_text"]
    assert_equal 42, page.json_attributes["simple_integer"]
  end

  test "AttrJson::Model nested objects" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_part: TestTextPart.new(name: "intro", content: "Welcome"),
      image_part: TestImagePart.new(name: "hero", image_id: 1, alt: "Hero image", filename: "hero.jpg")
    )
    
    page.reload
    assert_equal "intro", page.text_part.name
    assert_equal "Welcome", page.text_part.content
    assert_equal "hero", page.image_part.name
    assert_equal 1, page.image_part.image_id
    assert_equal "Hero image", page.image_part.alt
    assert_equal "hero.jpg", page.image_part.filename
  end

  test "AttrJson::Model arrays" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_parts: [
        TestTextPart.new(name: "part1", content: "First part"),
        TestTextPart.new(name: "part2", content: "Second part"),
        TestTextPart.new(name: "part3", content: "Third part")
      ]
    )
    
    page.reload
    assert_equal 3, page.text_parts.length
    assert_equal "part1", page.text_parts[0].name
    assert_equal "First part", page.text_parts[0].content
    assert_equal "part2", page.text_parts[1].name
    assert_equal "Second part", page.text_parts[1].content
    assert_equal "part3", page.text_parts[2].name
    assert_equal "Third part", page.text_parts[2].content
  end

  test "AttrJson type casting" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      simple_integer: "999"  # String input
    )
    
    assert_equal 999, page.simple_integer
    assert_equal Integer, page.simple_integer.class
  end

  test "AttrJson nested attributes" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_part_attributes: { name: "intro", content: "Welcome" },
      image_part_attributes: { name: "hero", image_id: 1, alt: "Hero", filename: "hero.jpg" }
    )
    
    assert_equal "intro", page.text_part.name
    assert_equal "Welcome", page.text_part.content
    assert_equal "hero", page.image_part.name
    assert_equal 1, page.image_part.image_id
  end

  test "AttrJson modification and persistence" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_part: TestTextPart.new(name: "intro", content: "Original content")
    )
    
    page.text_part.content = "Updated content"
    page.save!
    
    page.reload
    assert_equal "Updated content", page.text_part.content
  end

  test "AttrJson JSON querying" do
    page1 = TestAttrJsonPage.create!(
      title: "Test Page 1",
      simple_text: "findme"
    )
    
    page2 = TestAttrJsonPage.create!(
      title: "Test Page 2",
      simple_text: "other content"
    )
    
    results = TestAttrJsonPage.where("json_attributes LIKE ?", "%findme%")
    assert_equal 1, results.count
    assert_equal page1.id, results.first.id
  end

  test "AttrJson complex JSON operations" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_part: TestTextPart.new(name: "intro", content: "Content with old_id_123")
    )
    
    # Simulate SPINA's signed ID replacement
    ActiveRecord::Base.connection.execute(
      "UPDATE test_attr_json_pages SET json_attributes = REPLACE(json_attributes, 'old_id_123', 'new_id_456') WHERE id = #{page.id}"
    )
    
    page.reload
    assert_equal "Content with new_id_456", page.text_part.content
  end

  test "AttrJson arbitrary JSON data" do
    account = TestAttrJsonAccount.create!(
      name: "Test Account",
      settings: { 
        theme: "dark",
        language: "en",
        notifications: { email: true, push: false },
        metadata: { version: "1.0", features: ["feature1", "feature2"] }
      }
    )
    
    account.reload
    assert_equal "dark", account.settings["theme"]
    assert_equal "en", account.settings["language"]
    assert_equal true, account.settings["notifications"]["email"]
    assert_equal false, account.settings["notifications"]["push"]
    assert_equal "1.0", account.settings["metadata"]["version"]
    assert_equal ["feature1", "feature2"], account.settings["metadata"]["features"]
  end

  test "AttrJson data integrity with complex structures" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_parts: [
        TestTextPart.new(name: "intro", content: "Welcome to our site"),
        TestTextPart.new(name: "features", content: "Amazing features"),
        TestTextPart.new(name: "conclusion", content: "Contact us today")
      ]
    )
    
    # Verify JSON structure
    json_data = page.json_attributes
    assert_equal 3, json_data["text_parts"].length
    assert_equal "intro", json_data["text_parts"][0]["name"]
    assert_equal "Welcome to our site", json_data["text_parts"][0]["content"]
    
    # Verify object reconstruction
    page.reload
    assert_equal 3, page.text_parts.length
    assert_equal "intro", page.text_parts[0].name
    assert_equal "Welcome to our site", page.text_parts[0].content
  end

  test "AttrJson performance with moderate dataset" do
    # Create 50 pages with various AttrJson content
    start_time = Time.now
    
    50.times do |i|
      TestAttrJsonPage.create!(
        title: "Page #{i}",
        simple_text: "Content #{i}",
        simple_integer: i,
        text_part: TestTextPart.new(name: "part#{i}", content: "Content for part #{i}"),
        image_part: TestImagePart.new(name: "image#{i}", image_id: i, filename: "image#{i}.jpg"),
        text_parts: [
          TestTextPart.new(name: "sub1", content: "Sub content 1 for #{i}"),
          TestTextPart.new(name: "sub2", content: "Sub content 2 for #{i}")
        ]
      )
    end
    
    creation_time = Time.now - start_time
    
    # Query performance
    query_start = Time.now
    results = TestAttrJsonPage.where("json_attributes LIKE ?", "%Content 25%")
    query_time = Time.now - query_start
    
    # Assertions
    assert_equal 50, TestAttrJsonPage.count
    assert_equal 1, results.count
    assert creation_time < 10, "Creation should be reasonably fast (was #{creation_time}s)"
    assert query_time < 1, "Queries should be fast (was #{query_time}s)"
  end

  test "AttrJson edge cases with nil and empty values" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      simple_text: nil,
      text_part: nil,
      text_parts: []
    )
    
    page.reload
    assert_nil page.simple_text
    assert_nil page.text_part
    assert_equal [], page.text_parts
  end

  test "AttrJson default values" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_part: TestTextPart.new(name: "test")  # content should default to ""
    )
    
    page.reload
    assert_equal "", page.text_part.content
  end

  test "AttrJson compatibility with SPINA-like signed ID replacement" do
    # Create page with content that includes signed IDs
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_parts: [
        TestTextPart.new(name: "content1", content: "Image: signed_id_abc123"),
        TestTextPart.new(name: "content2", content: "Link: signed_id_def456 and signed_id_ghi789")
      ]
    )
    
    # Simulate SPINA's ReplaceSignedIdJob
    old_id = "signed_id_abc123"
    new_id = "signed_id_xyz999"
    
    ActiveRecord::Base.connection.execute(
      "UPDATE test_attr_json_pages SET json_attributes = REPLACE(json_attributes, '#{old_id}', '#{new_id}') WHERE id = #{page.id}"
    )
    
    page.reload
    assert_equal "Image: signed_id_xyz999", page.text_parts[0].content
    assert_equal "Link: signed_id_def456 and signed_id_ghi789", page.text_parts[1].content
  end

  test "AttrJson unknown_key handling" do
    # Create with extra unknown keys
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_part: TestTextPart.new(name: "test", content: "content", unknown_field: "should be stripped")
    )
    
    page.reload
    assert_equal "test", page.text_part.name
    assert_equal "content", page.text_part.content
    
    # Unknown field should be stripped due to attr_json_config(unknown_key: :strip)
    json_data = page.json_attributes
    assert_not_includes json_data["text_part"], "unknown_field"
  end

  test "jsonb_contains method not available (expected for SQLite)" do
    # This is expected behavior - jsonb_contains is PostgreSQL-specific
    assert_not TestAttrJsonPage.respond_to?(:jsonb_contains)
  end

  test "SQLite JSON functions work as alternative to PostgreSQL JSONB" do
    page = TestAttrJsonPage.create!(
      title: "Test Page",
      text_part: TestTextPart.new(name: "test", content: "searchable content")
    )
    
    # Use SQLite JSON functions instead of PostgreSQL JSONB operators
    results = TestAttrJsonPage.where("JSON_EXTRACT(json_attributes, '$.text_part.content') = ?", "searchable content")
    assert_equal 1, results.count
    assert_equal page.id, results.first.id
  end

  test "AttrJson works with SQLite database adapter" do
    assert_equal "SQLite", ActiveRecord::Base.connection.adapter_name
    
    # Verify JSON column type
    column = TestAttrJsonPage.columns.find { |c| c.name == "json_attributes" }
    assert_equal :json, column.type
  end
end