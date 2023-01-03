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
require "rails_helper"

RSpec.describe UserEmail do
  subject(:email) { build(:user_email, :with_user) }

  it_behaves_like "a validated model", %i[
    email
    user
  ]

  it "does not allow duplicated emails" do
    email.save!
    other = described_class.new(user: email.user, email: email.email)
    expect(other).not_to be_valid
  end
end
