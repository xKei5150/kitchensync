#!/bin/sh
set -eu

exec npm exec --yes --package firebase-tools@15.18.0 -- firebase "$@"
