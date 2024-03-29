# frozen_string_literal: true

json.call(repo, :id, :name, :description, :token, :default_branch)

if (branch = repo.find_default_branch)
  json.coverage branch.coverage
  json.issues branch.issues

  if (head = branch.head)
    json.head do
      json.call(head, :checks_status, :coverage_status)
      json.files_count head.coverage.files.count if head.coverage&.completed?
    end
  end
end
