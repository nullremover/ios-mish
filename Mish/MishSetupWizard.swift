
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Options

enum MishBaseTheme: String, CaseIterable, Identifiable {
    case smoked, amoled, clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smoked: return "Smoked"
        case .amoled: return "AMOLED"
        case .clear:  return "Clear"
        }
    }

    var blurb: String {
        switch self {
        case .smoked: return "Soft charcoal, easy on the eyes"
        case .amoled: return "Pure black, battery friendly"
        case .clear:  return "Frosted glass over color"
        }
    }
}

enum MishLayoutStyle: String, CaseIterable, Identifiable {
    case classic, vinyl, minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:   return "Classic"
        case .vinyl:     return "Vinyl"
        case .minimal:   return "Minimal"
        }
    }
}

// MARK: - Settings (persisted)

final class MishSettings: ObservableObject {
    private enum Key {
        static let setup = "mish.setupComplete"
        static let theme = "mish.baseTheme"
        static let accent = "mish.albumArtAccent"
        static let layout = "mish.layout"
        static let folder = "mish.musicFolderBookmark"
    }

    private let defaults = UserDefaults.standard

    @Published var setupComplete: Bool {
        didSet { defaults.set(setupComplete, forKey: Key.setup) }
    }

    @Published var baseTheme: MishBaseTheme {
        didSet { defaults.set(baseTheme.rawValue, forKey: Key.theme) }
    }

    @Published var albumArtAccent: Bool {
        didSet { defaults.set(albumArtAccent, forKey: Key.accent) }
    }

    @Published var layout: MishLayoutStyle {
        didSet { defaults.set(layout.rawValue, forKey: Key.layout) }
    }

    init() {
        let d = UserDefaults.standard

        setupComplete = d.bool(forKey: Key.setup)

        baseTheme = MishBaseTheme(
            rawValue: d.string(forKey: Key.theme) ?? ""
        ) ?? .smoked

        albumArtAccent = (d.object(forKey: Key.accent) as? Bool) ?? true

        layout = MishLayoutStyle(
            rawValue: d.string(forKey: Key.layout) ?? ""
        ) ?? .classic
    }

    /// Stores a security-scoped bookmark so the folder survives app restarts.
    func saveMusicFolder(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        defaults.set(data, forKey: Key.folder)
    }

    /// Returns the saved folder.
    /// Call startAccessingSecurityScopedResource() before reading its files.
    func resolveMusicFolder() -> URL? {
        guard let data = defaults.data(forKey: Key.folder) else {
            return nil
        }

        var stale = false

        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return nil
        }

        if stale {
            try? saveMusicFolder(url)
        }

        return url
    }

    /// Handy while developing: run the wizard again on next launch.
    func resetSetup() {
        setupComplete = false
    }
}

// MARK: - Library scan (counts tracks for the INDEXING screen)

enum MishLibraryScanner {
    static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "wav",
        "aiff", "aif", "alac", "ogg", "opus", "caf"
    ]

    static func countTracks(in folder: URL) -> Int {
        let scoped = folder.startAccessingSecurityScopedResource()

        defer {
            if scoped {
                folder.stopAccessingSecurityScopedResource()
            }
        }

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var count = 0

        for case let url as URL in enumerator
        where audioExtensions.contains(url.pathExtension.lowercased()) {
            count += 1
        }

        return count
    }
}

// MARK: - Haptics

@MainActor
enum MishHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func thud() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

// MARK: - Shared visuals

struct MishBackdrop: View {
    let theme: MishBaseTheme
    var fullScreen = true

    var body: some View {
        ZStack {
            switch theme {
            case .smoked:
                LinearGradient(
                    colors: [
                        Color(white: 0.17),
                        Color(white: 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

            case .amoled:
                Color.black

            case .clear:
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.mishGreen.opacity(0.45),
                            Color.blue.opacity(0.30),
                            Color.purple.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            }
        }
        .ignoresSafeArea(edges: fullScreen ? .all : [])
        .animation(.easeInOut(duration: 0.4), value: theme)
    }
}

private extension View {
    func stepTransition() -> some View {
        transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
    }
}

private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.custom("delagothicone-regular", size: 32))
                .foregroundStyle(Color.mishGreen)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 28)
    }
}

