import Foundation

actor YouTubeService {
    static let shared = YouTubeService()

    struct VideoInfo {
        let videoId: String
        let title: String
        let transcript: String
    }

    enum YouTubeError: Error, LocalizedError {
        case invalidURL
        case transcriptNotAvailable
        case ytDlpNotFound
        case processFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid YouTube URL"
            case .transcriptNotAvailable:
                return "No transcript/subtitles available for this video"
            case .ytDlpNotFound:
                return "yt-dlp is not installed. Please install it with: brew install yt-dlp"
            case .processFailed(let message):
                return "Failed to fetch transcript: \(message)"
            }
        }
    }

    // Regex patterns for YouTube URLs
    private let youtubePatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:https?://)?(?:www\.)?youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})"#,
            #"(?:https?://)?(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})"#,
            #"(?:https?://)?(?:www\.)?youtube\.com/v/([a-zA-Z0-9_-]{11})"#,
            #"(?:https?://)?youtu\.be/([a-zA-Z0-9_-]{11})"#,
            #"(?:https?://)?(?:www\.)?youtube\.com/shorts/([a-zA-Z0-9_-]{11})"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()

    /// Detects if text contains a YouTube URL and extracts the video ID
    func detectYouTubeURL(in text: String) -> String? {
        for pattern in youtubePatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                if let videoIdRange = Range(match.range(at: 1), in: text) {
                    return String(text[videoIdRange])
                }
            }
        }
        return nil
    }

    /// Extracts all YouTube URLs from text
    func extractYouTubeURLs(from text: String) -> [(url: String, videoId: String)] {
        var results: [(url: String, videoId: String)] = []

        for pattern in youtubePatterns {
            let range = NSRange(text.startIndex..., in: text)
            let matches = pattern.matches(in: text, options: [], range: range)

            for match in matches {
                if let urlRange = Range(match.range(at: 0), in: text),
                   let videoIdRange = Range(match.range(at: 1), in: text) {
                    let url = String(text[urlRange])
                    let videoId = String(text[videoIdRange])
                    if !results.contains(where: { $0.videoId == videoId }) {
                        results.append((url: url, videoId: videoId))
                    }
                }
            }
        }

        return results
    }

    /// Fetches video info and transcript using yt-dlp
    func fetchVideoInfo(videoId: String) async throws -> VideoInfo {
        let url = "https://www.youtube.com/watch?v=\(videoId)"

        // First, get the video title
        let title = try await fetchVideoTitle(url: url)

        // Then fetch the transcript
        let transcript = try await fetchTranscript(url: url)

        return VideoInfo(videoId: videoId, title: title, transcript: transcript)
    }

    private func fetchVideoTitle(url: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["yt-dlp", "--get-title", url]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw YouTubeError.ytDlpNotFound
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let title = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Video"

        return title
    }

    private func fetchTranscript(url: String) async throws -> String {
        // Create a temporary directory for subtitle files
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputTemplate = tempDir.appendingPathComponent("subtitle").path

        let process = Process()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "yt-dlp",
            "--write-auto-sub",
            "--write-sub",
            "--sub-lang", "en,en-US,en-GB",
            "--sub-format", "vtt",
            "--skip-download",
            "-o", outputTemplate,
            url
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        process.currentDirectoryURL = tempDir

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw YouTubeError.ytDlpNotFound
        }

        // Find the subtitle file
        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let subtitleFile = files.first(where: { $0.pathExtension == "vtt" }) else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"

            if errorMessage.contains("No subtitles") || process.terminationStatus != 0 {
                throw YouTubeError.transcriptNotAvailable
            }
            throw YouTubeError.processFailed(errorMessage)
        }

        // Read and parse the VTT file
        let vttContent = try String(contentsOf: subtitleFile, encoding: .utf8)
        let cleanedTranscript = parseVTT(vttContent)

        if cleanedTranscript.isEmpty {
            throw YouTubeError.transcriptNotAvailable
        }

        return cleanedTranscript
    }

    /// Parses VTT format and extracts clean text without duplicates
    private func parseVTT(_ content: String) -> String {
        var lines: [String] = []
        var lastLine = ""

        let contentLines = content.components(separatedBy: .newlines)

        for line in contentLines {
            // Skip VTT header, timestamps, and empty lines
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip header
            if trimmed.hasPrefix("WEBVTT") || trimmed.hasPrefix("Kind:") || trimmed.hasPrefix("Language:") {
                continue
            }

            // Skip timestamp lines (00:00:00.000 --> 00:00:00.000)
            if trimmed.contains("-->") {
                continue
            }

            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }

            // Skip positioning info (align:start position:0%)
            if trimmed.contains("align:") || trimmed.contains("position:") {
                continue
            }

            // Remove HTML-like tags and timing markers
            var cleanLine = trimmed
            // Remove <c> tags and timing markers like <00:00:19.039>
            cleanLine = cleanLine.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            cleanLine = cleanLine.trimmingCharacters(in: .whitespaces)

            // Skip if line is empty after cleaning
            if cleanLine.isEmpty {
                continue
            }

            // Skip duplicate lines (auto-generated subs often repeat)
            if cleanLine == lastLine {
                continue
            }

            // Skip lines that are subsets of the previous line (progressive build-up)
            if lastLine.hasPrefix(cleanLine) || (cleanLine.count < lastLine.count && lastLine.contains(cleanLine)) {
                continue
            }

            // If this line starts with the same words as last line, it's probably a continuation
            // Keep only the longer/newer version
            let lastWords = lastLine.components(separatedBy: " ")
            let currentWords = cleanLine.components(separatedBy: " ")

            if lastWords.count > 2 && currentWords.count > 2 {
                let overlap = min(3, min(lastWords.count, currentWords.count))
                if Array(lastWords.prefix(overlap)) == Array(currentWords.prefix(overlap)) {
                    // Replace last line with current if current is longer
                    if cleanLine.count > lastLine.count && !lines.isEmpty {
                        lines.removeLast()
                    } else {
                        continue
                    }
                }
            }

            lines.append(cleanLine)
            lastLine = cleanLine
        }

        // Join lines and clean up spacing
        var result = lines.joined(separator: " ")

        // Clean up multiple spaces
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Fix common issues
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " ?", with: "?")
        result = result.replacingOccurrences(of: " !", with: "!")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
