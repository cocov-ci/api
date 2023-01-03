# frozen_string_literal: true

json.private_keys private_keys, partial: "v1/private_keys/private_key", as: :private_key
json.paging paging_info(private_keys)
