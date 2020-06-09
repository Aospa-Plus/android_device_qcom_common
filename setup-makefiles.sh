#!/bin/bash
#
# Copyright (C) 2018-2019 The LineageOS Project
# Copyright (C) 2020 Paranoid Android
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ROOT="${MY_DIR}/../../.."

HELPER="${ROOT}/vendor/pa/build/tools/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Initialize the helper for device
setup_vendor "${COMPONENT}" "${VENDOR}" "${ROOT}" false true "" true

# Copyright headers and guards
write_headers

# The standard common blobs
write_makefiles "${MY_DIR}/${COMPONENT}/proprietary-files.txt" true

# Finish
write_footers

VENDOR_OVERLAY_FILES="${MY_DIR}/${COMPONENT}/proprietary-files-vendor-overlay.txt"
if [ -f "${VENDOR_OVERLAY_FILES}" ]; then
    # Initialize the helper for device
    setup_vendor "${COMPONENT}" "${VENDOR}" "${ROOT}" false false "$VNDNAME"-overlay true

    # Copyright headers and guards
    write_headers

    # The standard common blobs
    write_makefiles "${VENDOR_OVERLAY_FILES}" true

    # Conditionally include vendor-overlay Makefile
    printf '\n%s\n' "ifeq (\$(TARGET_IS_VENDORLESS),)" >> "$ANDROIDMK"
    printf '%s\n' "\$(call inherit-product-if-exists, "$OUTDIR"/qti-"$COMPONENT"-overlay-vendor.mk)" >> "$ANDROIDMK"
    printf '%s\n' "endif" >> "$ANDROIDMK"
    printf '%s\n' >> "$ANDROIDMK"


    # Finish
    write_footers

fi
