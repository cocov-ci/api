class AddGithubIdToRepositories < ActiveRecord::Migration[7.0]
  def change
    add_column :repositories, :github_id, :integer
    Repository.all.each do |r|
      r.github_id = Cocov::GitHub.app.repo("#{Cocov::GITHUB_ORGANIZATION_NAME}/#{r.name}").id
      r.save!
    end
    change_column_null :repositories, :github_id, false, 0
    add_index :repositories, :github_id, unique: true
  end
end
