# frozen_string_literal: true

json.users users do |u|
  json.user u
  json.permissions counts[u.id] unless u.admin?
end

json.paging paging_info(users)
