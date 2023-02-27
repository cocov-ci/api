# frozen_string_literal: true

module IssueFields
  extend ActiveSupport::Concern

  included do
    enum kind: {
      style: 0,
      performance: 1,
      security: 2,
      bug: 3,
      complexity: 4,
      duplication: 5,
      convention: 6,
      quality: 7
    }

    validates :check_source, presence: true
    validates :file, presence: true
    validates :kind, presence: true
    validates :line_end, presence: true
    validates :line_start, presence: true
    validates :message, presence: true
  end
end
