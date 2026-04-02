cask "hootty" do
  version "0.1.0"
  sha256 "fb4c03a89261603588c4e56baf938b0ed1fec7811533a0470afc239dfb8d4ac3"

  url "https://github.com/getsoel/hootty/releases/download/v#{version}/Hootty.dmg"
  name "Hootty"
  desc "macOS terminal emulator powered by libghostty"
  homepage "https://github.com/getsoel/hootty"

  depends_on macos: ">= :sonoma"

  app "Hootty.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Hootty.app"],
                   sudo: false
  end

  caveats <<~EOS
    Hootty is not signed or notarized. On first launch, you may need to:
      Right-click the app → Open → Open
    Or allow it in System Settings → Privacy & Security.
  EOS

  zap trash: [
    "~/Library/Preferences/com.soel.hootty.plist",
    "~/Library/Application Support/Hootty",
  ]
end
