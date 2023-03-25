# frozen_string_literal: true

# == Schema Information
#
# Table name: cache_artifacts
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  name          :citext           not null
#  name_hash     :string           not null
#  size          :bigint           not null
#  last_used_at  :datetime
#  engine        :citext           not null
#  mime          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_cache_artifacts_on_name                                    (name)
#  index_cache_artifacts_on_name_hash                               (name_hash)
#  index_cache_artifacts_on_repository_id                           (repository_id)
#  index_cache_artifacts_on_repository_id_and_name_and_engine       (repository_id,name,engine) UNIQUE
#  index_cache_artifacts_on_repository_id_and_name_hash_and_engine  (repository_id,name_hash,engine) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
require "rails_helper"

RSpec.describe CacheArtifact do
  subject(:arti) { build(:cache_artifact, :with_repository) }

  it_behaves_like "a validated model", %i[
    name
    name_hash
    size
    engine
    mime
  ]

  it "validates name uniqueness" do
    arti.save!
    second = arti.dup
    second.id = nil
    second.name_hash = "bla"
    expect(second).not_to be_valid
  end

  it "validates name_hash uniqueness" do
    arti.save!
    second = arti.dup
    second.id = nil
    second.name = "bla"
    expect(second).not_to be_valid
  end
end
