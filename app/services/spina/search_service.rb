module Spina
  module SearchService
    extend self

    def search_pages(query, options = {})
      return Page.none if query.blank?

      if sqlite_fts_available?
        fts_search_pages(query, options)
      else
        fallback_search_pages(query, options)
      end
    end

    def search_resources(query, options = {})
      return Resource.none if query.blank?

      if sqlite_fts_available?
        fts_search_resources(query, options)
      else
        fallback_search_resources(query, options)
      end
    end

    # Generate search snippets for highlighting
    def search_snippets(query, content, options = {})
      return content if query.blank?

      if sqlite_fts_available?
        fts_snippets(query, content, options)
      else
        fallback_snippets(query, content, options)
      end
    end

    private

    def sqlite_fts_available?
      @sqlite_fts_available ||= begin
        ActiveRecord::Base.connection.adapter_name == "SQLite" &&
          ActiveRecord::Base.connection.table_exists?("spina_pages_fts")
      end
    end

    def fts_search_pages(query, options = {})
      # Escape FTS query special characters
      escaped_query = escape_fts_query(query)
      
      # Build FTS query
      fts_query = build_fts_query(escaped_query, options)
      
      # Execute FTS search and join with pages
      # Using raw SQL to properly handle FTS5 ranking
      page_ids = ActiveRecord::Base.connection.execute(
        sanitize_sql_array([
          "SELECT page_id FROM spina_pages_fts WHERE spina_pages_fts MATCH ? ORDER BY rank",
          fts_query
        ])
      ).map { |row| row['page_id'] }

      return Page.none if page_ids.empty?

      # Get pages in ranked order
      pages = Page.where(id: page_ids)
      
      # Apply additional filters
      pages = apply_page_filters(pages, options)
      
      # Maintain FTS ranking order
      pages.order(Arel.sql("CASE #{page_ids.map.with_index { |id, i| "WHEN id = #{id} THEN #{i}" }.join(' ')} END"))
    end

    def fts_search_resources(query, options = {})
      # Escape FTS query special characters
      escaped_query = escape_fts_query(query)
      
      # Build FTS query
      fts_query = build_fts_query(escaped_query, options)
      
      # Execute FTS search and join with resources
      # Using raw SQL to properly handle FTS5 ranking
      resource_ids = ActiveRecord::Base.connection.execute(
        sanitize_sql_array([
          "SELECT resource_id FROM spina_resources_fts WHERE spina_resources_fts MATCH ? ORDER BY rank",
          fts_query
        ])
      ).map { |row| row['resource_id'] }

      return Resource.none if resource_ids.empty?

      # Get resources in ranked order
      resources = Resource.where(id: resource_ids)
      
      # Apply additional filters
      resources = apply_resource_filters(resources, options)
      
      # Maintain FTS ranking order
      resources.order(Arel.sql("CASE #{resource_ids.map.with_index { |id, i| "WHEN id = #{id} THEN #{i}" }.join(' ')} END"))
    end

    def fallback_search_pages(query, options = {})
      pages = Page.joins(:translations)
        .where(
          "LOWER(spina_page_translations.title) LIKE LOWER(:query) OR LOWER(materialized_path) LIKE LOWER(:query)",
          query: "%#{query}%"
        )
        .distinct

      apply_page_filters(pages, options)
    end

    def fallback_search_resources(query, options = {})
      resources = Resource.where(
        "LOWER(name) LIKE LOWER(:query) OR LOWER(label) LIKE LOWER(:query)",
        query: "%#{query}%"
      )

      apply_resource_filters(resources, options)
    end

    def escape_fts_query(query)
      # Escape FTS5 special characters: " * ( ) [ ] { } ^ ~ -
      query.gsub(/["*()\[\]{}^~-]/, '\\\\\\&')
    end

    def build_fts_query(query, options = {})
      # Support different query types
      case options[:query_type]
      when :phrase
        "\"#{query}\""
      when :prefix
        "#{query}*"
      when :boolean
        query # Allow user to specify boolean operators
      else
        # Default: terms with OR operator for better recall
        terms = query.split(/\s+/).map(&:strip).reject(&:blank?)
        terms.map { |term| "#{term}*" }.join(" OR ")
      end
    end

    def apply_page_filters(pages, options)
      if options[:resource_id]
        pages = pages.where(resource_id: options[:resource_id])
      end

      if options[:active_only]
        pages = pages.active
      end

      if options[:live_only]
        pages = pages.live
      end

      pages
    end

    def apply_resource_filters(resources, options)
      # Add any resource-specific filters here
      resources
    end

    def sanitize_sql_array(array)
      ActiveRecord::Base.sanitize_sql_array(array)
    end

    def fts_snippets(query, content, options = {})
      # Use SQLite's snippet function for highlighting
      escaped_query = escape_fts_query(query)
      start_tag = options[:start_tag] || '<mark>'
      end_tag = options[:end_tag] || '</mark>'
      
      # Simple highlighting for FTS matches
      terms = query.split(/\s+/).map(&:strip).reject(&:blank?)
      highlighted = content.dup
      
      terms.each do |term|
        highlighted.gsub!(/(#{Regexp.escape(term)})/i, "#{start_tag}\\1#{end_tag}")
      end
      
      highlighted
    end

    def fallback_snippets(query, content, options = {})
      # Simple regex-based highlighting
      start_tag = options[:start_tag] || '<mark>'
      end_tag = options[:end_tag] || '</mark>'
      
      terms = query.split(/\s+/).map(&:strip).reject(&:blank?)
      highlighted = content.dup
      
      terms.each do |term|
        highlighted.gsub!(/(#{Regexp.escape(term)})/i, "#{start_tag}\\1#{end_tag}")
      end
      
      highlighted
    end
  end
end