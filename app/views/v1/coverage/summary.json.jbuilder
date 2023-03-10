# frozen_string_literal: true

json.call(cov, :status)

json.repository { json.partial! "v1/repositories/repository", repo: repo }
json.commit { json.partial! "v1/commits/commit", commit: commit }

if cov.completed?
  json.call(cov, :percent_covered, :lines_total, :lines_covered)
  json.least_covered least_covered do |c|
    json.call(c, :id, :file, :percent_covered)
  end
end
