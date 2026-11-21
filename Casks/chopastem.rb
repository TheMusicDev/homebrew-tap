cask "chopastem" do
  version "0.4.6"
  sha256 "c4887b660a4a6007171a78ad877a9e4ef3cd9cdd5bf2446e8afc27c80a288688"

  url "https://github.com/TheMusicDev/chopastem-releases/releases/download/v#{version}/ChopAStem-#{version}.dmg"
  name "ChopAStem"
  desc "Free stem splitter: vocals, drums, bass and other"
  homepage "https://chopastem.com/"

  livecheck do
    url "https://chopastem.com/appcast.xml"
    strategy :sparkle, &:short_version
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "ChopAStem.app"

  zap trash: [
    "~/Library/Caches/com.themusicdev.chopastem",
    "~/Library/HTTPStorages/com.themusicdev.chopastem",
    "~/Library/Preferences/com.themusicdev.chopastem.plist",
  ]
end
