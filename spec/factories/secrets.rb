# frozen_string_literal: true

# == Schema Information
#
# Table name: secrets
#
#  id            :bigint           not null, primary key
#  scope         :integer          not null
#  name          :citext           not null
#  repository_id :bigint
#  secure_data   :binary           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  last_used_at  :datetime
#  owner_id      :bigint           not null
#
# Indexes
#
#  index_secrets_on_name                              (name)
#  index_secrets_on_owner_id                          (owner_id)
#  index_secrets_on_repository_id                     (repository_id)
#  index_secrets_on_scope                             (scope)
#  index_secrets_on_scope_and_name_and_repository_id  (scope,name,repository_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#  fk_rails_...  (repository_id => repositories.id)
#
FactoryBot.define do
  factory :secret do
    scope { :organization }
    name { Faker::TvShows::TwinPeaks.location.parameterize.tr("-", "_") }
    data { Faker::TvShows::TwinPeaks.quote }
    repository { nil }

    trait :with_owner do
      owner { create(:user) }
    end

    trait :with_repository do
      repository { create(:repository) }
    end
  end
end
