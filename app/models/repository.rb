# frozen_string_literal: true

# == Schema Information
#
# Table name: repositories
#
#  id             :bigint           not null, primary key
#  name           :citext           not null
#  description    :text
#  default_branch :citext           not null
#  token          :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_repositories_on_name   (name) UNIQUE
#  index_repositories_on_token  (token) UNIQUE
#
class Repository < ApplicationRecord
  before_validation :ensure_token

  validates :name, presence: true, uniqueness: true
  validates :default_branch, presence: true
  validates :token, presence: true, uniqueness: true

  has_many :branches, dependent: :destroy_async
  has_many :commits, dependent: :destroy_async
  has_many :secrets, dependent: :destroy_async
  has_many :private_keys, dependent: :destroy_async

  def find_default_branch
    if branches.loaded?
      branches.find { |b| b.name == default_branch }
    else
      branches.where(name: default_branch).first
    end
  end

  def self.by_fuzzy_name(name)
    find_by_sql [<<-SQL.squish, { name: }]
      SELECT *
      FROM #{table_name}
      ORDER BY SIMILARITY(name, :name) DESC
      LIMIT 5
    SQL
  end

  private

  def ensure_token
    self.token = SecureRandom.hex(21) if token.blank?
  end
end
