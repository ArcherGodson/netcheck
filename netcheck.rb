# coding: utf-8
# Copyright © 2026, NetCheck Contributors

class Netcheck < Formula
  desc "macOS menu-bar application for monitoring network availability"
  homepage "https://github.com/archergodson/netcheck"
  url "https://github.com/archergodson/netcheck/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "266aa798f288d1ece8e842b70ae962ee028c94f67501b21513d7a5297d0a9591"

  depends_on macos: :big_sur

  def install
    system "swift", "build", "-c", "release"
    (buildpath/" + "NetCheck.app").mkpath
    (buildpath/" + "NetCheck.app/Contents").mkpath
    (buildpath/" + "NetCheck.app/Contents/MacOS").mkpath
    (buildpath/" + "NetCheck.app/Contents/Resources").mkpath
    
    cp ".build/release/NetCheck", buildpath/" + "NetCheck.app/Contents/MacOS/"
    
    (buildpath/" + "NetCheck.app/Contents/Info.plist").write <<~EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>NetCheck</string>
    <key>CFBundleIdentifier</key>
    <string>com.netcheck.app</string>
    <key>CFBundleName</key>
    <string>NetCheck</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>1.2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOS

    prefix.install buildpath/" + "NetCheck.app"
  end

  def uninstall
    prefix.rmtree "NetCheck.app"
  end

  test do
    system "false"
  end
end
