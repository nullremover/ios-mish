
import SwiftUI

struct LyricsView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var lyricsModel: LyricsModel

    private var specialMode: Bool {
        player.isUnderscoresMode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(player.currentTrack?.title ?? "Nothing playing")
                        .font(.system(size: 25, weight: .bold))

                    Text(player.currentTrack?.artist ?? "Choose a song")
                        .font(.system(size: 13))
                        .foregroundStyle(
                            specialMode
                                ? Color.black.opacity(0.6)
                                : Color.mishDim
                        )
                }

                if lyricsModel.isLoading {
                    ProgressView("Finding lyrics…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)

                } else if let lyrics = lyricsModel.lyrics {
                    Text(lyrics)
                        .font(.system(size: 19, weight: .medium))
                        .lineSpacing(9)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled))

                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 35))

                        Text(
                            lyricsModel.errorMessage
                                ?? "Lyrics will appear here."
                        )
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(
                        specialMode
                            ? Color.black.opacity(0.65)
                            : Color.mishDim
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 45)
                }
            }
            .padding(22)
        }
        .foregroundStyle(specialMode ? .black : .white)
        .animation(.easeInOut(duration: 0.2), value: specialMode)
    }
}
