# frozen_string_literal: true

# == Schema Information
#
# Table name: private_keys
#
#  id            :bigint           not null, primary key
#  scope         :integer          not null
#  repository_id :bigint
#  name          :citext           not null
#  encrypted_key :binary           not null
#  digest        :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_private_keys_on_name                              (name)
#  index_private_keys_on_repository_id                     (repository_id)
#  index_private_keys_on_scope                             (scope)
#  index_private_keys_on_scope_and_name_and_repository_id  (scope,name,repository_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
class PrivateKey < ApplicationRecord
  enum scope: { organization: 0, repository: 1 }, _suffix: :scope

  belongs_to :repository, optional: true
  before_validation :make_digest!

  validates :scope, presence: true
  validates :repository, presence: true, if: -> { repository_scope? }
  validates :name, presence: true, uniqueness: { scope: %i[scope repository] }
  validates :encrypted_key, presence: true
  validates :digest, presence: true
  validate :ensure_key_validity

  def key
    return nil if encrypted_key.nil?

    Cocov::Crypto.decrypt(encrypted_key)
  end

  def key=(value)
    if value.nil?
      self.encrypted_key = nil
      return
    end

    self.encrypted_key = Cocov::Crypto.encrypt(value)
  end

  def parsed_key
    return if key.nil?

    @parsed_key ||= SSHData::PrivateKey.parse(key || "").first
  end

  def self.valid?(key)
    SSHData::PrivateKey.parse(key)
    true
  rescue SSHData::Error
    false
  end

  private

  def make_digest!
    self.digest = begin
      if parsed_key.blank?
        "invalid"
      else
        "SHA256:#{parsed_key.public_key.fingerprint}"
      end
    rescue SSHData::Error
      "invalid"
    end
  end

  def ensure_key_validity
    return if digest != "invalid"

    errors.add(:key, "is invalid")
  end
end
