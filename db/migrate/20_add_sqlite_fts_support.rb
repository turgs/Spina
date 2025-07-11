class AddSqliteFtsSupport < ActiveRecord::Migration[8.0]
  def up
    # Only create FTS tables for SQLite
    if connection.adapter_name == "SQLite"
      # Create FTS virtual table for pages
      connection.execute <<-SQL
        CREATE VIRTUAL TABLE spina_pages_fts USING fts5(
          page_id UNINDEXED,
          title,
          description,
          materialized_path
        );
      SQL

      # Create FTS virtual table for resources
      connection.execute <<-SQL
        CREATE VIRTUAL TABLE spina_resources_fts USING fts5(
          resource_id UNINDEXED,
          name,
          label
        );
      SQL

      # Populate initial data for pages
      connection.execute <<-SQL
        INSERT INTO spina_pages_fts(page_id, title, description, materialized_path)
        SELECT 
          p.id,
          COALESCE(pt.title, ''),
          COALESCE(pt.description, ''),
          COALESCE(pt.materialized_path, '')
        FROM spina_pages p
        LEFT JOIN spina_page_translations pt ON p.id = pt.page_id
        WHERE p.active = 1 AND p.draft = 0;
      SQL

      # Populate initial data for resources
      connection.execute <<-SQL
        INSERT INTO spina_resources_fts(resource_id, name, label)
        SELECT 
          r.id,
          COALESCE(r.name, ''),
          COALESCE(rt.label, '')
        FROM spina_resources r
        LEFT JOIN spina_resource_translations rt ON r.id = rt.resource_id;
      SQL

      # Create triggers to keep FTS tables synchronized
      # Pages triggers
      connection.execute <<-SQL
        CREATE TRIGGER spina_pages_fts_insert AFTER INSERT ON spina_pages
        WHEN NEW.active = 1 AND NEW.draft = 0
        BEGIN
          INSERT INTO spina_pages_fts(page_id, title, description, materialized_path)
          SELECT 
            NEW.id,
            COALESCE(pt.title, ''),
            COALESCE(pt.description, ''),
            COALESCE(pt.materialized_path, '')
          FROM spina_page_translations pt
          WHERE pt.page_id = NEW.id;
        END;
      SQL

      connection.execute <<-SQL
        CREATE TRIGGER spina_pages_fts_update AFTER UPDATE ON spina_pages
        BEGIN
          DELETE FROM spina_pages_fts WHERE page_id = OLD.id;
          INSERT INTO spina_pages_fts(page_id, title, description, materialized_path)
          SELECT 
            NEW.id,
            COALESCE(pt.title, ''),
            COALESCE(pt.description, ''),
            COALESCE(pt.materialized_path, '')
          FROM spina_page_translations pt
          WHERE pt.page_id = NEW.id AND NEW.active = 1 AND NEW.draft = 0;
        END;
      SQL

      connection.execute <<-SQL
        CREATE TRIGGER spina_pages_fts_delete AFTER DELETE ON spina_pages
        BEGIN
          DELETE FROM spina_pages_fts WHERE page_id = OLD.id;
        END;
      SQL

      # Page translations triggers
      connection.execute <<-SQL
        CREATE TRIGGER spina_page_translations_fts_insert AFTER INSERT ON spina_page_translations
        BEGIN
          DELETE FROM spina_pages_fts WHERE page_id = NEW.page_id;
          INSERT INTO spina_pages_fts(page_id, title, description, materialized_path)
          SELECT 
            p.id,
            COALESCE(NEW.title, ''),
            COALESCE(NEW.description, ''),
            COALESCE(NEW.materialized_path, '')
          FROM spina_pages p
          WHERE p.id = NEW.page_id AND p.active = 1 AND p.draft = 0;
        END;
      SQL

      connection.execute <<-SQL
        CREATE TRIGGER spina_page_translations_fts_update AFTER UPDATE ON spina_page_translations
        BEGIN
          DELETE FROM spina_pages_fts WHERE page_id = NEW.page_id;
          INSERT INTO spina_pages_fts(page_id, title, description, materialized_path)
          SELECT 
            p.id,
            COALESCE(NEW.title, ''),
            COALESCE(NEW.description, ''),
            COALESCE(NEW.materialized_path, '')
          FROM spina_pages p
          WHERE p.id = NEW.page_id AND p.active = 1 AND p.draft = 0;
        END;
      SQL

      connection.execute <<-SQL
        CREATE TRIGGER spina_page_translations_fts_delete AFTER DELETE ON spina_page_translations
        BEGIN
          DELETE FROM spina_pages_fts WHERE page_id = OLD.page_id;
        END;
      SQL

      # Resources triggers
      connection.execute <<-SQL
        CREATE TRIGGER spina_resources_fts_insert AFTER INSERT ON spina_resources
        BEGIN
          INSERT INTO spina_resources_fts(resource_id, name, label)
          SELECT 
            NEW.id,
            COALESCE(NEW.name, ''),
            COALESCE(rt.label, '')
          FROM spina_resource_translations rt
          WHERE rt.resource_id = NEW.id;
        END;
      SQL

      connection.execute <<-SQL
        CREATE TRIGGER spina_resources_fts_update AFTER UPDATE ON spina_resources
        BEGIN
          DELETE FROM spina_resources_fts WHERE resource_id = OLD.id;
          INSERT INTO spina_resources_fts(resource_id, name, label)
          SELECT 
            NEW.id,
            COALESCE(NEW.name, ''),
            COALESCE(rt.label, '')
          FROM spina_resource_translations rt
          WHERE rt.resource_id = NEW.id;
        END;
      SQL

      connection.execute <<-SQL
        CREATE TRIGGER spina_resources_fts_delete AFTER DELETE ON spina_resources
        BEGIN
          DELETE FROM spina_resources_fts WHERE resource_id = OLD.id;
        END;
      SQL

      # Resource translations triggers
      connection.execute <<-SQL
        CREATE TRIGGER spina_resource_translations_fts_insert AFTER INSERT ON spina_resource_translations
        BEGIN
          DELETE FROM spina_resources_fts WHERE resource_id = NEW.resource_id;
          INSERT INTO spina_resources_fts(resource_id, name, label)
          SELECT 
            r.id,
            COALESCE(r.name, ''),
            COALESCE(NEW.label, '')
          FROM spina_resources r
          WHERE r.id = NEW.resource_id;
        END;
      SQL

      connection.execute <<-SQL
        CREATE TRIGGER spina_resource_translations_fts_update AFTER UPDATE ON spina_resource_translations
        BEGIN
          DELETE FROM spina_resources_fts WHERE resource_id = NEW.resource_id;
          INSERT INTO spina_resources_fts(resource_id, name, label)
          SELECT 
            r.id,
            COALESCE(r.name, ''),
            COALESCE(NEW.label, '')
          FROM spina_resources r
          WHERE r.id = NEW.resource_id;
        END;
      SQL

      connection.execute <<-SQL
        CREATE TRIGGER spina_resource_translations_fts_delete AFTER DELETE ON spina_resource_translations
        BEGIN
          DELETE FROM spina_resources_fts WHERE resource_id = OLD.resource_id;
        END;
      SQL
    end
  end

  def down
    if connection.adapter_name == "SQLite"
      # Drop triggers
      connection.execute "DROP TRIGGER IF EXISTS spina_pages_fts_insert;"
      connection.execute "DROP TRIGGER IF EXISTS spina_pages_fts_update;"
      connection.execute "DROP TRIGGER IF EXISTS spina_pages_fts_delete;"
      connection.execute "DROP TRIGGER IF EXISTS spina_page_translations_fts_insert;"
      connection.execute "DROP TRIGGER IF EXISTS spina_page_translations_fts_update;"
      connection.execute "DROP TRIGGER IF EXISTS spina_page_translations_fts_delete;"
      connection.execute "DROP TRIGGER IF EXISTS spina_resources_fts_insert;"
      connection.execute "DROP TRIGGER IF EXISTS spina_resources_fts_update;"
      connection.execute "DROP TRIGGER IF EXISTS spina_resources_fts_delete;"
      connection.execute "DROP TRIGGER IF EXISTS spina_resource_translations_fts_insert;"
      connection.execute "DROP TRIGGER IF EXISTS spina_resource_translations_fts_update;"
      connection.execute "DROP TRIGGER IF EXISTS spina_resource_translations_fts_delete;"

      # Drop FTS tables
      connection.execute "DROP TABLE IF EXISTS spina_pages_fts;"
      connection.execute "DROP TABLE IF EXISTS spina_resources_fts;"
    end
  end
end