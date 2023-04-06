# frozen_string_literal: true

module CommitGitHubIntegration
  extend ActiveSupport::Concern

  # Public: Resets all checks and replaces it with a CheckSet with
  # an internal error. Do not use this method in case checks failed
  # to pass or if a single one catastrophically failed. For this and
  # other states, use #notify_check_status
  #
  # error - The error to be reported. Must be either a symbol representing
  #         one of Cocov::CheckSet::ErrorKind, or an instance of
  #         Cocov::Manifest::InvalidManifestError.
  #
  # Returns nothing.
  def notify_check_fatal_failure!(error)
    code = nil
    message = nil

    case error
    when Cocov::Manifest::InvalidManifestError
      code = error.code
      message = error.message
    when Symbol
      code = error
    else
      raise ArgumentError, "Invalid value for notify_check_fatal_failure!"
    end

    transaction do
      reset_check_set!
      cs = check_set
      cs.status = :failure
      cs.error_kind = code
      cs.error_extra = message
      cs.save!
    end

    description = Cocov::GitHubStatuses.instance.get(code)

    create_github_status(:error,
      context: "cocov",
      description:,
      url: checks_url)
  end

  # Public: Notifies GitHub of the current overall checks status.
  #
  # status - The status to report. Valid values are :canceled,
  #          :internal_error, :no_issues, :no_manifest, and :running.
  #
  # Returns nothing
  def notify_check_status(status)
    github_message = Cocov::GitHubStatuses.instance.get(status)

    # On GitHub's lingo, :error should be used when for instance an
    # exception is thrown; :failure represents a failed test.

    github_status = case status
    when :internal_error
      :error
    when :canceled
      :failure
    when :no_issues, :no_manifest
      :success
    when :running
      :pending
    else
      raise ArgumentError("Invalid status #{status}")
    end

    create_github_status(github_status,
      context: "cocov",
      description: github_message,
      url: checks_url)
  end
end
