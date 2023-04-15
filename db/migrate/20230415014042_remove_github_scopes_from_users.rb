class RemoveGithubScopesFromUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :github_scopes, :text
  end
end
