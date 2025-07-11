# This migration comes from spina (originally 13)
class AddJsonAttributesToSpinaAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :spina_accounts, :json_attributes, :json
  end
end
