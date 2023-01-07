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
#
# Indexes
#
#  index_secrets_on_name                              (name)
#  index_secrets_on_repository_id                     (repository_id)
#  index_secrets_on_scope                             (scope)
#  index_secrets_on_scope_and_name_and_repository_id  (scope,name,repository_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
class Secret < ApplicationRecord
  enum scope: { organization: 0, repository: 1 }, _suffix: :scope

  belongs_to :repository, optional: true

  validates :scope, presence: true
  validates :repository, presence: true, if: -> { repository_scope? }
  validates :name, presence: true, uniqueness: { scope: %i[scope repository] }
  validates :secure_data, presence: true

  def data=(value)
    if value.nil?
      self.secure_data = nil
      return
    end

    self.secure_data = Cocov::Crypto.encrypt(value)
  end

  def data
    Cocov::Crypto.decrypt(secure_data)
  end

  def generate_authorization
    auth_id = "csa_#{SecureRandom.hex(24)}"
    digest = OpenSSL::Digest::SHA256.hexdigest(auth_id)
    obj_id = Base64.encode64(Cocov::Crypto.encrypt(id.to_s))
    Cocov::Redis.register_secret_authorization(digest, obj_id)

    auth_id
  end

  def self.from_authorization(id)
    digest = OpenSSL::Digest::SHA256.hexdigest(id)
    obj = Cocov::Redis.void_secret_authorization(digest)
    return if obj.nil?

    find(Cocov::Crypto.decrypt(Base64.decode64(obj)))
  end
end
