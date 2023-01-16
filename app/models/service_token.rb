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
class ServiceToken < ApplicationRecord
  include LastUsageTracker

  belongs_to :owner, class_name: :User

  before_validation :ensure_value

  validates :hashed_token, presence: true, uniqueness: true
  validates :description, presence: true

  def self.hash_token(token)
    HASHER.base64digest(token)
  end

  def self.by_token(token)
    where(hashed_token: hash_token(token)).first
  end

  attr_reader :value

  def value=(val)
    self.hashed_token = self.class.hash_token(val)
    @value = val
  end

  def ensure_value
    self.value = "cos_#{SecureRandom.hex(32)}" if hashed_token.nil?
  end

  def kind
    :service
  end

  def service?
    true
  end

  def auth?
    false
  end

  def personal?
    false
  end
end
