cask "gestur" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "__URL__"
  name "Gestur"
  desc "Fast browser mouse gestures for macOS"
  homepage "https://github.com/wygoralves/gestur"

  app "Gestur.app"

  uninstall quit: "com.gestur.Gestur"

  postflight do
    # Best-effort friction reduction for unsigned / unnotarized builds.
    system_command "/usr/bin/xattr",
      args: ["-dr", "com.apple.quarantine", "#{appdir}/Gestur.app"]
  end

  zap trash: [
    "~/Library/Application Support/Gestur",
    "~/Library/Preferences/com.gestur.Gestur.plist",
  ]
end
