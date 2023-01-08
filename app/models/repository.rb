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
#  github_id      :integer          not null
#
# Indexes
#
#  index_repositories_on_github_id  (github_id) UNIQUE
#  index_repositories_on_name       (name) UNIQUE
#  index_repositories_on_token      (token) UNIQUE
#
class Repository < ApplicationRecord
  before_validation :ensure_token

  validates :name, presence: true, uniqueness: true
  validates :github_id, presence: true, uniqueness: true
  validates :default_branch, presence: true
  validates :token, presence: true, uniqueness: true

  has_many :branches, dependent: :destroy
  has_many :commits, dependent: :destroy
  has_many :secrets, dependent: :destroy
  has_many :private_keys, dependent: :destroy

  def find_default_branch
    if branches.loaded?
      branches.find { |b| b.name == default_branch }
    else
      branches.where(name: default_branch).first
    end
  end

  def update_with_github_data!(data)
    self.name = data.name
    self.description = data.description
    self.default_branch = data.default_branch
    save!
  end

  def resync_with_github!
    update_with_github_data!(Cocov::GitHub.app.repo(github_id))
  end

  def find_secret(named)
    secrets.find_by(name: named) || Secret.find_by(name: named, scope: :organization)
  end

  def self.by_fuzzy_name(name)
    find_by_sql [<<-SQL.squish, { name: }]
      SELECT *
      FROM #{table_name}
      ORDER BY SIMILARITY(name, :name) DESC
      LIMIT 5
    SQL
  end

  def self.create_from_github(repo)
    repo = Cocov::GitHub.app.repo("#{Cocov::GITHUB_ORGANIZATION_NAME}/#{repo}") if repo.is_a? String
    find_or_initialize_by(github_id: repo.id).tap do |inst|
      inst.update_with_github_data! repo
    end
  end

  private

  def ensure_token
    self.token = "crt_#{SecureRandom.hex(21)}" if token.blank?
  end
end
