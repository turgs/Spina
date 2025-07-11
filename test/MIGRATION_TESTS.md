# PostgreSQL to SQLite Migration - Comprehensive Test Suite

This document describes the comprehensive test suite created to verify the PostgreSQL to SQLite migration implementation.

## Test Coverage Overview

The test suite consists of 5 main test files that cover all aspects of the migration:

### 1. SQLite Migration Test (`test/integration/spina/sqlite_migration_test.rb`)
**Purpose**: Verify core migration functionality and SQLite compatibility

**Test Coverage**:
- ✅ Database adapter detection (SQLite)
- ✅ JSONB to JSON column conversion
- ✅ Mobility backend configuration (table-based)
- ✅ Migration file execution
- ✅ FTS table creation and structure
- ✅ FTS trigger synchronization
- ✅ SQL operation compatibility (LIKE, REPLACE, JSON operations)
- ✅ SQLite PRAGMA configuration
- ✅ Basic search functionality
- ✅ Data type compatibility
- ✅ Performance baseline testing

### 2. FTS Comprehensive Test (`test/integration/spina/fts_comprehensive_test.rb`)
**Purpose**: Thoroughly test Full-Text Search implementation

**Test Coverage**:
- ✅ FTS table structure validation
- ✅ FTS triggers for page creation/update/deletion
- ✅ FTS triggers for resource operations
- ✅ Page active/draft status handling
- ✅ Search relevance ranking
- ✅ Multiple query types (phrase, prefix, boolean)
- ✅ Special character handling
- ✅ Search performance testing
- ✅ Search filters integration
- ✅ Fallback mechanism for non-SQLite
- ✅ Search snippet highlighting

### 3. SQL Compatibility Test (`test/integration/spina/sql_compatibility_test.rb`)
**Purpose**: Verify SQL query compatibility between PostgreSQL and SQLite

**Test Coverage**:
- ✅ ILIKE to LOWER()/LIKE conversion
- ✅ REGEXP_REPLACE to REPLACE function conversion
- ✅ JSON operations (LIKE, extraction, manipulation)
- ✅ SQLite-specific SQL functions
- ✅ Complex SQL queries with JOINs
- ✅ Database constraints and foreign keys
- ✅ Transaction handling and rollback
- ✅ Date/time operations
- ✅ Case-insensitive text search
- ✅ JSON data integrity
- ✅ Large dataset performance

### 4. Search Service Test (`test/services/spina/search_service_test.rb`)
**Purpose**: Test the SearchService module implementation

**Test Coverage**:
- ✅ Page search functionality
- ✅ Resource search functionality
- ✅ Query type variations (phrase, prefix, boolean)
- ✅ Search filters (active_only, live_only)
- ✅ Search snippet highlighting
- ✅ Empty query handling
- ✅ FTS availability detection
- ✅ Fallback mechanism testing

### 5. System Integration Test (`test/integration/spina/system_integration_test.rb`)
**Purpose**: End-to-end system testing and realistic workflow validation

**Test Coverage**:
- ✅ Complete CMS workflow (create, read, update, delete)
- ✅ Complex content management scenarios
- ✅ Data migration simulation
- ✅ Performance testing with realistic workloads
- ✅ Error handling and edge cases
- ✅ Database integrity maintenance
- ✅ Multi-resource hierarchical structures
- ✅ JSON attribute manipulation
- ✅ FTS synchronization verification

## Test Environment Requirements

### Database Requirements
- SQLite 3.x with FTS5 support
- Rails 8.0+ application environment
- Proper SQLite PRAGMA settings

### Test Dependencies
- Minitest testing framework
- Factory Bot for test data generation
- Rails test environment setup

## Running the Tests

### Individual Test Files
```bash
# Run individual test files
ruby -I test test/integration/spina/sqlite_migration_test.rb
ruby -I test test/integration/spina/fts_comprehensive_test.rb
ruby -I test test/integration/spina/sql_compatibility_test.rb
ruby -I test test/services/spina/search_service_test.rb
ruby -I test test/integration/spina/system_integration_test.rb
```

### Complete Test Suite
```bash
# Run all migration tests
ruby test/run_migration_tests.rb

# Or with Rails
rails test test/integration/spina/
rails test test/services/spina/search_service_test.rb
```

## Test Data Management

### Test Data Isolation
- Each test file uses unique prefixes for test data
- Teardown methods clean up test data
- No interference between test files

### Test Data Patterns
- Pages: `test-*`, `fts-test-*`, `sql-test-*`, `system-test-*`
- Resources: `test-*`, `fts-test-*`, `sql-test-*`, `system-test-*`
- Automatic cleanup in teardown methods

## Performance Benchmarks

### Baseline Performance Expectations
- Page creation: < 5 seconds for 20 pages
- Search operations: < 1 second for datasets up to 100 records
- FTS search: < 0.5 seconds for 50 records
- Complex queries: < 1 second for typical workloads

### Stress Test Scenarios
- 100 resources with complex JSON attributes
- 50 pages with FTS indexing
- Hierarchical resource structures
- Migration simulation with data transformation

## Key Features Tested

### Migration Compatibility
- ✅ PostgreSQL JSONB → SQLite JSON conversion
- ✅ PostgreSQL ILIKE → SQLite LOWER()/LIKE conversion
- ✅ PostgreSQL REGEXP_REPLACE → SQLite REPLACE conversion
- ✅ Mobility backend table-based configuration
- ✅ Rails 8 compatibility

### FTS Implementation
- ✅ FTS5 virtual table creation
- ✅ Automatic trigger synchronization
- ✅ Advanced search capabilities
- ✅ Relevance ranking
- ✅ Performance optimization

### Data Integrity
- ✅ Foreign key constraints
- ✅ Transaction consistency
- ✅ JSON data preservation
- ✅ Search index synchronization
- ✅ Error handling

## Test Success Criteria

### Migration Validation
- All migrations execute successfully
- No data loss during conversion
- All SQL queries work with SQLite
- Performance meets baseline requirements

### FTS Validation
- FTS tables created and populated
- Triggers maintain synchronization
- Search results ranked by relevance
- Advanced search features work

### System Integration
- End-to-end workflows complete successfully
- Error handling works properly
- Performance acceptable for production use
- Database integrity maintained

## Troubleshooting Test Issues

### Common Issues
1. **SQLite Version**: Ensure SQLite 3.x with FTS5 support
2. **Rails Version**: Requires Rails 8.0+
3. **Test Environment**: Ensure proper test database setup
4. **FTS Tables**: Verify FTS migration has run

### Debug Commands
```bash
# Check SQLite version
sqlite3 --version

# Check FTS support
sqlite3 database.db "SELECT * FROM sqlite_master WHERE type='table' AND name LIKE '%fts%';"

# Check Rails version
rails --version

# Check pending migrations
rails db:migrate:status
```

## Continuous Integration

### CI Requirements
- SQLite 3.x with FTS5
- Ruby 3.x
- Rails 8.0+
- Test database setup

### CI Test Commands
```bash
# Setup
bundle install
rails db:setup RAILS_ENV=test

# Run tests
ruby test/run_migration_tests.rb
```

This comprehensive test suite ensures that the PostgreSQL to SQLite migration is thoroughly validated across all aspects of functionality, performance, and data integrity.