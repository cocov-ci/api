# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cocov::SchemaValidator do
  subject(:validator) do
    described_class.with do
      hash(
        sha: string,
        issues: hash(
          alt(string, symbol) => opt(
            array(
              hash(
                uid: string,
                kind: string,
                file: string,
                line_start: integer,
                line_end: integer,
                message: string
              )
            )
          )
        )
      )
    end
  end

  it "returns its inspectable value" do
    expect(validator.inspect).to eq "hash(:sha => string, :issues => hash(alt(string, symbol) => " \
                                    "array(hash(:uid => string, :kind => string, :file => string, " \
                                    ":line_start => integer, :line_end => integer, :message => string))?))"
  end

  valid_object = {
    sha: "",
    issues: {
      "a" => [
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" },
        { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: "" }
      ]
    }
  }.freeze

  cases = {
    "sha" => {
      obj: valid_object.dup.merge({ sha: 0 }),
      msg: "Expected sha to match string. Assertion failed due to current object's value: 0"
    },
    "issues" => {
      obj: valid_object.dup.merge({ issues: 0 }),
      msg: "Expected issues to match Hash. Assertion failed due to current object's value: 0"
    },
    "issues.a.0.uid" => {
      obj: valid_object.dup.merge({
        issues: {
          "a" => [
            { uid: 0, file: "", line_start: 0, line_end: 0, message: "", kind: "" }
          ]
        }
      }),
      msg: "Expected issues.a.0.uid to match string. Assertion failed due to current object's value: 0"
    },
    "issues.a.0.file" => {
      obj: valid_object.dup.merge({
        issues: {
          "a" => [
            { uid: "", file: 0, line_start: 0, line_end: 0, message: "", kind: "" }
          ]
        }
      }),
      msg: "Expected issues.a.0.file to match string. Assertion failed due to current object's value: 0"
    },
    "issues.a.0.line_start" => {
      obj: valid_object.dup.merge({
        issues: {
          "a" => [
            { uid: "", file: "", line_start: "", line_end: 0, message: "", kind: "" }
          ]
        }
      }),
      msg: "Expected issues.a.0.line_start to match Integer. Assertion failed due to current object's value: \"\""
    },
    "issues.a.0.line_end" => {
      obj: valid_object.dup.merge({
        issues: {
          "a" => [
            { uid: "", file: "", line_start: 0, line_end: "", message: "", kind: "" }
          ]
        }
      }),
      msg: "Expected issues.a.0.line_end to match Integer. Assertion failed due to current object's value: \"\""
    },
    "issues.a.0.message" => {
      obj: valid_object.dup.merge({
        issues: {
          "a" => [
            { uid: "", file: "", line_start: 0, line_end: 0, message: 0, kind: "" }
          ]
        }
      }),
      msg: "Expected issues.a.0.message to match string. Assertion failed due to current object's value: 0"
    },
    "issues.a.0.kind" => {
      obj: valid_object.dup.merge({
        issues: {
          "a" => [
            { uid: "", file: "", line_start: 0, line_end: 0, message: "", kind: 0 }
          ]
        }
      }),
      msg: "Expected issues.a.0.kind to match string. Assertion failed due to current object's value: 0"
    }
  }.freeze

  cases.each do |name, data|
    it "rejects when #{name} is invalid" do
      expect { validator.validate(data[:obj]) }.to raise_error(Cocov::SchemaValidator::ValidationError) do |err|
        expect(err.to_s).to eq(data[:msg])
      end
    end
  end
end
