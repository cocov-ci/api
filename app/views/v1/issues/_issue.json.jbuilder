# frozen_string_literal: true

json.call(issue, :id, :kind, :status, :file, :uid, :line_start, :line_end, :message, :check_source, :status_reason)
json.affected_file do
  line_start = [0, issue.line_start - 2].max
  line_end = issue.line_end + 2
  range = (line_start..line_end)

  begin
    file_content = GitService.file_for_commit(issue.commit.sha, path: issue.file, range: range)
    line_count = file_content.count("\n")
    json.first_line line_start
    json.last_line line_start + line_count
    json.content file_content
    json.status :ok
  rescue GitService::CommitNotDownloaded
    json.status :not_downloaded
  rescue StandardError => e
    logger.error("Failed obtaining file `#{issue.file}' from commit " \
                 "#{issue.commit.sha} (repo ID #{issue.commit.repository_id}): #{e}")
    json.status :errored
  end
end

if (assig = issue.assignee)
  json.assignee do
    json.partial! "v1/users/user", user: assig
  end
end
