# frozen_string_literal: true

class IssueRegisteringService < ApplicationService
  VALIDATOR = Cocov::SchemaValidator.with do
    hash(
      sha: string,
      issues: hash(
        alt(string, symbol) => opt(
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
    )
  end

  def self.validate(data)
    VALIDATOR.validate(data)
  end

  def call(data, repo, status)
    @data = data
    @repo = repo
    @status = status

    prepare_commit!
    cleanup_issues!
    register_issues!
    update_branches!
  end

  def register_issues!
    to_create = {}
    @data[:issues].map do |source, issues|
      next if issues.nil?

      issues.each do |issue|
        db_issue = issue
          .slice(:kind, :file, :line_start, :line_end, :message, :uid)
          .merge({
            status: Issue.statuses[:new],
            check_source: source
          })
        to_create[db_issue[:uid].strip.to_s] = db_issue
      end
    end

    Issue.transaction do
      to_create.values.each { @commit.issues.create! _1 }

      @commit.issues_count = @commit.issues.count
      @commit.checks_status = @status
      @commit.save!
      IssueHistory.register_history! @commit, @commit.issues_count

      issue_commit_status
    end
  end

  def issue_commit_status
    if @commit.checks_errored?
      # TODO: url
      @commit.create_github_status(:failure, context: "cocov", description: "An internal error occurred")
      return
    end

    if @commit.issues_count.zero?
      @commit.create_github_status(:success, context: "cocov", description: "No issues detected")
      return
    end
    qty = @commit.issues_count
    name = "issue#{qty == 1 ? "" : "s"}"

    # TODO: url
    @commit.create_github_status(:failure, context: "cocov", description: "#{qty} #{name} detected")
  end

  def prepare_commit!
    @commit = @repo.commits.find_by!(sha: @data[:sha])
  end

  def cleanup_issues!
    @commit
      .issues
      .where.not(status: Issue.statuses[:ignored])
      .delete_all
  end

  def update_branches!
    @repo.branches.where(head_id: @commit.id).each do |branch|
      branch.issues = @commit.issues_count
      branch.save!
    end
  end
end
