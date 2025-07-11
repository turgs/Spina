#!/usr/bin/env ruby

# Test runner for PostgreSQL to SQLite migration comprehensive tests
# This script runs all the migration-related tests and provides a summary

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/reporters'

# Set up test environment
ENV['RAILS_ENV'] = 'test'

# Load Rails application
require File.expand_path('../test/dummy/config/environment.rb', __FILE__)

# Configure reporters
Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(color: true),
  Minitest::Reporters::SpecReporter.new
]

# Test files to run
test_files = [
  'test/services/spina/search_service_test.rb',
  'test/integration/spina/sqlite_migration_test.rb',
  'test/integration/spina/fts_comprehensive_test.rb',
  'test/integration/spina/sql_compatibility_test.rb',
  'test/integration/spina/system_integration_test.rb'
]

puts "=" * 80
puts "PostgreSQL to SQLite Migration - Comprehensive Test Suite"
puts "=" * 80
puts ""

puts "Running comprehensive tests for:"
puts "✓ SQLite Migration Compatibility"
puts "✓ Full-Text Search (FTS) Functionality"
puts "✓ SQL Query Compatibility"
puts "✓ Search Service Integration"
puts "✓ System Integration & Performance"
puts ""

puts "Database Adapter: #{ActiveRecord::Base.connection.adapter_name}"
puts "SQLite Version: #{ActiveRecord::Base.connection.execute('SELECT sqlite_version()').first['sqlite_version()']}"
puts ""

# Check if we're running on SQLite
if ActiveRecord::Base.connection.adapter_name != "SQLite"
  puts "⚠️  WARNING: Tests are designed for SQLite but running on #{ActiveRecord::Base.connection.adapter_name}"
  puts "   Some tests may be skipped or fail."
  puts ""
end

# Check if FTS tables exist
fts_available = ActiveRecord::Base.connection.table_exists?("spina_pages_fts")
puts "FTS Tables Available: #{fts_available ? '✓' : '✗'}"
puts ""

# Run migrations if needed
puts "Checking database migrations..."
begin
  ActiveRecord::Migration.check_pending!
  puts "✓ All migrations are up to date"
rescue ActiveRecord::PendingMigrationError => e
  puts "⚠️  Pending migrations detected: #{e.message}"
  puts "   Run 'rails db:migrate' to resolve"
end
puts ""

# Load test files
test_files.each do |file|
  if File.exist?(file)
    puts "Loading #{file}..."
    require_relative file
  else
    puts "⚠️  Test file not found: #{file}"
  end
end

puts ""
puts "=" * 80
puts "Running Tests..."
puts "=" * 80

# Run tests
# (Tests will run automatically due to minitest/autorun)