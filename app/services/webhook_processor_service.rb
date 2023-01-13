# frozen_string_literal: true

class WebhookProcessorService < ApplicationService
  WANTED_EVENTS = %i[public repository team_add member organization membership delete push].freeze

  def self.register(klass, event)
    @handlers[event] ||= []
    @handlers[event] << klass
  end

  def self.reload!
    @handlers = {}
    Dir[File.join(__dir__, "webhook_processor_service/*.rb")].each do |handler|
      require handler
    end
  end

  def call(event, payload)
    event = [event] unless event.is_a? Array

    [[event.first], event]
      .uniq
      .map { self.class.instance_variable_get(:@handlers)[_1] }
      .flatten
      .compact
      .uniq
      .each do |handler|
        inst = handler.new(event.first, payload)
        next unless inst.validate

        inst.handle
      rescue StandardError => e
        Rails.logger.error("Failed running handler for #{handler}: #{e.message}\n#{e.backtrace.join("\n")}")
      end
  end
end
