# frozen_string_literal: true

json.branches branches, partial: "v1/branches/branch", as: :branch
json.paging paging_info(branches)
