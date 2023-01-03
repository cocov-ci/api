# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  HASHER = Digest::SHA256

  def locking(timeout:, &block)
    raise "cannot lock unpersisted record" unless persisted?

    resource_id = "record:#{self.class.name.demodulize}:#{id}"
    Cocov::Redis.lock(resource_id, timeout, &block)
  end
end
