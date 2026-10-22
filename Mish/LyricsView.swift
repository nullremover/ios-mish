import SwiftUI

struct LyricsView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var lyricsModel: LyricsModel

    private var specialMode: Bool {
        player.isUnderscoresMode
    }

    // MARK: - Colors (precomputed so body stays simple)

    private var primaryColor: Color {
        specialMode ? Color.black : Color.white
    }

    private var inactiveLineColor: Color {
        specialMode ? Color.black.opacity(0.48) : Color.white.opacity(0.48)
    }

    private var activeLineBackground: Color {
        specialMode ? Color.black.opacity(0.08) : Color.white.opacity(0.12)
    }

    private var dimColor: Color {
        specialMode ? Color.black.opacity(0.6) : Color.mishDim
    }

    private var emptyStateColor: Color {
        specialMode ? Color.black.opacity(0.65) : Color.mishDim
    }

    // MARK: - Active line

    // Find the last lyric whose timestamp has been reached.
    private var activeLineIndex: Int? {
        guard !lyricsModel.syncedLines.isEmpty else {
            return nil
        }

        return lyricsModel.syncedLines.lastIndex {
            $0.time <= player.currentTime
        }
    }

    private var activeLineID: Int? {
        guard let index = activeLineIndex,
              lyricsModel.syncedLines.indices.contains(index) else {
            return nil
        }

        return lyricsModel.syncedLines[index].id
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    lyricsContent
                }
                .padding(22)
            }
            .foregroundStyle(primaryColor)
            .animation(.easeInOut(duration: 0.2), value: specialMode)
            .onChange(of: activeLineID) { newID in
                guard let newID else { return }

                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(player.currentTrack?.title ?? "Nothing playing")
                .font(.system(size: 25, weight: .bold))

            Text(player.currentTrack?.artist ?? "Choose a song")
                .font(.system(size: 13))
                .foregroundStyle(dimColor)
        }
    }

    @ViewBuilder
    private var lyricsContent: some View {
        if lyricsModel.isLoading {
            loadingView
        } else if !lyricsModel.syncedLines.isEmpty {
            syncedList
        } else if let lyrics = lyricsModel.lyrics {
            plainLyrics(lyrics)
        } else {
            emptyState
        }
    }

    private var loadingView: some View {
        ProgressView("Finding lyrics…")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    private var syncedList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(
                Array(lyricsModel.syncedLines.enumerated()),
                id: \.element.id
            ) { item in
                lyricLine(
                    text: item.element.text,
                    isActive: item.offset == activeLineIndex
                )
                .id(item.element.id)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeLineIndex)
    }

    private func lyricLine(text: String, isActive: Bool) -> some View {
        let fontSize: CGFloat = isActive ? 21 : 18
        let fontWeight: Font.Weight = isActive ? .bold : .medium
        let textColor: Color = isActive ? primaryColor : inactiveLineColor
        let displayText: String = text.isEmpty ? "♪" : text

        return Text(displayText)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(activeLineBackground)
                }
            }
            .scaleEffect(isActive ? 1.01 : 1.0, anchor: .leading)
    }

    // Plain lyrics fallback: no timestamps to synchronize.
    private func plainLyrics(_ lyrics: String) -> some View {
        Text(lyrics)
            .font(.system(size: 19, weight: .medium))
            .lineSpacing(9)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private var emptyState: some View {
        let message: String = lyricsModel.errorMessage ?? "Lyrics will appear here."

        return VStack(spacing: 12) {
            Image(systemName: "text.quote")
                .font(.system(size: 35))

            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(emptyStateColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 45)
    }
}
