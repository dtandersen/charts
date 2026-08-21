#!/usr/bin/env bash
set -eu

python /patches/patch_mtp_nightly.py
python /patches/patch_mtp_boundary.py
python /patches/patch_gdn_mixed_split_v5.py

exec "$@"
