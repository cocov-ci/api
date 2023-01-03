# frozen_string_literal: true

json.call(commit, :id, :author_email, :author_name, :checks_status,
  :coverage_status, :sha, :coverage_percent, :issues_count, :condensed_status)

if commit.association(:user).loaded?
  json.user do
    json.name commit.user.login
    json.avatar "https://github.com/#{commit.user.login}.png"
  end
end
