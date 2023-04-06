# frozen_string_literal: true

json.repository { json.partial! "v1/repositories/repository", repo: repo }
json.commit { json.partial! "v1/commits/commit", commit: commit }
json.checks checks, partial: "v1/checks/check", as: :check
json.issues issues

if check_set
  if check_set.canceling
    json.status "canceling"
  else
    json.status check_set.status
  end

  if check_set.failure?
    json.failure_reason check_set.error_kind
    json.failure_details check_set.error_extra if check_set.error_extra.present?
  end
else
  json.status "waiting"
end

json.status commit.check_set&.status || "waiting"
