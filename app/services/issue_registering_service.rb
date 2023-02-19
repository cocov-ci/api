# frozen_string_literal: true

class IssueRegisteringService < ApplicationService
  VALIDATOR = Cocov::SchemaValidator.with do
    hash(
      sha: string,
      source: alt(string, symbol),
      issues: opt(
        array(
          hash(
            uid: string,
            kind: string,
            file: string,
            line_start: integer,
            line_end: integer,
            message: string
          )
        )
      )
    )
  end

  def self.validate(data) = VALIDATOR.validate(data)

  def call(data, repo)
    @data = data
    @repo = repo

    @commit = @repo.commits.find_by!(sha: @data[:sha])

    register_issues!
  end

  def register_issues!
    check_source = Cocov::Manifest.cleanup_plugin_name(@data[:source])
    to_create = @data[:issues]&.map do |issue|
      issue
        .slice(:kind, :file, :line_start, :line_end, :message, :uid)
        .merge({
          status: Issue.statuses[:new],
          check_source:,
          commit_id: @commit.id
        })
    end

    return if to_create.blank?

    Issue.insert_all(to_create)
    @commit.reset_counters
  end
end
