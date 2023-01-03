# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateCommitsAuthorJob do
  subject(:job) { described_class.new }

  it "updates all commits by email" do
    u1 = create(:user, :with_emails)
    u2 = create(:user, :with_emails)

    repo = create(:repository)

    3.times { create(:commit, repository: repo, author_email: u1.emails.pluck(:email).sample(1).first) }
    2.times { create(:commit, repository: repo, author_email: u2.emails.pluck(:email).sample(1).first) }
    create_list(:commit, 5, repository: repo)

    expect(Commit.where(user: u1).count).to eq 0
    job.perform(u1.id)
    expect(Commit.where(user: u1).count).to eq 3
  end
end
