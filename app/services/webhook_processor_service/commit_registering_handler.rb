# frozen_string_literal: true

class WebhookProcessorService
  class CommitRegisteringHandler < BaseHandler
    wants :push

    def validate
      event[:ref].start_with? "refs/heads/"
    end

    def handle
      repo = repository_for_event or return

      sha = event.dig(:head_commit, :id)
      commit = Cocov::Redis.lock("commit:#{repo.id}:#{sha}", 1.minute) do
        commit = repo.commits.find_by(sha:)
        next commit if commit

        Commit.create!(
          repository: repo,
          sha: event.dig(:head_commit, :id),
          message: event.dig(:head_commit, :message),
          author_name: event.dig(:head_commit, :author, :name),
          author_email: event.dig(:head_commit, :author, :email)
        )
      end

      deferred_coverage = Cocov::Redis.get_json("commit:coverage:#{repo.id}:#{sha}", delete: true)
      ProcessCoverageJob.perform_later(repo.id, sha, deferred_coverage.to_json) if deferred_coverage

      ref_name = event[:ref].gsub(%r{^refs/heads/}, "")
      branch = repo.branches.find_or_initialize_by(name: ref_name)
      branch.head_id = commit.id
      branch.save!

      ProcessCommitJob.perform_later(commit.id)
    end
  end
end
