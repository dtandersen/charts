#!/usr/bin/env bash
set -eu

python /patches/patch_mtp_nightly.py
python /patches/patch_mtp_boundary.py

exec "$@"
