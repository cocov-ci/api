# frozen_string_literal: true

# == Schema Information
#
# Table name: user_emails
#
#  id         :bigint           not null, primary key
#  user_id    :bigint           not null
#  email      :citext           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_user_emails_on_email    (email) UNIQUE
#  index_user_emails_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :user_email do
    email { Faker::Internet.email }
    user { nil }

    trait :with_user do
      user { create(:user) }
    end
  end
end
