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
#
# Indexes
#
#  index_repository_members_on_repository_id                       (repository_id)
#  index_repository_members_on_repository_id_and_github_member_id  (repository_id,github_member_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
require "rails_helper"

RSpec.describe RepositoryMember do
  pending "add some examples to (or delete) #{__FILE__}"
end
