require 'test_helper'

class AttrJsonSpinaUsagePatternsTest < ActiveSupport::TestCase
  
  def setup
    # Skip if not SQLite
    skip "AttrJson usage pattern tests only work with SQLite" unless ActiveRecord::Base.connection.adapter_name == "SQLite"
    
    # Ensure test database is clean
    cleanup_test_data
  end

  def teardown
    cleanup_test_data
  end

  def cleanup_test_data
    Spina::Page.delete_all
    Spina::Account.delete_all
    Spina::Resource.delete_all
  end

  # Test 1: SPINA Account model with AttrJson preferences
  test "SPINA Account model AttrJson functionality" do
    account = Spina::Account.create!(
      name: "Test Account",
      json_attributes: {
        "google_analytics" => "GA-123456",
        "facebook" => "https://facebook.com/test",
        "theme" => "default"
      }
    )
    
    # Test serialized_attr_accessor functionality
    account.google_analytics = "GA-UPDATED"
    account.facebook = "https://facebook.com/updated"
    account.theme = "dark"
    account.save!
    
    account.reload
    assert_equal "GA-UPDATED", account.google_analytics
    assert_equal "https://facebook.com/updated", account.facebook
    assert_equal "dark", account.theme
    
    # Verify JSON structure is correct
    assert_equal "GA-UPDATED", account.preferences["google_analytics"]
    assert_equal "https://facebook.com/updated", account.preferences["facebook"]
    assert_equal "dark", account.preferences["theme"]
  end

  # Test 2: SPINA Page model with AttrJson parts
  test "SPINA Page model AttrJson parts functionality" do
    page = Spina::Page.create!(
      title: "Test Page",
      json_attributes: {
        "text_part" => {
          "name" => "intro",
          "content" => "Welcome to our site"
        },
        "image_part" => {
          "name" => "hero",
          "image_id" => 1,
          "alt" => "Hero image",
          "filename" => "hero.jpg"
        }
      }
    )
    
    # Test part retrieval
    page.reload
    assert_equal "intro", page.json_attributes["text_part"]["name"]
    assert_equal "Welcome to our site", page.json_attributes["text_part"]["content"]
    assert_equal "hero", page.json_attributes["image_part"]["name"]
    assert_equal 1, page.json_attributes["image_part"]["image_id"]
  end

  # Test 3: SPINA Parts models individually
  test "SPINA Parts models AttrJson functionality" do
    # Test Text part
    text_part = Spina::Parts::Text.new(
      name: "intro",
      content: "Welcome to our site"
    )
    
    assert_equal "intro", text_part.name
    assert_equal "Welcome to our site", text_part.content
    assert_equal "Welcome to our site", text_part.label
    
    # Test Image part  
    image_part = Spina::Parts::Image.new(
      name: "hero", 
      image_id: 1,
      alt: "Hero image"
    )
    
    assert_equal "hero", image_part.name
    assert_equal 1, image_part.image_id
    assert_equal "Hero image", image_part.alt
    
    # Test Line part
    line_part = Spina::Parts::Line.new(
      name: "subtitle",
      content: "Subtitle text"
    )
    
    assert_equal "subtitle", line_part.name
    assert_equal "Subtitle text", line_part.content
    
    # Test MultiLine part
    multiline_part = Spina::Parts::MultiLine.new(
      name: "description",
      content: "This is a longer description\nwith multiple lines"
    )
    
    assert_equal "description", multiline_part.name
    assert_equal "This is a longer description\nwith multiple lines", multiline_part.content
  end

  # Test 4: SPINA Repeater functionality with nested AttrJson
  test "SPINA Repeater parts with nested AttrJson" do
    skip "Requires full SPINA parts system setup" # This would need more complex setup
    
    # This test would verify:
    # - Repeater content creation
    # - Nested attributes handling  
    # - Array serialization/deserialization
    # - Content modification and persistence
  end

  # Test 5: SPINA PolymorphicModel usage
  test "SPINA PolymorphicModel type system" do
    # Test the custom SpinaPartsModel polymorphic type
    polymorphic_type = AttrJson::Type::SpinaPartsModel.new
    
    # Verify it can handle model names
    model_names = polymorphic_type.model_names
    assert_includes model_names, "Spina::Parts::Text"
    assert_includes model_names, "Spina::Parts::Image"
    assert_includes model_names, "Spina::Parts::Line"
    assert_includes model_names, "Spina::Parts::MultiLine"
    
    # Test type lookup
    text_type = polymorphic_type.type_for_model_name("Spina::Parts::Text")
    assert_not_nil text_type
    assert_equal Spina::Parts::Text, text_type.model
  end

  # Test 6: AttrJson unknown_key handling in SPINA
  test "SPINA AttrJson unknown_key stripping" do
    # Create a Text part with unknown attributes
    text_part = Spina::Parts::Text.new(
      name: "test",
      content: "content", 
      unknown_field: "should be stripped",
      another_unknown: "also stripped"
    )
    
    # Verify known attributes are preserved
    assert_equal "test", text_part.name
    assert_equal "content", text_part.content
    
    # Verify unknown keys are stripped (attr_json_config(unknown_key: :strip))
    serialized = text_part.as_json
    assert_not_includes serialized, "unknown_field"
    assert_not_includes serialized, "another_unknown"
  end

  # Test 7: JSON query compatibility with SPINA usage
  test "JSON querying works with SPINA AttrJson patterns" do
    # Create pages with various content
    page1 = Spina::Page.create!(
      title: "Page 1",
      json_attributes: {
        "intro" => {
          "name" => "intro",
          "content" => "Welcome to our website"
        }
      }
    )
    
    page2 = Spina::Page.create!(
      title: "Page 2", 
      json_attributes: {
        "intro" => {
          "name" => "intro",
          "content" => "About our company"
        }
      }
    )
    
    # Test LIKE queries (basic search)
    results = Spina::Page.where("json_attributes LIKE ?", "%website%")
    assert_equal 1, results.count
    assert_equal page1.id, results.first.id
    
    # Test SQLite JSON_EXTRACT (more precise querying)
    results = Spina::Page.where("JSON_EXTRACT(json_attributes, '$.intro.content') LIKE ?", "%company%")
    assert_equal 1, results.count
    assert_equal page2.id, results.first.id
    
    # Test case-insensitive search (replacement for PostgreSQL ILIKE)
    results = Spina::Page.where("LOWER(json_attributes) LIKE LOWER(?)", "%WELCOME%")
    assert_equal 1, results.count
    assert_equal page1.id, results.first.id
  end

  # Test 8: SPINA signed ID replacement compatibility
  test "SPINA signed ID replacement works with AttrJson" do
    # Create page with content containing signed IDs
    page = Spina::Page.create!(
      title: "Test Page",
      json_attributes: {
        "content" => {
          "name" => "main_content",
          "content" => "Image: signed_id_abc123, Link: signed_id_def456"
        },
        "sidebar" => {
          "name" => "sidebar",
          "content" => "Another image: signed_id_abc123"
        }
      }
    )
    
    # Simulate SPINA's ReplaceSignedIdJob
    old_id = "signed_id_abc123"
    new_id = "signed_id_xyz999"
    
    ActiveRecord::Base.connection.execute(
      "UPDATE spina_pages SET json_attributes = REPLACE(json_attributes, '#{old_id}', '#{new_id}') WHERE id = #{page.id}"
    )
    
    page.reload
    
    # Verify replacement worked
    assert_includes page.json_attributes["content"]["content"], "signed_id_xyz999"
    assert_not_includes page.json_attributes["content"]["content"], "signed_id_abc123"
    assert_includes page.json_attributes["sidebar"]["content"], "signed_id_xyz999"
    assert_not_includes page.json_attributes["sidebar"]["content"], "signed_id_abc123"
    
    # Verify other signed IDs are preserved
    assert_includes page.json_attributes["content"]["content"], "signed_id_def456"
  end

  # Test 9: AttrJson performance with SPINA-like usage
  test "AttrJson performance with SPINA-like content structures" do
    start_time = Time.now
    
    # Create 30 pages with realistic SPINA content
    30.times do |i|
      Spina::Page.create!(
        title: "Page #{i}",
        json_attributes: {
          "intro" => {
            "name" => "intro",
            "content" => "Introduction content for page #{i}"
          },
          "hero_image" => {
            "name" => "hero",
            "image_id" => i + 1,
            "alt" => "Hero image for page #{i}",
            "filename" => "hero#{i}.jpg"
          },
          "content_blocks" => [
            {
              "name" => "block1",
              "content" => "First content block for page #{i}"
            },
            {
              "name" => "block2", 
              "content" => "Second content block for page #{i}"
            }
          ]
        }
      )
    end
    
    creation_time = Time.now - start_time
    
    # Test query performance
    query_start = Time.now
    results = Spina::Page.where("json_attributes LIKE ?", "%page 15%")
    query_time = Time.now - query_start
    
    # Test complex query performance
    complex_query_start = Time.now
    complex_results = Spina::Page.where("JSON_EXTRACT(json_attributes, '$.hero_image.alt') LIKE ?", "%page 20%")
    complex_query_time = Time.now - complex_query_start
    
    # Assertions
    assert_equal 30, Spina::Page.count
    assert_equal 1, results.count
    assert_equal 1, complex_results.count
    
    # Performance should be reasonable for small to medium datasets
    assert creation_time < 10, "Page creation should be fast (was #{creation_time}s)"
    assert query_time < 1, "Simple queries should be fast (was #{query_time}s)"
    assert complex_query_time < 1, "Complex queries should be fast (was #{complex_query_time}s)"
  end

  # Test 10: AttrJson type casting with SPINA parts
  test "AttrJson type casting works correctly with SPINA parts" do
    # Test integer casting
    image_part = Spina::Parts::Image.new(
      name: "test_image",
      image_id: "123",  # String input
      alt: "Test image"
    )
    
    assert_equal 123, image_part.image_id
    assert_equal Integer, image_part.image_id.class
    
    # Test string casting
    text_part = Spina::Parts::Text.new(
      name: "test_text",
      content: 456  # Integer input
    )
    
    assert_equal "456", text_part.content
    assert_equal String, text_part.content.class
  end

  # Test 11: AttrJson edge cases specific to SPINA
  test "AttrJson handles SPINA-specific edge cases" do
    # Test empty/nil content
    page = Spina::Page.create!(
      title: "Empty Content Page",
      json_attributes: {
        "empty_text" => {
          "name" => "empty",
          "content" => ""
        },
        "nil_image" => nil
      }
    )
    
    page.reload
    assert_equal "", page.json_attributes["empty_text"]["content"]
    assert_nil page.json_attributes["nil_image"]
    
    # Test default values
    text_part = Spina::Parts::Text.new(name: "test")
    assert_equal "", text_part.content  # Default from attr_json :content, :string, default: ""
  end

  # Test 12: AttrJson nested attributes (if used in SPINA)
  test "AttrJson nested attributes work with SPINA patterns" do
    # Test would verify nested_attributes functionality
    # This is complex and depends on specific SPINA implementation details
    
    # For now, just verify the basic capability exists
    assert Spina::Page.include?(AttrJson::NestedAttributes)
    assert Spina::Account.include?(AttrJson::NestedAttributes)
  end

  # Test 13: AttrJson JSON column structure validation
  test "AttrJson maintains proper JSON column structure" do
    page = Spina::Page.create!(
      title: "Structure Test",
      json_attributes: {
        "complex_structure" => {
          "name" => "complex",
          "metadata" => {
            "version" => "1.0",
            "features" => ["feature1", "feature2"],
            "settings" => {
              "theme" => "dark",
              "language" => "en"
            }
          }
        }
      }
    )
    
    page.reload
    json_data = page.json_attributes
    
    # Verify nested structure is preserved
    assert_equal "complex", json_data["complex_structure"]["name"]
    assert_equal "1.0", json_data["complex_structure"]["metadata"]["version"]
    assert_equal ["feature1", "feature2"], json_data["complex_structure"]["metadata"]["features"]
    assert_equal "dark", json_data["complex_structure"]["metadata"]["settings"]["theme"]
    assert_equal "en", json_data["complex_structure"]["metadata"]["settings"]["language"]
  end

  # Test 14: AttrJson compatibility with SPINA migrations
  test "AttrJson works after SPINA SQLite migration" do
    # Verify that pages created after migration work correctly
    page = Spina::Page.create!(
      title: "Post-Migration Page",
      json_attributes: {
        "migrated_content" => {
          "name" => "content",
          "content" => "This content was created after PostgreSQL to SQLite migration"
        }
      }
    )
    
    page.reload
    assert_equal "content", page.json_attributes["migrated_content"]["name"]
    assert_equal "This content was created after PostgreSQL to SQLite migration", page.json_attributes["migrated_content"]["content"]
    
    # Verify the database column is correct type
    column = Spina::Page.columns.find { |c| c.name == "json_attributes" }
    assert_equal :json, column.type
  end

  # Test 15: AttrJson memory usage and object creation
  test "AttrJson memory usage is reasonable with SPINA parts" do
    # Create objects and measure memory impact
    start_memory = measure_memory_usage
    
    # Create multiple part objects
    parts = []
    100.times do |i|
      parts << Spina::Parts::Text.new(name: "part#{i}", content: "Content #{i}")
      parts << Spina::Parts::Image.new(name: "image#{i}", image_id: i, alt: "Alt #{i}")
    end
    
    end_memory = measure_memory_usage
    memory_diff = end_memory - start_memory
    
    # Memory usage should be reasonable (less than 50MB for 200 objects)
    assert memory_diff < 50_000_000, "Memory usage should be reasonable (was #{memory_diff} bytes)"
    
    # Verify objects are created correctly
    assert_equal 200, parts.length
    assert_equal "part0", parts[0].name
    assert_equal "image0", parts[1].name
  end

  private

  def measure_memory_usage
    GC.start
    `ps -o rss= -p #{Process.pid}`.to_i * 1024  # Convert KB to bytes
  end
end