# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id           :bigint           not null, primary key
#  login        :citext           not null
#  github_id    :integer          not null
#  admin        :boolean          default(FALSE), not null
#  github_token :text             not null
#  avatar_url   :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_users_on_github_id  (github_id) UNIQUE
#  index_users_on_login      (login) UNIQUE
#
FactoryBot.define do
  factory :user do
    login { Faker::Internet.username }
    github_id { (Faker::Number.rand * 1e9).round }
    github_token { SecureRandom.hex(21) }
    admin { false }

    trait :admin do
      admin { true }
    end

    trait :with_emails do
      after :create do |u|
        2.times { create(:user_email, email: "#{SecureRandom.uuid}@example.org", user: u) }
      end
    end
  end
end
