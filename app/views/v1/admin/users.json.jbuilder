# frozen_string_literal: true

json.users users do |u|
  json.user do
    json.call(u, :id, :login, :avatar_url, :admin)
  end
  json.permissions counts[u.id] unless u.admin?
end

json.paging paging_info(users)
