# frozen_string_literal: true

# == Schema Information
#
# Table name: cache_tools
#
#  id           :bigint           not null, primary key
#  name         :citext           not null
#  name_hash    :string           not null
#  size         :integer          not null
#  last_used_at :datetime
#  engine       :citext           not null
#  mime         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_cache_tools_on_engine                (engine)
#  index_cache_tools_on_last_used_at          (last_used_at)
#  index_cache_tools_on_name_and_engine       (name,engine) UNIQUE
#  index_cache_tools_on_name_hash             (name_hash)
#  index_cache_tools_on_name_hash_and_engine  (name_hash,engine) UNIQUE
#
class CacheTool < ApplicationRecord
  validates :name, presence: true, uniqueness: { scope: :engine }
  validates :name_hash, presence: true, uniqueness: { scope: :engine }
  validates :size, presence: true
  validates :engine, presence: true
  validates :mime, presence: true
end
