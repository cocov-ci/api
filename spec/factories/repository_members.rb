# frozen_string_literal: true

# == Schema Information
#
# Table name: repository_members
#
#  id               :bigint           not null, primary key
#  repository_id    :bigint           not null
#  github_member_id :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  level            :integer          not null
#
# Indexes
#
#  index_repository_members_on_github_member_id                    (github_member_id)
#  index_repository_members_on_repository_id                       (repository_id)
#  index_repository_members_on_repository_id_and_github_member_id  (repository_id,github_member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
FactoryBot.define do
  factory :repository_member do
    repository { nil }
    github_member_id { 1 }
    level { :user }

    trait :admin do
      level { :admin }
    end
  end
end
