# frozen_string_literal: true

# == Schema Information
#
# Table name: branches
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  name          :citext           not null
#  issues        :integer
#  coverage      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  head_id       :bigint
#
# Indexes
#
#  index_branches_on_head_id                 (head_id)
#  index_branches_on_repository_id           (repository_id)
#  index_branches_on_repository_id_and_name  (repository_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (head_id => commits.id)
#  fk_rails_...  (repository_id => repositories.id)
#
class Branch < ApplicationRecord
  validates :name, presence: true, uniqueness: { scope: [:repository_id] }

  belongs_to :repository
  belongs_to :head, class_name: :Commit, optional: true

  def condensed_status
    return :gray if head.nil?

    head.condensed_status
  end
end
