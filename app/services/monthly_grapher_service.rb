# frozen_string_literal: true

class MonthlyGrapherService < ApplicationService
  def call(repo, kind, branch: nil)
    raise ArgumentError, "Expected a repository instance" unless repo.is_a? Repository

    model = case kind
            when :issues
              IssueHistory
            when :coverage
              CoverageHistory
            else
              raise ArgumentError, "invalid value `#{kind}' for parameter 'kind'"
            end

    branch = case branch
             when nil
               repo.find_default_branch&.id || 0
             when Branch
               branch.id
             when Integer
               branch
             when String
               Branch.find_by(name: branch, repository: repo).id
             else
               raise ArgumentError, "invalid value `#{branch}' for parameter 'branch'"
             end

    stop = Time.zone.now.utc.end_of_day
    start = stop - 1.month

    cache_key = "repo:history:#{kind}:#{repo.id}:#{start.to_i}:#{stop.to_i}"
    cache_encoder = Cocov::Redis::JsonEncoder
    Cocov::Redis.cached_value(cache_key, encoder: cache_encoder) do
      model.history_for(repo, branch, start, stop).pluck(:value)
    end
  end
end
