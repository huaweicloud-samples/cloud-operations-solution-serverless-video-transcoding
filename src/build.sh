#!/bin/bash
# SPDX-License-Identifier: MIT
# Build script: packages each FunctionGraph function into a zip with
# dependencies and shared layer code.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
LAYERS_DIR="${SCRIPT_DIR}/layers"

mkdir -p "${DIST_DIR}"

# Function to package a function
# Usage: package_function <function_name>
package_function() {
    local func_name="$1"
    local func_dir="${SCRIPT_DIR}/${func_name}"
    local tmp_dir="${DIST_DIR}/${func_name}_tmp"

    echo "==> Packaging ${func_name}..."

    # Clean and create temp directory
    rm -rf "${tmp_dir}"
    mkdir -p "${tmp_dir}/lib"

    # Copy handler and DAL files
    cp "${func_dir}"/*.js "${tmp_dir}/"
    cp "${func_dir}/package.json" "${tmp_dir}/"

    # Copy shared layer code into lib/
    cp "${LAYERS_DIR}"/*.js "${tmp_dir}/lib/"
    cp "${LAYERS_DIR}/package.json" "${tmp_dir}/lib/"

    # Install production dependencies
    cd "${tmp_dir}"
    npm install --production --no-package-lock 2>/dev/null || true

    # Create zip
    cd "${DIST_DIR}"
    rm -f "${func_name}.zip"
    zip -r -q "${func_name}.zip" "${func_name}_tmp/"/*
    mv "${func_name}_tmp"/* "${DIST_DIR}/${func_name}_zip_content" 2>/dev/null || true

    # Re-zip with correct structure (files at root)
    rm -f "${func_name}.zip"
    cd "${tmp_dir}"
    zip -r -q "${DIST_DIR}/${func_name}.zip" ./*

    # Cleanup
    rm -rf "${tmp_dir}"

    echo "    -> ${DIST_DIR}/${func_name}.zip created"
}

# Package both functions
package_function "product-manager"
package_function "order-manager"

echo ""
echo "Build complete. Zip files in ${DIST_DIR}/"
ls -lh "${DIST_DIR}"/*.zip
