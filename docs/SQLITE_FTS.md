# SQLite Full-Text Search (FTS) in Spina

Spina now includes SQLite Full-Text Search (FTS) capabilities for improved search performance and functionality.

## Features

- **Fast Text Search**: Utilizes SQLite's FTS5 engine for optimized full-text search
- **Relevance Ranking**: Results are automatically ranked by relevance
- **Multiple Query Types**: Support for phrase queries, prefix matching, and boolean operators
- **Automatic Synchronization**: FTS tables are kept in sync with main tables via triggers
- **Backward Compatibility**: Falls back to LIKE queries for non-SQLite databases
- **Search Highlighting**: Built-in support for highlighting search terms in results

## Usage

### Basic Search

```ruby
# Search pages
results = Spina::SearchService.search_pages("spina cms")

# Search resources
results = Spina::SearchService.search_resources("blog")
```

### Advanced Search Options

```ruby
# Phrase search (exact phrase)
results = Spina::SearchService.search_pages("content management", query_type: :phrase)

# Prefix search (starts with)
results = Spina::SearchService.search_pages("comp", query_type: :prefix)

# Boolean search (use AND, OR, NOT operators)
results = Spina::SearchService.search_pages("spina AND cms", query_type: :boolean)

# Search with filters
results = Spina::SearchService.search_pages("about", active_only: true, live_only: true)
```

### Search Highlighting

```ruby
# Highlight search terms in content
content = "Welcome to Spina CMS"
query = "spina"
highlighted = Spina::SearchService.search_snippets(query, content)
# Returns: "Welcome to <mark>Spina</mark> CMS"

# Custom highlight tags
highlighted = Spina::SearchService.search_snippets(query, content, 
  start_tag: '<strong>', end_tag: '</strong>')
```

## Controllers

The search controllers have been updated to use FTS automatically:

- `Spina::Admin::PageSelectOptionsController#search`
- `Spina::Admin::ResourceSelectOptionsController#search`

## Database Setup

FTS tables are created automatically via the migration:

```ruby
rails db:migrate
```

The migration creates:
- `spina_pages_fts` - FTS table for pages
- `spina_resources_fts` - FTS table for resources
- Triggers to keep FTS tables synchronized

## Query Syntax

### Basic Queries
- `spina` - Find documents containing "spina"
- `spina cms` - Find documents containing "spina" OR "cms"

### Phrase Queries
- `"spina cms"` - Find documents containing the exact phrase "spina cms"

### Prefix Queries
- `spin*` - Find documents containing words starting with "spin"

### Boolean Queries
- `spina AND cms` - Find documents containing both "spina" and "cms"
- `spina OR blog` - Find documents containing either "spina" or "blog"
- `spina NOT blog` - Find documents containing "spina" but not "blog"

### Column-specific Queries
- `title:spina` - Search only in title column
- `description:cms` - Search only in description column

## Performance

SQLite FTS provides significant performance improvements over LIKE queries:

- **Indexed Search**: FTS uses specialized indexes for fast text search
- **Relevance Ranking**: Results are automatically ranked by relevance
- **Memory Efficient**: FTS tables are stored separately and optimized for search
- **Scalable**: Performance remains consistent as content grows

## Configuration

FTS is enabled by default in the SQLite database configuration:

```yaml
# config/database.yml
default: &default
  adapter: sqlite3
  pragma:
    enable_fts: true
    # other pragmas...
```

## Compatibility

- **SQLite**: Full FTS support with FTS5 engine
- **Other Databases**: Automatic fallback to LIKE queries
- **Rails 8**: Optimized for Rails 8 with proper SQLite configuration

## Testing

Tests are included to verify FTS functionality:

```bash
rails test test/services/spina/search_service_test.rb
```

## Troubleshooting

### FTS Not Working

1. Verify SQLite version supports FTS5:
   ```bash
   sqlite3 --version
   ```

2. Check if FTS tables exist:
   ```sql
   SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%_fts';
   ```

3. Rebuild FTS tables if needed:
   ```ruby
   # In Rails console
   ActiveRecord::Base.connection.execute("INSERT INTO spina_pages_fts(spina_pages_fts) VALUES('rebuild')")
   ```

### Search Not Finding Results

1. Verify data is in FTS tables:
   ```sql
   SELECT COUNT(*) FROM spina_pages_fts;
   ```

2. Check for special characters in query (automatically escaped by SearchService)

3. Use fallback search for debugging:
   ```ruby
   # This will use LIKE queries regardless of database
   results = Spina::SearchService.send(:fallback_search_pages, "query")
   ```