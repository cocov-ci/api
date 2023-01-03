# frozen_string_literal: true

require "rspec/expectations"

RSpec::Matchers.define :have_json_body do |body|
  diffable

  match do |response|
    body = body.with_indifferent_access if body.is_a? Hash

    values_match? body, response.json
  end
end

RSpec::Matchers.define :be_a_json_error do |*path|
  match do |response|
    values_match? path.join("."), response.json[:code]
  end
end
