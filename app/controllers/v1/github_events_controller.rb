# frozen_string_literal: true

module V1
  class GithubEventsController < V1Controller
    before_action :validate_signature
    before_action :check_if_wants_event
    around_action :ignore_duplicated_events

    WANTED_EVENTS = {
      delete: :passthrough, # branch deleted
      pull_request: %i[opened synchronize],
      push: :passthrough, # push created
      repository: %i[renamed deleted]
    }.freeze

    def create
      event = JSON.parse(request.body.read).with_indifferent_access
      method = [:process, @event_name]
      method << event[:action] if WANTED_EVENTS[@event_name].is_a? Array
      method = method.join("_")
      ActiveRecord::Base.transaction do
        case method
        when "process_delete"
          process_delete(event)
        when "process_pull_request_opened"
          process_pull_request_opened(event)
        when "process_push"
          process_push(event)
        when "process_repository_renamed"
          process_repository_renamed(event)
        when "process_repository_deleted"
          process_repository_deleted(event)
        end
      end
      head :ok
    end

    private

    # TODO
    def process_delete(_event); end

    # TODO
    def process_pull_request_opened(_event); end

    # TODO
    def process_pull_request_synchronize(_event); end

    def process_push(event)
      return unless event[:ref].start_with? "refs/heads/"

      repo = Repository.find_by(name: event.dig(:repository, :name))
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

    # TODO
    def process_repository_renamed(_event); end

    # TODO
    def process_repository_deleted(_event); end

    def check_if_wants_event
      @event_name = request.env["HTTP_X_GITHUB_EVENT"]
      return head :bad_request if @event_name.blank?

      @event_name = @event_name.to_sym
      return head :ok unless WANTED_EVENTS.key? @event_name
      return if WANTED_EVENTS[@event_name] == :passthrough

      return head :ok unless WANTED_EVENTS[@event_name].include? params[:action].to_sym
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
