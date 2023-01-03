# frozen_string_literal: true

json.call(repo, :id, :name, :description, :token)

if (branch = repo.find_default_branch)
  json.coverage branch.coverage
  json.issues branch.issues
end
