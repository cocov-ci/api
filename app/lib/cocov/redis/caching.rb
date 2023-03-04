# frozen_string_literal: true

module Cocov
  class Redis
    module Caching
      def cached_value(key, ex: 1.day, encoder: nil)
        raise ArgumentError, "encoder must be either nil, or a Class" if !encoder.nil? && !encoder.is_a?(Class)

        return yield if cache.nil?

        data = cache.getex(key, ex:)
        if data.nil?
          data = yield
          writeable_data = if encoder
            encoder.encode(data)
          else
            data
          end
          cache.set(key, writeable_data, ex:)
        elsif encoder
          begin
            data = encoder.decode(data)
          rescue StandardError
            cache.del(key)
            return nil
          end
        end
        data
      end

      def cached_file(key, &)
        cached_value(key, ex: CACHED_FILE_EXPIRATION, encoder: JsonEncoder, &)
      end

      def cached_file_language(key, &)
        cached_value(key, ex: CACHED_FILE_EXPIRATION, encoder: JsonEncoder, &)
      end

      def cached_formatted_file(key, &)
        cached_value(key, ex: CACHED_FILE_EXPIRATION, encoder: JsonEncoder, &)
      end

      def org_repo_key(key) = "cocov:github_org_repos:#{key}"

      def organization_repositories
        lock("organization_repos", 2000) do
          status, etag, updated, items = cache.mget(
            org_repo_key(:status),
            org_repo_key(:etag),
            org_repo_key(:updated_at),
            org_repo_key(:items)
          )

          return { status: :updating } if status == "updating"

          return nil if [status, etag, updated, items].any?(&:nil?)

          return nil if status != "present"

          # At this point, data is present. Just arrange it
          # and make it ready for processing.
          {
            status: :ok,
            etag:,
            items:,
            updated_at: Time.zone.parse(updated)
          }
        end
      end

      def set_organization_repositories_updating
        lock("organization_repos", 2000) do
          cache.set(org_repo_key(:status), "updating")
        end
      end

      def set_organization_repositories(items:, etag:)
        lock("organization_repos", 2000) do
          cache.pipelined do |pipe|
            pipe.set(org_repo_key(:status), "present")
            pipe.set(org_repo_key(:updated_at), Time.now.iso8601)
            pipe.set(org_repo_key(:etag), etag)
            pipe.set(org_repo_key(:items), items)
          end
        end
      end
    end
  end
end
