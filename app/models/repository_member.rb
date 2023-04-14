# frozen_string_literal: true

# == Schema Information
#
# Table name: repository_members
#
#  id               :bigint           not null, primary key
#  repository_id    :bigint           not null
#  github_member_id :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  level            :integer          not null
#
# Indexes
#
#  index_repository_members_on_github_member_id                    (github_member_id)
#  index_repository_members_on_repository_id                       (repository_id)
#  index_repository_members_on_repository_id_and_github_member_id  (repository_id,github_member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
class RepositoryMember < ApplicationRecord
  belongs_to :repository
  enum level: {
    user: 0,
    maintainer: 1,
    admin: 2
  }

  validates :github_member_id, presence: true, uniqueness: { scope: [:repository_id] }
  validates :level, presence: true

  def self.level_from_github(obj)
    return :admin if obj.admin
    return :maintainer if obj.maintain

    :user
  end

  def self.count_users_permissions(users:)
    raise ArgumentError, "Only User objects are accepted by #count_users_permissions" if users.any? { !_1.is_a? User }

    conn = ActiveRecord::Base.connection
    query = %{
        SELECT repository_members.level AS level,
               count(repository_members.level) AS count,
               repository_members.github_member_id AS github_member_id
        FROM repository_members
        WHERE github_member_id IN (#{users.map { conn.quote(_1.github_id) }.join(",")})
        GROUP BY level, github_member_id
    }
    data = conn.execute(query)
    result = Hash.new { [] }
    data.each do |row|
      result[row["github_member_id"]] += [row.slice("level", "count").with_indifferent_access]
    end

    result.to_h do |k, v|
      v = levels.transform_values do |val|
        v.find { _1["level"] == val }&.fetch(:count) || 0
      end
      [users.find { _1.github_id == k }.id, v]
    end
  end
end
