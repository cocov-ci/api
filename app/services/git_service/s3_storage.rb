# frozen_string_literal: true

class GitService
  class S3Storage < BaseStorage
    def initialize
      super
      @s3 = Aws::S3::Resource.new
      @bucket_name = Cocov::GIT_SERVICE_S3_STORAGE_BUCKET_NAME
      @bucket = @s3.bucket(@bucket_name)
    end

    def base_path
      nil
    end

    def commit_exists?(commit)
      key = commit_path(commit)
      @bucket.object("#{key}.tar.zst").exists?
    end

    def download_commit(commit)
      base = Dir.mktmpdir
      into = "#{base}/#{commit.sha}"
      Git.clone(commit, into:)
      repo = repo_path(commit.repository.name)
      Exec.exec("aws s3 cp --recursive --only-show-errors --follow-symlinks . s3://#{@bucket_name}/#{repo}/",
        chdir: base,
        env: ENV)
    ensure
      FileUtils.rm_rf(base)
    end

    def file_for_commit(commit, path:)
      key = "#{commit_path(commit)}/#{path}"
      @bucket.object(key).get.body.string
    rescue Aws::S3::Errors::NoSuchKey
      file_not_found! path
    end

    def destroy_repository(repository)
      key = repository_path(repository.name)
      @bucket.objects(prefix: "#{key}/").batch_delete!
    end
  end
end
