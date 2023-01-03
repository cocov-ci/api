# frozen_string_literal: true

guard :rspec, cmd: "rspec" do
  watch(%r{^app/(controllers|jobs|lib|models)/(.+)\.rb}) { "spec" }
  watch(%r{^spec/.+_spec\.rb$}) { |m| (m[0]).to_s }
  watch("spec/spec_helper.rb")  { "spec" }
end
