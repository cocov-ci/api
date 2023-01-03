# frozen_string_literal: true

json.call branch, :id, :name, :coverage, :issues, :condensed_status
if branch.head
  json.head do
    json.partial! "v1/commits/commit", commit: branch.head
  end
end
