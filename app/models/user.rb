# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id            :bigint           not null, primary key
#  login         :citext           not null
#  github_id     :integer          not null
#  admin         :boolean          default(FALSE), not null
#  github_token  :text             not null
#  github_scopes :text             not null
#  avatar_url    :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_users_on_github_id  (github_id) UNIQUE
#  index_users_on_login      (login) UNIQUE
#
class User < ApplicationRecord
  validates :login, presence: true, uniqueness: true
  validates :github_id, presence: true, uniqueness: true
  validates :github_token, presence: true
  validates :github_scopes, presence: true

  has_many :emails, class_name: :UserEmail, dependent: :destroy
  has_many :tokens, class_name: :UserToken, dependent: :destroy
  has_many :commits, dependent: :nullify
  has_many :service_tokens, dependent: :destroy, foreign_key: :owner_id, inverse_of: :owner
  has_many :secrets, dependent: :destroy, foreign_key: :owner_id, inverse_of: :owner

  def scopes
    github_scopes.split(",")
  end

  def scopes=(val)
    self.github_scopes = val.join(",")
  end

  def self.with_github_data!(user, token_data)
    find_or_initialize_by(github_id: user.id).tap do |inst|
      inst.login = user.login
      inst.avatar_url = user.avatar_url
      inst.github_token = token_data[:access_token]
      inst.github_scopes = token_data[:scope]
      inst.save!
      inst.update_emails!
    end
  end

  def update_emails!
    UserEmail.transaction do
      emails.destroy_all
      github_client.emails.filter(&:verified?).map(&:email).each do |email|
        emails.where(email:).first_or_create
      end
    end
    UpdateCommitsAuthorJob.perform_later(id)
  end

  def github_client
    Cocov::GitHub.for_user(github_token)
  end

  def make_auth_token!
    tokens.create! kind: :auth
  end
end