private struct WizardButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Color.mishGreen.opacity(enabled ? 1 : 0.3),
                    in: Capsule()
                )
        }
        .disabled(!enabled)
        .padding(.bottom, 20)
    }
}

private struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(
                        i == current
                            ? Color.mishGreen
                            : Color.white.opacity(0.25)
                    )
                    .frame(
                        width: i == current ? 22 : 8,
                        height: 8
                    )
            }
        }
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8),
            value: current
        )
    }
}

private struct SpinnerWheel: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)

            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(
                    Color.mishGreen,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(spin ? 360 : 0))
        }
        .frame(width: 84, height: 84)
        .onAppear {
            withAnimation(
                .linear(duration: 0.9)
                    .repeatForever(autoreverses: false)
            ) {
                spin = true
            }
        }
    }
}

private struct IndexingLabel: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { context in
            let n = Int(
                context.date.timeIntervalSinceReferenceDate / 0.4
            ) % 4

            Text("INDEXING" + String(repeating: ".", count: n))
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 190, alignment: .leading)
        }
    }
}

// MARK: - Wizard

struct MishSetupWizard: View {
    @EnvironmentObject private var settings: MishSettings
    @EnvironmentObject private var player: PlayerModel

    let onFinished: () -> Void

    private enum Step: Int {
        case folder, theme, layout, save
    }

    @State private var step: Step = .folder

    var body: some View {
        ZStack {
            MishBackdrop(theme: settings.baseTheme)

            VStack(spacing: 0) {
                if step != .save {
                    ProgressDots(current: step.rawValue, total: 3)
                        .padding(.top, 20)
                        .transition(.opacity)
                }

                ZStack {
                    switch step {
                    case .folder:
                        FolderStep(
                            onNext: {
                                go(.theme)
                            },
                            onFolderSelected: { url in
                                // Add the selected folder to Mish's actual library.
                                player.addRoots([url])
                            }
                        )
                        .stepTransition()

                    case .theme:
                        ThemeStep(
                            onNext: {
                                go(.layout)
                            }
                        )
                        .stepTransition()

                    case .layout:
                        LayoutStep(
                            onNext: {
                                go(.save)
                            }
                        )
                        .stepTransition()

                    case .save:
                        SaveStep {
                            settings.setupComplete = true
                            onFinished()
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .foregroundStyle(Color.white)
    }

    private func go(_ next: Step) {
        withAnimation(
            .spring(response: 0.55, dampingFraction: 0.88)
        ) {
            step = next
        }
    }
}

// MARK: Step 1 - music folder

private struct FolderStep: View {
    @EnvironmentObject private var settings: MishSettings

    let onNext: () -> Void
    let onFolderSelected: (URL) -> Void

    private enum Phase: Equatable {
        case idle
        case indexing
        case done(Int)
        case failed
    }

    @State private var phase: Phase = .idle
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 28) {
            StepHeader(
                title: "Where's your music?",
                subtitle: "Pick the folder your songs live in. Mish will take it from there."
            )

            Spacer()

            Group {
                switch phase {
                case .idle:
                    Image(systemName: "folder.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.mishGreen)

                case .indexing:
                    VStack(spacing: 24) {
                        SpinnerWheel()
                        IndexingLabel()
                    }

                case .done(let count):
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.mishGreen)

                        Text("\(count) song\(count == 1 ? "" : "s") found")
                            .font(.title3.weight(.semibold))
                    }

                case .failed:
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.orange)

                        Text("Couldn't open that folder. Try another one.")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
            }
            .transition(
                .opacity.combined(with: .scale(scale: 0.9))
            )

            Spacer()

            switch phase {
            case .idle, .failed:
                WizardButton(title: "Choose music folder") {
                    showPicker = true
                }

            case .indexing:
                WizardButton(title: "Indexing…", enabled: false) {}

            case .done:
                WizardButton(title: "Continue") {
                    onNext()
                }
            }
        }
        .animation(
            .spring(response: 0.5, dampingFraction: 0.85),
            value: phase
        )
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder]
        ) { result in
            handle(result)
        }
    }

