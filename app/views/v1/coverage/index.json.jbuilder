# frozen_string_literal: true

json.repository { json.partial! "v1/repositories/repository", repo: repo }
json.commit { json.partial! "v1/commits/commit", commit: commit }

json.status commit.coverage_status
if commit&.coverage&.processed?
  json.files files do |file|
    json.call(file, :id, :file, :percent_covered)
  end
end
