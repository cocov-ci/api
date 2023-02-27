# frozen_string_literal: true

# == Schema Information
#
# Table name: repositories
#
#  id                       :bigint           not null, primary key
#  name                     :citext           not null
#  description              :text
#  default_branch           :citext           not null
#  token                    :text             not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  github_id                :integer          not null
#  issue_ignore_rules_count :integer          default(0), not null
#
# Indexes
#
#  index_repositories_on_github_id  (github_id) UNIQUE
#  index_repositories_on_name       (name) UNIQUE
#  index_repositories_on_token      (token) UNIQUE
#
FactoryBot.define do
  factory :repository do
    name { Faker::App.name.parameterize }
    default_branch { "master" }
    sequence(:github_id, 10_000)
  end
end
