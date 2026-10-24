[![Build IPA](https://github.com/nullremover/ios-mish/actions/workflows/ios.yml/badge.svg?branch=main)](https://github.com/nullremover/ios-mish/actions/workflows/ios.yml)

## Last.fm Now Playing

Mish can publish the current track to Last.fm so services that read your Last.fm Now Playing status can detect it. This sends `track.updateNowPlaying` updates only; it does not submit listening-history scrobbles.

1. In Mish, open **Appearance → Last.fm / Roblox Now Playing**.
2. Enter the API key and shared secret from your Last.fm API account.
3. Tap **Save credentials and authorize**, approve Mish in the browser, then return to Mish.
4. Tap **I've approved Mish, finish connection**.

The API shared secret and user session key are stored in iOS Keychain. This project does not bundle an API secret. The Last.fm service requires authenticated, signed API requests for Now Playing updates.
