# frozen_string_literal: true

json.repository { json.partial! "v1/repositories/repository", repo: repo }

json.artifacts items, partial: "v1/cache/artifact", as: :artifact
json.paging paging_info(items)
