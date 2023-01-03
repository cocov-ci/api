# frozen_string_literal: true

json.issues issues, partial: "v1/issues/issue", as: :issue
json.paging paging_info(issues)
