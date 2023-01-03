# frozen_string_literal: true

class GitService
  class BaseStorage
    def file_not_found!(path)
      raise FileNotFoundError, "File #{path} does not exist"
    end

    def download_commit(_commit)
      raise NotImplementedError
    end

    def file_for_commit(_commit, path:)
      raise NotImplementedError
    end

    def base_path
      raise NotImplementedError
    end

    def repo_path(repo)
      base = base_path
      name = Digest::SHA1.hexdigest(repo)
      case base
      when Pathname
        base.join(name)
      when nil
        name
      else
        "#{base}/#{name}"
      end
    end

    def commit_path(commit)
      base = repo_path(commit.repository.name)
      if base.is_a? Pathname
        base.join(commit.sha)
      else
        "#{base}/#{commit.sha}"
      end
    end
  end
end
