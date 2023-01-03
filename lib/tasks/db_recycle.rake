# frozen_string_literal: true

namespace :db do
  task recycle: %i[drop create migrate]
end
