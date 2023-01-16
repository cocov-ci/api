# frozen_string_literal: true

# Requires TimeNormalizer to be included before this concern.
module HistoryProvider
  extend ActiveSupport::Concern

  class_methods do
    def history_field(name)
      @history_field = name.to_sym
    end

    def history_for(repository, branch, date_start, date_end)
      raise "Can't use #history_for without calling #history_field" unless @history_field

      repository = repository.id if repository.is_a? Repository
      branch = branch.id if branch.is_a? Branch
      date_start = coerce_time_param(date_start)
      date_end = coerce_time_param(date_end)

      last_known = where("repository_id = :id AND created_at < :start", id: repository, start: date_start)
        .order(created_at: :desc)
        .limit(1)
        .pick(@history_field)

      params = { repo_id: repository, start: date_start, end: date_end, branch_id: branch }

      entries_between = ActiveRecord::Base.connection.execute(
        ApplicationRecord.sanitize_sql([<<-SQL.squish, params])
          SELECT
            COUNT(*) AS count
          FROM #{table_name}
          WHERE
            repository_id = :repo_id
            AND branch_id = :branch_id
            AND DATE_TRUNC('day', created_at) >= DATE_TRUNC('day', :start::timestamp)
            AND DATE_TRUNC('day', created_at) <= DATE_TRUNC('day', :end::timestamp)
        SQL
      ).to_a.first["count"]

      return [] if entries_between.zero? && last_known.nil?

      data = ActiveRecord::Base.connection.execute(
        ApplicationRecord.sanitize_sql([<<-SQL.squish, params])
          SELECT
            DATE_TRUNC('day', created_at) AS date,
            MAX(#{@history_field})
          FROM #{table_name}
          WHERE
            repository_id = :repo_id
            AND branch_id = :branch_id
            AND DATE_TRUNC('day', created_at) >= DATE_TRUNC('day', :start::timestamp)
            AND DATE_TRUNC('day', created_at) <= DATE_TRUNC('day', :end::timestamp)
          GROUP BY date
          ORDER BY date
        SQL
      ).to_a.map { { date: _1["date"].to_date, value: _1["max"] } }

      normalize_time_array(date_array(date_start, date_end), data, last_known)
    end

    def register_history!(commit, value)
      raise "Can't use #register_history! without calling #history_field" unless @history_field

      cid = commit.id
      transaction do
        commit.repository.branches.where(head_id: cid).find_each do |branch|
          create!(branch:, repository: commit.repository, @history_field => value)
        end
      end
    end
  end
end
