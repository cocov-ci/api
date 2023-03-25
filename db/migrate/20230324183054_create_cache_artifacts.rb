class CreateCacheArtifacts < ActiveRecord::Migration[7.0]
  def change
    create_table :cache_artifacts do |t|
      t.references :repository, null: false, foreign_key: true
      t.citext :name, null: false, index: true
      t.integer :size, limit: 8, null: false 
      t.timestamp :last_used_at
      t.citext :engine, null: false
      t.string :mime, null: false

      t.timestamps
    end
    
    add_index :cache_artifacts, [:repository_id, :name, :engine], unique: true
  end
end
