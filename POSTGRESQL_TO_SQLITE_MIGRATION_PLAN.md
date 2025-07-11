# PostgreSQL to SQLite Migration Plan

This document outlines the complete migration plan for removing PostgreSQL dependencies and converting Spina CMS to use SQLite exclusively.

## Overview

Spina CMS currently has a hard dependency on PostgreSQL and extensively uses its JSONB datatype for storing JSON data. This migration will:

1. Remove PostgreSQL dependency completely
2. Replace JSONB columns with SQLite-compatible alternatives
3. Update any PostgreSQL-specific SQL queries
4. Ensure all functionality remains intact

## Current PostgreSQL Dependencies

### 1. Gem Dependencies
- **File**: `spina.gemspec`
- **Issue**: Hard dependency on `pg` gem
- **Action**: Remove `pg` dependency, add `sqlite3` gem

### 2. Database Schema (JSONB Columns)
The following tables use PostgreSQL's JSONB datatype:

- **`spina_accounts.json_attributes`** (jsonb) - Stores account-level JSON data
- **`spina_pages.json_attributes`** (jsonb) - Stores page-level JSON data  
- **`spina_resources.slug`** (jsonb) - Stores multilingual slugs
- **`spina_settings.preferences`** (jsonb) - Stores plugin preferences

### 3. Mobility Gem Configuration
- **File**: `app/models/spina/resource.rb`
- **Issue**: Uses `translates :slug, backend: :jsonb`
- **Action**: Change to table-based backend

### 4. PostgreSQL-Specific SQL Queries
- **File**: `app/jobs/spina/replace_signed_id_job.rb`
- **Issue**: Uses PostgreSQL-specific `REGEXP_REPLACE` with JSONB casting
- **Action**: Replace with SQLite-compatible JSON operations

### 5. Database Configuration Templates
- **File**: `test/dummy/config/database.yml`
- **Issue**: Configured for PostgreSQL
- **Action**: Update to SQLite configuration

## Migration Steps

### Step 1: Update Gem Dependencies
**Files to modify:**
- `spina.gemspec`

**Changes:**
- Remove: `gem.add_dependency "pg"`
- Add: `gem.add_dependency "sqlite3", "~> 1.6"`

### Step 2: Create New SQLite-Compatible Migrations
**New migration files to create:**
- `db/migrate/19_convert_jsonb_to_json_for_sqlite.rb`

**Actions:**
- Convert `jsonb` columns to `json` (SQLite TEXT with JSON validation)
- Ensure data compatibility during migration
- Update indexes as needed

### Step 3: Update Mobility Configuration
**Files to modify:**
- `app/models/spina/resource.rb`
- `lib/generators/spina/templates/config/initializers/mobility.rb`

**Changes:**
- Change `translates :slug, backend: :jsonb` to `translates :slug, backend: :table`
- Update mobility initializer to use table backend by default

### Step 4: Replace PostgreSQL-Specific SQL Queries
**Files to modify:**
- `app/jobs/spina/replace_signed_id_job.rb`

**Changes:**
- Replace PostgreSQL `REGEXP_REPLACE` with SQLite-compatible JSON operations
- Use `json_replace()` or similar SQLite JSON functions
- Ensure proper JSON handling for text replacement

### Step 5: Update Database Configuration Templates
**Files to modify:**
- `test/dummy/config/database.yml`
- Any generator templates that create database configurations

**Changes:**
- Update default adapter from `postgresql` to `sqlite3`
- Update connection parameters
- Remove PostgreSQL-specific configuration options

### Step 6: Update Documentation and Installation
**Files to modify:**
- `README.md`
- `lib/generators/spina/install_generator.rb`
- Installation documentation

**Changes:**
- Remove PostgreSQL requirements from setup instructions
- Update system requirements
- Update installation steps

### Step 7: Update Test Configuration
**Files to modify:**
- `test/dummy/config/database.yml`
- Any test fixtures or factories that depend on PostgreSQL features

**Changes:**
- Ensure all tests work with SQLite
- Update test database configuration
- Verify JSON handling in tests

## Technical Considerations

### JSON Data Handling
- SQLite supports JSON operations via JSON functions
- Ensure all JSON queries use SQLite-compatible syntax
- Test JSON validation and querying thoroughly

### Performance Implications
- SQLite may have different performance characteristics
- Monitor query performance, especially for JSON operations
- Consider indexing strategies for JSON fields

### Data Migration Strategy
- This is a **hard cutover** - no data migration between PostgreSQL and SQLite
- All existing PostgreSQL databases will need to be recreated
- Users will need to export/import their data manually if needed

### Compatibility Testing
- Test all CMS features with SQLite
- Verify plugin compatibility
- Ensure admin interface works correctly
- Test multilingual functionality

## Files Requiring Changes

### Core Files
1. `spina.gemspec` - Update gem dependencies
2. `app/models/spina/resource.rb` - Change mobility backend
3. `app/jobs/spina/replace_signed_id_job.rb` - Replace PostgreSQL SQL
4. `lib/generators/spina/templates/config/initializers/mobility.rb` - Update mobility config

### Migration Files
5. `db/migrate/19_convert_jsonb_to_json_for_sqlite.rb` - New migration for SQLite schema

### Configuration Files
6. `test/dummy/config/database.yml` - Update test database config
7. Any generator templates that create database configurations

### Documentation
8. `README.md` - Update installation requirements
9. Installation guides and documentation

## Risk Assessment

### High Risk
- JSON query compatibility between PostgreSQL JSONB and SQLite JSON
- Performance differences in JSON operations
- Plugin compatibility with new backend

### Medium Risk
- Mobility gem configuration changes
- Test suite compatibility
- Installation process changes

### Low Risk
- Basic CRUD operations
- Admin interface functionality
- Static content management

## Testing Strategy

1. **Unit Tests**: Ensure all models work with SQLite
2. **Integration Tests**: Test JSON operations and queries
3. **System Tests**: Verify full CMS functionality
4. **Plugin Tests**: Test compatibility with existing plugins
5. **Performance Tests**: Compare performance with PostgreSQL

## Rollback Plan

If issues arise during migration:
1. Revert gem dependency changes
2. Restore PostgreSQL migrations
3. Restore original mobility configuration
4. Restore PostgreSQL-specific SQL queries

## Timeline

1. **Phase 1**: Update dependencies and basic configuration (1-2 days)
2. **Phase 2**: Create migrations and update SQL queries (2-3 days)
3. **Phase 3**: Testing and validation (2-3 days)
4. **Phase 4**: Documentation updates (1 day)

## Success Criteria

- [ ] All tests pass with SQLite
- [ ] CMS functionality is preserved
- [ ] Installation process works smoothly
- [ ] No PostgreSQL dependencies remain
- [ ] Documentation is updated
- [ ] Performance is acceptable

## Post-Migration Tasks

1. Update CI/CD pipelines to use SQLite
2. Update deployment documentation
3. Create migration guide for existing users
4. Update plugin development documentation
5. Monitor for any compatibility issues

---

**Note**: This is a breaking change that will require users to recreate their databases. Proper communication and documentation will be essential for the transition.