# frozen_string_literal: true

# == Schema Information
#
# Table name: commits
#
#  id               :bigint           not null, primary key
#  repository_id    :bigint           not null
#  sha              :citext           not null
#  author_name      :string           not null
#  author_email     :string           not null
#  message          :text             not null
#  user_id          :bigint
#  issues_count     :integer
#  coverage_percent :integer
#  clone_status     :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  minimum_coverage :integer
#  clone_size       :bigint
#
# Indexes
#
#  index_commits_on_repository_id          (repository_id)
#  index_commits_on_sha                    (sha)
#  index_commits_on_sha_and_repository_id  (sha,repository_id) UNIQUE
#  index_commits_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (repository_id => repositories.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Commit do
  subject(:commit) { build(:commit, :with_repository) }

  it_behaves_like "a validated model", %i[
    message
    author_email
    author_name
    sha
    repository
  ]

  describe "#create_github_status" do
    before { stub_configuration! }

    it "creates statuses with all fields" do
      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      expect(gh_app).to receive(:create_status).with(
        "#{@github_organization_name}/#{commit.repository.name}",
        commit.sha,
        "success",
        description: "foo",
        target_url: "bar",
        context: "cocov"
      )

      commit.create_github_status(:success, context: "cocov", description: "foo", url: "bar")
    end

    it "creates statuses without optional fields" do
      gh_app = double(:github_app)
      allow(Cocov::GitHub).to receive(:app).and_return(gh_app)
      expect(gh_app).to receive(:create_status).with(
        "#{@github_organization_name}/#{commit.repository.name}",
        commit.sha,
        "success",
        description: "foo",
        context: "cocov"
      )

      commit.create_github_status(:success, context: "cocov", description: "foo")
    end

    describe "determines its condensed status" do
      it "determines yellow status" do
        c = described_class.new
        c.build_coverage(status: :waiting)
        c.build_check_set(status: :waiting)
        expect(c.condensed_status).to eq :yellow
      end

      it "determines red status" do
        c = described_class.new
        c.build_coverage(status: :errored)
        c.build_check_set(status: :waiting)
        expect(c.condensed_status).to eq :red
      end

      it "determines green status" do
        c = described_class.new
        c.build_coverage(status: :completed)
        c.build_check_set(status: :completed)
        expect(c.condensed_status).to eq :green
      end
    end
  end
end
