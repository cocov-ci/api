# frozen_string_literal: true

class UpdateCommitsAuthorJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    u = User.find(user_id)
    emails = u.emails.pluck(:email)
    Commit.transaction do
      Commit
        .where("author_email IN (:emails) AND (user_id IS NULL OR user_id != :user_id)", user_id:, emails:)
        .each do |c|
          c.user_id = user_id
          c.save!
        end
    end
  end
end
