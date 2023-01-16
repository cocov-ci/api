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
class UserToken < ApplicationRecord
  include LastUsageTracker

  enum kind: { auth: 0, personal: 1 }

  before_validation :ensure_value

  validates :kind, presence: true
  validates :hashed_token, presence: true, uniqueness: true

  belongs_to :user

  def self.hash_token(token)
    HASHER.base64digest(token)
  end

  def expired?
    expires_at.past?
  end

  def service?
    false
  end

  attr_reader :value

  def value=(val)
    self.hashed_token = self.class.hash_token(val)
    @value = val
  end

  def token_prefix
    personal? ? "cop_" : "coa_"
  end

  def ensure_value
    self.value = "#{token_prefix}#{SecureRandom.hex(32)}" if hashed_token.nil?
  end

  def self.by_token(token)
    includes(:user).where(<<-SQL.squish, hash_token(token)).first
      hashed_token = ? AND (expires_at IS NULL OR expires_at >= NOW())
    SQL
  end
end
