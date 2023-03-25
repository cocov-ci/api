# == Schema Information
#
# Table name: cache_artifacts
#
#  id            :bigint           not null, primary key
#  repository_id :bigint           not null
#  name          :citext           not null
#  size          :bigint           not null
#  last_used_at  :datetime
#  engine        :citext           not null
#  mime          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_cache_artifacts_on_name                               (name)
#  index_cache_artifacts_on_repository_id                      (repository_id)
#  index_cache_artifacts_on_repository_id_and_name_and_engine  (repository_id,name,engine) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#
require 'rails_helper'

RSpec.describe CacheArtifact, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
