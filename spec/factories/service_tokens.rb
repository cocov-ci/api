# frozen_string_literal: true

# == Schema Information
#
# Table name: service_tokens
#
#  id           :bigint           not null, primary key
#  hashed_token :text             not null
#  description  :text             not null
#  owner_id     :bigint           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  last_used_at :datetime
#
# Indexes
#
#  index_service_tokens_on_hashed_token  (hashed_token) UNIQUE
#  index_service_tokens_on_owner_id      (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (owner_id => users.id)
#
FactoryBot.define do
  factory :service_token do
    description { "Some description" }

    trait :with_owner do
      owner { create(:user) }
    end
  end
end
