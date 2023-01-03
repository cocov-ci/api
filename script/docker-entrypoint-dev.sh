#!/bin/bash
set -e
bundle check || bundle install
[[ "$COCOV_ENTRYPOINT_AUTOMIGRATE" == "true" ]] && rails db:migrate
exec "$@"
