# frozen_string_literal: true

class ApplicationService
  def self.call(*args, **kwargs)
    new.call(*args, **kwargs)
  end
end
