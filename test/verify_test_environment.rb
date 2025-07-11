#!/usr/bin/env ruby

# Simple test verification script to ensure the migration tests will work
# This script checks the basic requirements and setup

puts "=" * 60
puts "PostgreSQL to SQLite Migration - Test Environment Check"
puts "=" * 60
puts ""

# Check if we can load the required gems
begin
  require 'bundler/setup'
  puts "✓ Bundler setup successful"
rescue LoadError => e
  puts "✗ Bundler setup failed: #{e.message}"
  exit 1
end

# Check if we can load Rails
begin
  ENV['RAILS_ENV'] = 'test'
  require File.expand_path('../test/dummy/config/environment.rb', __FILE__)
  puts "✓ Rails environment loaded successfully"
rescue LoadError => e
  puts "✗ Rails environment failed to load: #{e.message}"
  exit 1
end

# Check database connection
begin
  ActiveRecord::Base.connection
  puts "✓ Database connection established"
  puts "  Adapter: #{ActiveRecord::Base.connection.adapter_name}"
  
  if ActiveRecord::Base.connection.adapter_name == "SQLite"
    version = ActiveRecord::Base.connection.execute("SELECT sqlite_version()").first["sqlite_version()"]
    puts "  SQLite Version: #{version}"
    puts "✓ SQLite confirmed"
  else
    puts "⚠️  Expected SQLite, got #{ActiveRecord::Base.connection.adapter_name}"
  end
rescue => e
  puts "✗ Database connection failed: #{e.message}"
  exit 1
end

# Check if migrations are up to date
begin
  ActiveRecord::Migration.check_pending!
  puts "✓ All migrations are up to date"
rescue ActiveRecord::PendingMigrationError => e
  puts "⚠️  Pending migrations detected"
  puts "  Run the following to resolve:"
  puts "  cd test/dummy && rails db:migrate RAILS_ENV=test"
end

# Check if FTS tables exist
begin
  if ActiveRecord::Base.connection.table_exists?("spina_pages_fts")
    puts "✓ FTS pages table exists"
  else
    puts "⚠️  FTS pages table missing"
  end
  
  if ActiveRecord::Base.connection.table_exists?("spina_resources_fts")
    puts "✓ FTS resources table exists"
  else
    puts "⚠️  FTS resources table missing"
  end
rescue => e
  puts "✗ FTS table check failed: #{e.message}"
end

# Check if Spina models can be loaded
begin
  Spina::Page
  puts "✓ Spina::Page model loaded"
rescue => e
  puts "✗ Spina::Page model failed to load: #{e.message}"
end

begin
  Spina::Resource
  puts "✓ Spina::Resource model loaded"
rescue => e
  puts "✗ Spina::Resource model failed to load: #{e.message}"
end

# Check if SearchService can be loaded
begin
  Spina::SearchService
  puts "✓ Spina::SearchService loaded"
rescue => e
  puts "✗ Spina::SearchService failed to load: #{e.message}"
end

# Test basic model creation
begin
  test_resource = Spina::Resource.new(name: "test-verification", label: "Test Verification")
  if test_resource.valid?
    puts "✓ Resource model validation works"
  else
    puts "⚠️  Resource model validation issues: #{test_resource.errors.full_messages.join(', ')}"
  end
rescue => e
  puts "✗ Resource model test failed: #{e.message}"
end

begin
  test_page = Spina::Page.new(
    name: "test-verification",
    title: "Test Verification",
    description: "Test description",
    materialized_path: "/test-verification",
    active: true,
    draft: false
  )
  if test_page.valid?
    puts "✓ Page model validation works"
  else
    puts "⚠️  Page model validation issues: #{test_page.errors.full_messages.join(', ')}"
  end
rescue => e
  puts "✗ Page model test failed: #{e.message}"
end

# Test search service
begin
  results = Spina::SearchService.search_pages("")
  puts "✓ SearchService basic test passed"
rescue => e
  puts "✗ SearchService test failed: #{e.message}"
end

puts ""
puts "=" * 60
puts "Environment Check Complete"
puts "=" * 60
puts ""

puts "Next steps:"
puts "1. If any issues were found, resolve them before running tests"
puts "2. Run the comprehensive test suite:"
puts "   ruby test/run_migration_tests.rb"
puts "3. Or run individual test files:"
puts "   ruby -I test test/integration/spina/sqlite_migration_test.rb"
puts ""