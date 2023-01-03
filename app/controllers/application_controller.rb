# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from Cocov::Errors::StopError, with: :managed_error
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def not_found!
    error! :not_found
  end

  def record_not_found
    managed_error(Cocov::Errors::StopError.new([:not_found], {}))
  end

  def managed_error(error)
    payload = {
      code: error.path.join(".")
    }.merge(Cocov::Errors.instance[*error.path])

    payload["message"] = payload["message"] % error.args

    render status: payload.delete("status").to_sym,
      json: payload
  end

  def error!(*path, **args) = raise Cocov::Errors::StopError.new(path, args)
end
