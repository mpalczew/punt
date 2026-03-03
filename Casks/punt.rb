cask "punt" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/mpalczew/punt/releases/download/v#{version}/Punt-#{version}-universal.zip"
  name "Punt"
  desc "macOS browser picker — choose which browser opens each link"
  homepage "https://github.com/mpalczew/punt"

  depends_on macos: ">= :ventura"

  app "Punt.app"

  zap trash: [
    "~/Library/Preferences/com.punt.browser-picker.plist",
  ]
end