    private func handle(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                // Save a bookmark so the selected folder can be restored later.
                try settings.saveMusicFolder(url)
            } catch {
                phase = .failed
                return
            }

            // Add the selected folder to PlayerModel's music library.
            onFolderSelected(url)

            // Count the supported audio files for the setup screen.
            startIndexing(url)

        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                phase = .failed
            }
        }
    }

    private func startIndexing(_ url: URL) {
        phase = .indexing

        Task {
            let start = Date()

            let count = await Task.detached(
                priority: .userInitiated
            ) {
                MishLibraryScanner.countTracks(in: url)
            }.value

            // Keep the wheel on screen long enough to feel intentional.
            let elapsed = Date().timeIntervalSince(start)

            if elapsed < 2.2 {
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        (2.2 - elapsed) * 1_000_000_000
                    )
                )
            }

            guard !Task.isCancelled else { return }

            phase = .done(count)
            MishHaptics.tap()
        }
    }
}

// MARK: Step 2 - theme

private struct ThemeStep: View {
    @EnvironmentObject private var settings: MishSettings

    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                title: "Pick your base",
                subtitle: "You can change this later in settings."
            )

            VStack(spacing: 12) {
                ForEach(MishBaseTheme.allCases) { theme in
                    ThemeCard(
                        theme: theme,
                        selected: settings.baseTheme == theme
                    ) {
                        MishHaptics.tap()

                        withAnimation(.easeInOut(duration: 0.3)) {
                            settings.baseTheme = theme
                        }
                    }
                }
            }
            .padding(.top, 8)

            Toggle(isOn: $settings.albumArtAccent) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Match the song")
                        .font(.headline)

                    Text("Use the album art's colors as the accent")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .tint(Color.mishGreen)
            .padding(16)
            .background(
                Color.white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 16)
            )

            Spacer()

            WizardButton(title: "Continue") {
                onNext()
            }
        }
    }
}

private struct ThemeCard: View {
    let theme: MishBaseTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                MishBackdrop(theme: theme, fullScreen: false)
                    .frame(width: 56, height: 56)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.title)
                        .font(.headline)

                    Text(theme.blurb)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()

                Image(
                    systemName: selected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    selected
                        ? Color.mishGreen
                        : Color.white.opacity(0.3)
                )
            }
            .padding(12)
            .background(
                Color.white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selected ? Color.mishGreen : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: Step 3 - layout

private struct LayoutStep: View {
    @EnvironmentObject private var settings: MishSettings

    let onNext: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(spacing: 20) {
            StepHeader(
                title: "How should it look?",
                subtitle: "Choose a player layout."
            )

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(MishLayoutStyle.allCases) { style in
                    let selected = settings.layout == style

                    Button {
                        MishHaptics.tap()

                        withAnimation(
                            .spring(
                                response: 0.35,
                                dampingFraction: 0.75
                            )
                        ) {
                            settings.layout = style
                        }
                    } label: {
                        VStack(spacing: 10) {
                            LayoutPreview(style: style)

                            Text(style.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(10)
                        .background(
                            Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    selected
                                        ? Color.mishGreen
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .scaleEffect(selected ? 1.03 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)

            Spacer()

            WizardButton(title: "Continue") {
                onNext()
            }
        }
    }
}

private struct LayoutPreview: View {
    let style: MishLayoutStyle

    private func bar(
        _ width: CGFloat,
        _ opacity: Double = 0.4
    ) -> some View {
        Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: width, height: 4)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.07))

            content
                .padding(10)
        }
        .frame(height: 130)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .classic:
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.mishGreen.opacity(0.75))
                    .aspectRatio(1, contentMode: .fit)

                bar(60, 0.55)
                bar(38)

                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 10, height: 10)
                    }
                }
            }

        case .vinyl:
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(Color.mishGreen.opacity(0.75))

                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 14, height: 14)
                }
                .aspectRatio(1, contentMode: .fit)

                bar(54, 0.55)
                bar(34)
            }

        case .minimal:
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.mishGreen.opacity(0.75))
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 5) {
                        bar(40, 0.55)
                        bar(26)
                    }
                }

                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 3)

                Spacer()
            }
        }
    }
}

