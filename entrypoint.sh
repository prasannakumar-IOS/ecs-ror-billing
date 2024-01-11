#!/bin/bash

set -e

rake db:create
rake db:migrate
rake assets:precompile

exec "$@"
