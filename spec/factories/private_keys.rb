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
FactoryBot.define do
  factory :private_key do
    scope { :organization }
    repository { nil }
    name { Faker::TvShows::RickAndMorty.location }
    key { Rails.root.join("spec/fixtures/ssh_key").read }
  end
end
