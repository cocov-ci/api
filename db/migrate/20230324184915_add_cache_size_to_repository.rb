class AddCacheSizeToRepository < ActiveRecord::Migration[7.0]
  def change
    add_column :repositories, :cache_size, :integer, limit: 8, default: 0, null: false
  end
end
