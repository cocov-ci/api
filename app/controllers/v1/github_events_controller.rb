# frozen_string_literal: true

module V1
  class GithubEventsController < V1Controller
    before_action :validate_signature
    before_action :event_wanted?
    around_action :ignore_duplicated_events

    WANTED_EVENTS = {
      delete: :passthrough, # branch deleted
      push: :passthrough, # push created
      repository: %i[renamed deleted edited]
    }.freeze

    def create
      event = @event
      method = [:process, @event_name]
      method << event[:action] if WANTED_EVENTS[@event_name].is_a? Array
      method = method.join("_")
      ActiveRecord::Base.transaction do
        case method
        when "process_delete"
          process_delete(event)
        when "process_push"
          process_push(event)
        when "process_repository_renamed"
          process_repository_renamed(event)
        when "process_repository_deleted"
          process_repository_deleted(event)
        when "process_repository_edited"
          process_repository_edited(event)
        end
      end
      head :ok
    end

    private

    def process_delete(event)
      return if event.dig(:ref_type) != "branch"

      repo = Repository.find_by(github_id: event.dig(:repository, :id))
      return if repo.nil?

      branch = repo.branches.find_by(name: event.dig(:ref))
      return if branch.nil?

      branch.destroy
    end

    def process_push(event)
      return unless event[:ref].start_with? "refs/heads/"

      repo = Repository.find_by(github_id: event.dig(:repository, :id))
      return if repo.nil?

      sha = event.dig(:head_commit, :id)
      commit = Cocov::Redis.lock("commit:#{repo.id}:#{sha}", 1.minute) do
        commit = repo.commits.find_by(sha:)
        unless commit
          commit = Commit.new(
            repository: repo,
            sha: event.dig(:head_commit, :id),
            message: event.dig(:head_commit, :message),
            author_name: event.dig(:head_commit, :author, :name),
            author_email: event.dig(:head_commit, :author, :email)
          )
          commit.save!
        end
        commit
      end

      deferred_coverage = Cocov::Redis.get_json("commit:coverage:#{repo.id}:#{sha}", delete: true)
      ProcessCoverageJob.perform_later(repo.id, sha, deferred_coverage.to_json) if deferred_coverage

      ref_name = event[:ref].gsub(%r{^refs/heads/}, "")
      branch = repo.branches.find_or_initialize_by(name: ref_name)
      branch.head_id = commit.id
      branch.save!

      ProcessCommitJob.perform_later(commit.id)
    end

    def process_repository_renamed(event)
      repo = Repository.find_by(github_id: event.dig(:repository, :id))
      return if repo.nil?

      repo.name = event.dig(:repository, :name)
      repo.save!
    end

    def process_repository_deleted(event)
      repo = Repository.find_by(github_id: event.dig(:repository, :id))
      return if repo.nil?

      DestroyRepositoryJob.perform_later(repo.id)
    end

    def process_repository_edited(event)
      wanted_changes = [:description, :default_branch]
      changes = event.dig(:changes).keys.map(&:to_sym)
      return if (wanted_changes & changes).empty?

      repo = Repository.find_by(github_id: event.dig(:repository, :id))
      return if repo.nil?

      repo.description = event.dig(:repository, :description)
      repo.default_branch = event.dig(:repository, :default_branch)
      repo.save!
    end

    def event_wanted?
      @event_name = request.env["HTTP_X_GITHUB_EVENT"]
      return head :bad_request if @event_name.blank?

      @event_name = @event_name.to_sym

      request.body.rewind
      @event = JSON.parse(request.body.read, symbolize_names: true).with_indifferent_access

      return head :ok unless WANTED_EVENTS.key? @event_name

      return if WANTED_EVENTS[@event_name] == :passthrough

      return head :bad_request if @event[:action].blank?

      return head :ok unless WANTED_EVENTS[@event_name].include? @event[:action].to_sym
    end

    def ignore_duplicated_events
      event_id = request.env["HTTP_X_GITHUB_DELIVERY"]
      return head :bad_request if event_id.blank?

      event_key = "github:event:delivery:#{event_id}"
      Cocov::Redis.lock("github:delivery:#{event_id}", 1.minute) do
        head :ok and return if Cocov::Redis.instance.exists? event_key

        yield

        Cocov::Redis.instance.set event_key, 1, ex: 2.days if response.successful?
      end
    end

    def validate_signature
      return if Cocov::GITHUB_WEBHOOK_SECRET_KEY.blank?

      request.body.rewind
      hex_digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), Cocov::GITHUB_WEBHOOK_SECRET_KEY,
        request.body.read)
      head :forbidden unless Rack::Utils.secure_compare("sha256=#{hex_digest}", request.env["HTTP_X_HUB_SIGNATURE_256"])
    end
  end
end
