import Foundation
import Combine

// MARK: - 歌词管理器
class LyricsManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentLyrics: Lyrics?
    @Published var currentLine: LyricLine?
    @Published var currentLineIndex: Int?
    @Published var displayMode: LyricsDisplayMode = .scroll
    @Published var showTranslation: Bool = false
    @Published var isLyricsVisible: Bool = false
    @Published var lyricsLibrary: [UUID: Lyrics] = [:] // 歌词库，以歌曲ID为键
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let lyricsKey = "SavedLyrics"
    private let downloadService = LyricsDownloadService.shared
    
    // MARK: - Singleton
    static let shared = LyricsManager()
    
    init() {
        loadLyricsLibrary()
    }
    
    // MARK: - 歌词库管理
    
    // 加载歌词库
    private func loadLyricsLibrary() {
        if let data = userDefaults.data(forKey: lyricsKey),
           let lyrics = try? JSONDecoder().decode([UUID: Lyrics].self, from: data) {
            lyricsLibrary = lyrics
            print("✅ 歌词库加载成功，共 \(lyrics.count) 首歌曲的歌词")
        } else {
            print("ℹ️ 歌词库为空或加载失败")
        }
    }
    
    // 保存歌词库
    private func saveLyricsLibrary() {
        if let data = try? JSONEncoder().encode(lyricsLibrary) {
            userDefaults.set(data, forKey: lyricsKey)
            print("✅ 歌词库保存成功")
        } else {
            print("❌ 歌词库保存失败")
        }
    }
    
    // 添加歌词到库
    func addLyrics(_ lyrics: Lyrics) {
        lyricsLibrary[lyrics.songId] = lyrics
        saveLyricsLibrary()
        print("✅ 歌词已添加到库: \(lyrics.title ?? "未知歌曲")")
    }
    
    // 删除歌词
    func removeLyrics(for songId: UUID) {
        lyricsLibrary.removeValue(forKey: songId)
        saveLyricsLibrary()
        print("✅ 歌词已删除")
    }
    
    // 获取歌曲的歌词
    func getLyrics(for songId: UUID) -> Lyrics? {
        return lyricsLibrary[songId]
    }
    
    // 检查歌曲是否有歌词
    func hasLyrics(for songId: UUID) -> Bool {
        return lyricsLibrary[songId] != nil
    }
    
    // MARK: - 歌词加载和设置
    
    // 为当前歌曲加载歌词
    func loadLyrics(for song: Song) {
        // 首先尝试从歌词库加载
        if let lyrics = getLyrics(for: song.id) {
            currentLyrics = lyrics
            print("✅ 从歌词库加载歌词: \(song.title)")
            return
        }
        
        // 尝试从本地文件加载
        if let lyrics = loadLyricsFromFile(for: song) {
            currentLyrics = lyrics
            addLyrics(lyrics) // 添加到歌词库
            print("✅ 从本地文件加载歌词: \(song.title)")
            return
        }
        
        // 尝试在线下载歌词
        downloadLyricsOnline(for: song)
    }
    
    // 重新加载歌词（强制刷新）
    func reloadLyrics(for song: Song, forceOnlineDownload: Bool = false) {
        if forceOnlineDownload {
            // 强制在线下载
            downloadLyricsOnline(for: song)
        } else {
            // 清除当前歌词，重新加载
            currentLyrics = nil
            loadLyrics(for: song)
        }
    }
    
    // 在线下载歌词
    private func downloadLyricsOnline(for song: Song) {
        print("🔍 开始在线搜索歌词: \(song.artist) - \(song.title)")
        
        downloadService.downloadLyrics(for: song) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let lyrics):
                    self?.currentLyrics = lyrics
                    self?.addLyrics(lyrics)
                    print("✅ 在线歌词下载成功: \(song.title)")
                case .failure(let error):
                    print("❌ 在线歌词下载失败: \(error.localizedDescription)")
                    // 下载失败时保持无歌词状态
                    self?.currentLyrics = nil
                }
            }
        }
    }
    
    // 从本地文件加载歌词
    private func loadLyricsFromFile(for song: Song) -> Lyrics? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 尝试不同的歌词文件格式
        let lyricsFormats = ["lrc", "txt"]
        let possibleNames = [
            song.fileName.replacingOccurrences(of: ".\(song.fileName.split(separator: ".").last ?? "")", with: ""),
            song.title,
            "\(song.artist) - \(song.title)"
        ]
        
        for name in possibleNames {
            for format in lyricsFormats {
                let lyricsURL = documentsPath.appendingPathComponent("\(name).\(format)")
                if FileManager.default.fileExists(atPath: lyricsURL.path) {
                    return parseLyricsFile(at: lyricsURL, for: song)
                }
            }
        }
        
        return nil
    }
    
    // 解析歌词文件
    private func parseLyricsFile(at url: URL, for song: Song) -> Lyrics? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ 无法读取歌词文件: \(url.lastPathComponent)")
            return nil
        }
        
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "lrc":
            return parseLRCFormat(content: content, for: song)
        case "txt":
            return parseTextFormat(content: content, for: song)
        default:
            return nil
        }
    }
    
    // 解析LRC格式歌词
    private func parseLRCFormat(content: String, for song: Song) -> Lyrics? {
        let lines = content.components(separatedBy: .newlines)
        var lyricLines: [LyricLine] = []
        var title: String?
        var artist: String?
        var album: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            // 解析元数据
            if trimmedLine.hasPrefix("[ti:") {
                title = extractMetadata(from: trimmedLine, prefix: "[ti:", suffix: "]")
            } else if trimmedLine.hasPrefix("[ar:") {
                artist = extractMetadata(from: trimmedLine, prefix: "[ar:", suffix: "]")
            } else if trimmedLine.hasPrefix("[al:") {
                album = extractMetadata(from: trimmedLine, prefix: "[al:", suffix: "]")
            } else if trimmedLine.contains("]") && !trimmedLine.hasPrefix("[") {
                // 解析时间戳和歌词
                if let lyricLine = parseLRCLine(trimmedLine) {
                    lyricLines.append(lyricLine)
                }
            }
        }
        
        guard !lyricLines.isEmpty else { return nil }
        
        return Lyrics(
            songId: song.id,
            title: title ?? song.title,
            artist: artist ?? song.artist,
            album: album ?? song.album,
            lines: lyricLines,
            source: .local
        )
    }
    
    // 解析LRC行
    private func parseLRCLine(_ line: String) -> LyricLine? {
        // 匹配时间戳格式 [mm:ss.xx] 或 [mm:ss]
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: line.utf16.count)
        
        guard let match = regex?.firstMatch(in: line, range: range) else { return nil }
        
        let minutesRange = Range(match.range(at: 1), in: line)!
        let secondsRange = Range(match.range(at: 2), in: line)!
        let millisecondsRange = match.range(at: 3).location != NSNotFound ? Range(match.range(at: 3), in: line) : nil
        let textRange = Range(match.range(at: 4), in: line)!
        
        let minutes = Int(line[minutesRange]) ?? 0
        let seconds = Int(line[secondsRange]) ?? 0
        let milliseconds = millisecondsRange != nil ? Int(line[millisecondsRange!]) ?? 0 : 0
        let text = String(line[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let timeStamp = TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
        
        return LyricLine(timeStamp: timeStamp, text: text)
    }
    
    // 解析纯文本格式歌词
    private func parseTextFormat(content: String, for song: Song) -> Lyrics? {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { return nil }
        
        // 为纯文本歌词生成时间戳（平均分配）
        let totalDuration = song.duration
        let timePerLine = totalDuration / Double(lines.count)
        
        let lyricLines = lines.enumerated().map { index, text in
            LyricLine(timeStamp: TimeInterval(index) * timePerLine, text: text)
        }
        
        return Lyrics(
            songId: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            lines: lyricLines,
            source: .local
        )
    }
    
    // 提取元数据
    private func extractMetadata(from line: String, prefix: String, suffix: String) -> String? {
        guard line.hasPrefix(prefix) && line.hasSuffix(suffix) else { return nil }
        let startIndex = line.index(line.startIndex, offsetBy: prefix.count)
        let endIndex = line.index(line.endIndex, offsetBy: -suffix.count)
        return String(line[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    

    
    // MARK: - 歌词同步
    
    // 更新当前播放时间对应的歌词
    func updateCurrentLyrics(currentTime: TimeInterval) {
        guard let lyrics = currentLyrics else {
            currentLine = nil
            currentLineIndex = nil
            return
        }
        
        currentLine = lyrics.getCurrentLine(at: currentTime)
        currentLineIndex = lyrics.getCurrentLineIndex(at: currentTime)
    }
    
    // 清除当前歌词
    func clearCurrentLyrics() {
        currentLyrics = nil
        currentLine = nil
        currentLineIndex = nil
    }
    
    // MARK: - 歌词显示设置
    
    // 切换歌词显示模式
    func toggleDisplayMode() {
        let modes = LyricsDisplayMode.allCases
        if let currentIndex = modes.firstIndex(of: displayMode) {
            let nextIndex = (currentIndex + 1) % modes.count
            displayMode = modes[nextIndex]
        }
    }
    
    // 切换翻译显示
    func toggleTranslation() {
        showTranslation.toggle()
    }
    
    // 切换歌词可见性
    func toggleLyricsVisibility() {
        isLyricsVisible.toggle()
    }
} 