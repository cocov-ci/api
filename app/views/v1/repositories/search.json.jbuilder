# frozen_string_literal: true

json.array! repos do |repo|
  json.call(repo, :name, :description)
end
