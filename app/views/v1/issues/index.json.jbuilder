# frozen_string_literal: true

json.repository { json.partial! "v1/repositories/repository", repo: repo }
json.commit { json.partial! "v1/commits/commit", commit: commit }

json.issues issues, partial: "v1/issues/issue", as: :issue
json.paging paging_info(issues)
