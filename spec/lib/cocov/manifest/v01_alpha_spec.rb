# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::Manifest::V01Alpha do
  subject(:spec) { described_class }

  let(:data) { YAML.load(fixture_file("manifests/v0.1alpha/complete.yaml")).with_indifferent_access }

  it "validates and organizes data" do
    manifest = spec.new(data)
    expect(manifest.coverage.min_percent).to eq 90

    checks = [
      "cocov/rubocop:v0.1",
      "cocov/brakeman:v0.1"
    ]

    checks.each_with_index do |chk, idx|
      expect(manifest.checks[idx].plugin).to eq chk
    end

    excludes = [
      "coverage/*",
      "spec/**/.ignore"
    ]

    excludes.each_with_index do |p, idx|
      expect(manifest.exclude_paths[idx]).to eq p
    end
  end

  describe "coverage" do
    messages = {
      min_percent: "Expected coverage.min_percent to match Integer. " \
                   "Assertion failed due to current object's value: \"a\""
    }
    { min_percent: "a" }.each do |key, value|
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

  describe "excludes" do
    it "rejects when a exclude key is empty" do
      d = data.dup
      d[:exclude_paths] = [""]
      expect { spec.new(d) }.to raise_error(Cocov::Manifest::InvalidManifestError)
        .with_message("Expected exclude_paths.0 to not be blank")
    end
  end

  describe "defaults" do
    let(:data) { YAML.load(fixture_file("manifests/v0.1alpha/with_defaults.yaml")).with_indifferent_access }

    it "accepts defaults for checks" do
      s = spec.new(data)
      s.checks.each do |c|
        expect(c.envs).to eq({ "TEST" => "true" })
        expect(c.mounts.length).to eq 1
        expect(c.mounts.first.source).to eq "secrets:FOO"
        expect(c.mounts.first.destination).to eq "~/test"
      end
    end

    it "merges defaults with plugin definitions" do
      data[:checks][0][:mounts] = [
        { source: "secrets:TEST", destination: "/foobar" }
      ]

      s = spec.new(data)
      c = s.checks[0]
      expect(c.mounts.length).to eq 2
      expect(c.mounts.first.source).to eq "secrets:TEST"
      expect(c.mounts.first.destination).to eq "/foobar"
      expect(c.mounts.second.source).to eq "secrets:FOO"
      expect(c.mounts.second.destination).to eq "~/test"
    end

    it "rejects conflicting default mounts" do
      data[:defaults][:checks][:mounts] = [
        { source: "secrets:BLA", destination: "~/test" },
        { source: "secrets:BLE", destination: "~/test" }
      ]
      expect { spec.new(data) }.to raise_error(Cocov::Manifest::InvalidManifestError)
        .with_message("Duplicated mount destination `~/test' in defaults definition")
    end

    it "rejects conflicting plugin mounts" do
      data[:checks][0][:mounts] = [
        { source: "secrets:BLA", destination: "~/test" },
        { source: "secrets:BLE", destination: "~/test" }
      ]
      expect { spec.new(data) }.to raise_error(Cocov::Manifest::InvalidManifestError)
        .with_message("Duplicated mount destination `~/test' in plugin `cocov/rubocop:v0.1'")
    end

    it "allows plugins to override defaults" do
      data[:checks][0][:mounts] = [
        { source: "secrets:BLA", destination: "~/test" }
      ]

      s = spec.new(data)
      c = s.checks[0]
      expect(c.mounts.length).to eq 1
      expect(c.mounts.first.source).to eq "secrets:BLA"
      expect(c.mounts.first.destination).to eq "~/test"
    end
  end
end
