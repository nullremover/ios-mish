
import SwiftUI

struct LyricsView: View {
    @EnvironmentObject var player: PlayerModel
    @EnvironmentObject var lyricsModel: LyricsModel

    private var specialMode: Bool {
        player.isUnderscoresMode
    }

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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { 
                VStack(alignment: .leading, spacing: 22) {
                    // Track information
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
    
                    } else if !lyricsModel.syncedLines.isEmpty {
                        // Timestamped lyrics
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(
                                Array(lyricsModel.syncedLines.enumerated()),
                                id: \.element.id
                            ) { item in
                                let index = item.offset
                                let line = item.element
                                let isActive = index == activeLineIndex
    
                                Text(line.text.isEmpty ? "♪" : line.text)
                                    .font(
                                        .system(
                                            size: isActive ? 21 : 18,
                                            weight: isActive ? .bold : .medium
                                        )
                                    )
                                    .foregroundStyle(
                                        isActive
                                            ? (specialMode
                                                ? Color.black
                                                : Color.white)
                                            : (specialMode
                                                ? Color.black.opacity(0.48)
                                                : Color.white.opacity(0.48))
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background {
                                        if isActive {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(
                                                    specialMode
                                                        ? Color.black.opacity(0.08)
                                                        : Color.white.opacity(0.12)
                                                )
                                        }
                                    }
                                    .scaleEffect(isActive ? 1.01 : 1.0, anchor: .leading)
                                    .id(line.id)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: activeLineIndex)
    
                    } else if let lyrics = lyricsModel.lyrics {
                        // Plain lyrics fallback: no timestamps to synchronize.
                        Text(lyrics)
                            .font(.system(size: 19, weight: .medium))
                            .lineSpacing(9)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .textSelection(.enabled)
    
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
            .foregroundStyle(specialMode ? Color.black : Color.white)
            .animation(.easeInOut(duration: 0.2), value: specialMode)
             .onChange(of: activeLineID) { newID in
                    guard let newID else { return }
            
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }