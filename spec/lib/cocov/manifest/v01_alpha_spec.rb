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
      "cocov-ci/rubocop:v0.1",
      "cocov-ci/brakeman:v0.1"
    ]

    checks.each_with_index do |chk, idx|
      expect(manifest.checks[idx].plugin).to eq chk
    end
  end

  describe "coverage" do
    %i[path format].each do |key|
      it "rejects when coverage.#{key} is missing" do
        d = data.dup
        d[:coverage].delete(key)

        expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
          .with_message("coverage.#{key} should not be empty")
      end
    end

    messages = {
      min_percent: "Expected one of Integer or nil, but found String"
    }
    { path: 0, format: 1, min_percent: "a" }.each do |key, value|
      it "rejects when coverage.#{key} has an invalid value" do
        d = data.dup
        d[:coverage][key] = value
        expected_type = if value.is_a? Integer
                          String
                        else
                          Integer
                        end

        expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
          .with_message("coverage.#{key}: #{messages.fetch(key,
            "Expected #{expected_type}, but found #{value.class}")}")
      end
    end
  end

  describe "checks" do
    it "rejects checks without plugins" do
      d = data.dup
      d[:checks][1].delete(:plugin)

      expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
        .with_message("checks.1.plugin should not be empty")
    end

    it "rejects checks with invalid plugins" do
      d = data.dup
      d[:checks][1][:plugin] = 1

      expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
        .with_message("checks.1.plugin: Expected String, but found Integer")
    end
  end
end
