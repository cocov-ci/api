# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::Manifest::V01Alpha do
  subject(:spec) { described_class }

  let(:data) { YAML.load(fixture_file("manifests/v0.1alpha/complete.yaml")).with_indifferent_access }

  it "validates and organizes data" do
    manifest = spec.new(data)

    expect(manifest.coverage.path).to eq "./coverage/coverage.json"
    expect(manifest.coverage.format).to eq "simplecov"
    expect(manifest.coverage.min_percent).to eq 90

    checks = [
      "cocov/rubocop:v0.1",
      "cocov/brakeman:v0.1"
    ]

    checks.each_with_index do |chk, idx|
      expect(manifest.checks[idx].plugin).to eq chk
    end
  end

  describe "coverage" do
    %i[path format].each do |key|
      it "rejects when coverage.#{key} is set, but empty" do
        d = data.dup
        d[:coverage][key] = ""

        expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
          .with_message("Expected coverage.#{key} to not be blank")
      end
    end

    messages = {
      min_percent: "Expected coverage.min_percent to match Integer. " \
                   "Assertion failed due to current object's value: \"a\"",
      path: "Expected coverage.path to match string. Assertion failed due to current object's value: 0"
    }
    { path: 0, format: 1, min_percent: "a" }.each do |key, value|
      it "rejects when coverage.#{key} has an invalid value" do
        d = data.dup
        d[:coverage][key] = value
        expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
          .with_message(messages[key])
      end
    end
  end

  describe "checks" do
    it "rejects checks without plugins" do
      d = data.dup
      d[:checks][1].delete(:plugin)

      expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
        .with_message("checks.1 is missing a required key: plugin")
    end

    it "rejects checks with invalid plugins" do
      d = data.dup
      d[:checks][1][:plugin] = 1

      expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
        .with_message("Expected checks.1.plugin to match string. Assertion failed due to current object's value: 1")
    end

    it "handles checks with environments" do
      d = YAML.load(fixture_file("manifests/v0.1alpha/check_envs.yaml")).with_indifferent_access
      result = spec.new(d)
      expect(result.checks.first.envs.length).to eq 1
      expect(result.checks.first.envs["GOPRIVATE"]).to eq "github.com/cocov-ci"
    end

    it "handles checks with mounts" do
      d = YAML.load(fixture_file("manifests/v0.1alpha/check_mounts.yaml")).with_indifferent_access
      result = spec.new(d)
      expect(result.checks.first.mounts.length).to eq 1
      expect(result.checks.first.mounts.first.source).to eq "secrets:GIT_CONFIG"
      expect(result.checks.first.mounts.first.destination).to eq "~/.gitconfig"
    end
  end
end
