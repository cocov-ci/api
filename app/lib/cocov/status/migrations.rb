# frozen_string_literal: true

module Cocov
  module Status
    class Migrations
      def self.up_to_date?
        conn = ActiveRecord::Base.connection
        return false unless conn.schema_migration.table_exists?

        conn.migration_context.migrations_status.map(&:first).all? "up"
      end
    end
  end
end
