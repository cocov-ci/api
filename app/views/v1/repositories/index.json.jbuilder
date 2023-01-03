# frozen_string_literal: true

json.repositories repos, partial: "v1/repositories/repository", as: :repo
json.paging paging_info(repos)
