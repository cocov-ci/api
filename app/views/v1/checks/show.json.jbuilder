# frozen_string_literal: true

json.partial! "v1/checks/check", check: check

json.call(check, :error_output) if check.errored?
