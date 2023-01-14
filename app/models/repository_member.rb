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
end
