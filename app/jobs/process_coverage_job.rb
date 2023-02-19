# frozen_string_literal: true

class ProcessCoverageJob < ApplicationJob
  queue_as :default

  def prepare_coverage_files(files, coverage)
    parser = Cocov::CoverageParser.new
    lines_total = 0
    lines_covered = 0

    files.each do |file, encoded|
      parser.reset
      raw_data = Base64.decode64(encoded)
      parser.parse(raw_data)

      cov_file = CoverageFile.new(coverage:, file:, raw_data:)
      cov_file.apply_lines(parser.lines)
      lines_total += cov_file.lines_total
      lines_covered += cov_file.lines_covered
      cov_file.save!
    end

    coverage.tap do |cov|
      cov.lines_total = lines_total
      cov.lines_covered = lines_covered
      cov.percent_covered = lines_total.zero? ? 0 : ((lines_covered.to_f / lines_total) * 100)
      cov.status = :processed
      cov.save!
    end
  end

  def perform(repo_id, sha, data)
    r = Repository.find(repo_id)
    commit = r.commits.find_by!(sha:)
    data = JSON.parse(data)

    cover = ActiveRecord::Base.transaction do
      commit.reset_coverage! status: :processing
      commit.coverage
    end

    cov = ActiveRecord::Base.transaction do
      prepare_coverage_files(data, cover).tap do |coverage|
        commit.coverage_percent = coverage.percent_covered
        commit.coverage.processed!
        CoverageHistory.register_history! commit, coverage.percent_covered
        r.branches.where(head_id: commit.id).each do |b|
          b.coverage = coverage.percent_covered
          b.save!
        end
      end
    end

    coverage_url = "#{Cocov::UI_BASE_URL}/repos/#{r.name}/commits/#{sha}/coverage"
    manifest = ManifestService.manifest_for_commit(commit)
    if manifest.nil? || manifest.coverage.nil?
      commit.create_github_status(:success,
        context: "cocov/coverage",
        description: "#{cov.percent_covered.round(2)}% covered",
        url: coverage_url)
      return
    end

    if manifest.coverage.min_percent.present?
      min = manifest.coverage.min_percent
      commit.minimum_coverage = min
      commit.save!

      if cov.percent_covered < min
        commit.create_github_status(:failure,
          context: "cocov/coverage",
          description: "#{cov.percent_covered.round(2)}% covered (at least #{min}% is required)",
          url: coverage_url)
      else
        commit.create_github_status(:success,
          context: "cocov/coverage",
          description: "#{cov.percent_covered.round(2)}% covered",
          url: coverage_url)
      end
    end
  rescue StandardError => e
    commit.coverage.errored!
    raise e
  end
end
