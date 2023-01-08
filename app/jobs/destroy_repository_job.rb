class DestroyRepositoryJob < ApplicationJob
  queue_as :default

  def perform(id)
    r = Repository.find(id)
    r.destroy!
  end
end
