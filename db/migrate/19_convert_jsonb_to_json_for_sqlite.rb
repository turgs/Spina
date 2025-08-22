class ConvertJsonbToJsonForSqlite < ActiveRecord::Migration[7.0]
  def up
    # Convert jsonb columns to json (text) for SQLite compatibility
    if connection.adapter_name == 'SQLite'
      change_column :spina_accounts, :json_attributes, :json if column_exists?(:spina_accounts, :json_attributes)
      change_column :spina_pages, :json_attributes, :json if column_exists?(:spina_pages, :json_attributes)
      change_column :spina_resources, :slug, :json if column_exists?(:spina_resources, :slug)
      change_column :spina_settings, :preferences, :json if column_exists?(:spina_settings, :preferences)
    end
  end

  def down
    # Convert back to jsonb for PostgreSQL
    if connection.adapter_name == 'PostgreSQL'
      change_column :spina_accounts, :json_attributes, :jsonb if column_exists?(:spina_accounts, :json_attributes)
      change_column :spina_pages, :json_attributes, :jsonb if column_exists?(:spina_pages, :json_attributes)
      change_column :spina_resources, :slug, :jsonb if column_exists?(:spina_resources, :slug)
      change_column :spina_settings, :preferences, :jsonb if column_exists?(:spina_settings, :preferences)
    end
  end
end