#!/bin/bash

# Release automation script for NetCheck

set -e

VERSION="1.2.0"
APP_NAME="NetCheck"
ARCHIVE_NAME="${APP_NAME}-${VERSION}.tar.gz"

echo "Creating release for NetCheck v${VERSION}..."

# Build the application
echo "Building release version..."
swift build -c release

# Create app bundle using build script
echo "Creating app bundle..."
./build.sh

# Create archive
echo "Creating archive..."
tar -czf "${ARCHIVE_NAME}" "${APP_NAME}.app"

# Calculate SHA256
echo "Calculating SHA256..."
SHA256=$(shasum -a 256 "${ARCHIVE_NAME}" | awk '{print $1}')

echo "Release created: ${ARCHIVE_NAME}"
echo "SHA256: ${SHA256}"
echo ""
echo "Next steps:"
echo "1. Upload ${ARCHIVE_NAME} to GitHub release"
echo "2. Update SHA256 in netcheck.rb"
echo "3. Submit netcheck.rb to Homebrew tap"
echo "4. Update README.md with release notes"
