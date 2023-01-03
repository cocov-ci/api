# frozen_string_literal: true

json.secrets secrets, partial: "v1/secrets/secret", as: :secret
json.paging paging_info(secrets)
