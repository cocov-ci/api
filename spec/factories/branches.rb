# frozen_string_literal: true

# == Schema Information
#
# Table name: branches
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  name          :citext           not null
#  issues        :integer
#  coverage      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  head_id       :bigint
#
# Indexes
#
#  index_branches_on_head_id                 (head_id)
#  index_branches_on_repository_id           (repository_id)
#  index_branches_on_repository_id_and_name  (repository_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (head_id => commits.id)
#  fk_rails_...  (repository_id => repositories.id)
#
FactoryBot.define do
  factory :branch do
    repository { nil }
    name { "master" }
    issues { nil }
    coverage { nil }

    trait :with_repository do
      repository { create(:repository) }
    end

    trait :with_commit do
      head { create(:commit, :with_user, repository:) }
    end
  end
end
