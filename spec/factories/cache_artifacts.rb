# frozen_string_literal: true

# == Schema Information
#
# Table name: cache_artifacts
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  name          :citext           not null
#  name_hash     :string           not null
#  size          :bigint           not null
#  last_used_at  :datetime
#  engine        :citext           not null
#  mime          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_cache_artifacts_on_name                                    (name)
#  index_cache_artifacts_on_name_hash                               (name_hash)
#  index_cache_artifacts_on_repository_id                           (repository_id)
#  index_cache_artifacts_on_repository_id_and_name_and_engine       (repository_id,name,engine) UNIQUE
#  index_cache_artifacts_on_repository_id_and_name_hash_and_engine  (repository_id,name_hash,engine) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
FactoryBot.define do
  factory :cache_artifact do
    repository { nil }
    name { SecureRandom.hex(32) }
    name_hash { Digest::SHA1.hexdigest(name) }
    size { 1024 }
    last_used_at { Time.zone.now }
    engine { "test" }
    created_at { Time.zone.now }
    mime { "application/octet-stream" }

    trait :with_repository do
      repository { create(:repository) }
    end
  end
end
