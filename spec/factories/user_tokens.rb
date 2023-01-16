# frozen_string_literal: true

# == Schema Information
#
# Table name: user_tokens
#
#  id           :bigint           not null, primary key
#  user_id      :bigint           not null
#  kind         :integer          not null
#  hashed_token :text             not null
#  expires_at   :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  last_used_at :datetime
#
# Indexes
#
#  index_user_tokens_on_hashed_token  (hashed_token) UNIQUE
#  index_user_tokens_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :user_token do
    user { nil }
    kind { :auth }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :expires do
      expires_at { 1.day.from_now }
    end

    trait :with_user do
      user { create(:user) }
    end
  end
end
