# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::Manifest do
  subject(:manifest) { described_class }

  it "rejects manifests with invalid roots" do
    path = fixture_file_path("manifests", "invalid_mapping.yaml")
    expect { manifest.load(path) }.to raise_error(Cocov::Manifest::InvalidManifestError)
      .with_message("Invalid manifest: Root should be a mapping")
  end

  it "rejects manifests without versions" do
    path = fixture_file_path("manifests", "no_version.yaml")
    expect { manifest.load(path) }.to raise_error(Cocov::Manifest::InvalidManifestError)
      .with_message("Invalid manifest: Missing version field")
  end

  it "rejects manifests with invalid versions" do
    path = fixture_file_path("manifests", "invalid_version.yaml")
    expect { manifest.load(path) }.to raise_error(Cocov::Manifest::InvalidManifestError)
      .with_message("Invalid manifest: Version must be a string")
  end

  it "rejects manifests with unknown versions" do
    path = fixture_file_path("manifests", "unknown_version.yaml")
    expect { manifest.load(path) }.to raise_error(Cocov::Manifest::InvalidManifestError)
      .with_message("Invalid manifest: Unsupported version bla")
  end

  it "parses valid manifests" do
    path = fixture_file_path("manifests", "v0.1alpha", "complete.yaml")
    expect(manifest.load(path)).to be_a Cocov::Manifest::V01Alpha
  end

  it "returns a sane error when extra keys are provided to coverage" do
    data = File.read(fixture_file_path("manifests", "v0.1alpha", "extra_coverage_keys.yaml"))
    expect { manifest.parse(data) }.to raise_error(Cocov::Manifest::InvalidManifestError)
      .with_message("Unexpected extra key `unexpected_key' on `coverage'")
  end

  it "returns a sane error when extra keys are provided to a plugin" do
    data = File.read(fixture_file_path("manifests", "v0.1alpha", "extra_check_keys.yaml"))
    expect { manifest.parse(data) }.to raise_error(Cocov::Manifest::InvalidManifestError)
      .with_message("Unexpected extra key `unexpected_key' on `checks.1'")
  end
end