// MARK: Step 4 - save file animation

private struct DisketteIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.mishGreen)

            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.85))
                    .frame(width: 46, height: 30)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 9, height: 20)
                            .padding(.trailing, 6)
                    }

                Spacer()
            }

            VStack {
                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 62, height: 36)
                    .overlay {
                        VStack(spacing: 6) {
                            Capsule()
                                .fill(Color.black.opacity(0.2))
                                .frame(width: 44, height: 3)

                            Capsule()
                                .fill(Color.black.opacity(0.2))
                                .frame(width: 34, height: 3)
                        }
                    }
            }
        }
        .frame(width: 96, height: 96)
    }
}

private struct SaveStep: View {
    let onFinished: () -> Void

    @State private var appeared = false
    @State private var done = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                DisketteIcon()
                    .scaleEffect(appeared ? 1 : 0.01)
                    .rotationEffect(
                        .degrees(appeared ? 0 : -720)
                    )
                    .opacity(appeared ? 1 : 0)

                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.white, Color.green)
                        .offset(x: 46, y: 46)
                        .transition(.scale)
                }
            }

            Text(done ? "Setup complete" : "Saving your setup…")
                .font(.custom("delagothicone-regular", size: 26))
                .foregroundStyle(Color.mishGreen)
                .contentTransition(.opacity)

            Spacer()
        }
        .task {
            withAnimation(
                .spring(response: 1.1, dampingFraction: 0.62)
            ) {
                appeared = true
            }

            try? await Task.sleep(
                nanoseconds: 1_400_000_000
            )

            guard !Task.isCancelled else { return }

            withAnimation(
                .spring(response: 0.4, dampingFraction: 0.6)
            ) {
                done = true
            }

            MishHaptics.thud()

            try? await Task.sleep(
                nanoseconds: 1_300_000_000
            )

            guard !Task.isCancelled else { return }

            onFinished()
        }
    }
}

// MARK: - About

/// Drop this into your settings screen, e.g. NavigationLink("About") { MishAboutView() }
struct MishAboutView: View {
    @State private var taps = 0
    @State private var secretFound = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("mish")
                .font(.custom("delagothicone-regular", size: 72))
                .foregroundStyle(Color.mishGreen)
                .shadow(
                    color: Color.mishGreen.opacity(secretFound ? 0.7 : 0),
                    radius: 24
                )
                .scaleEffect(secretFound ? 1.08 : 1)
                .onTapGesture {
                    logoTapped()
                }

            Text("Version \(version)")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.5))

            Text("Thank you for enjoying my player.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            if secretFound {
                Text("you found it ♥")
                    .font(.subheadline)
                    .foregroundStyle(Color.mishGreen)
                    .transition(
                        .opacity.combined(with: .scale)
                    )
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            Color(red: 0.03, green: 0.03, blue: 0.04)
                .ignoresSafeArea()
        )
        .foregroundStyle(Color.white)
    }

    private func logoTapped() {
        taps += 1
        MishHaptics.tap()

        if taps >= 7 && !secretFound {
            MishHaptics.thud()

            withAnimation(
                .spring(response: 0.5, dampingFraction: 0.5)
            ) {
                secretFound = true
            }

            // Placeholder: hook your real secret in here.
        }
    }
}
