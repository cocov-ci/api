# frozen_string_literal: true

json.repository { json.partial! "v1/repositories/repository", repo: repo }
json.commit { json.partial! "v1/commits/commit", commit: commit }
json.checks checks, partial: "v1/checks/check", as: :check
json.issues issues
