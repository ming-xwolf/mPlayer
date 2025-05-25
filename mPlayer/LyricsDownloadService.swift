import Foundation
import Combine

// MARK: - 歌词下载服务
class LyricsDownloadService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var lastError: String?
    
    // MARK: - Private Properties
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    private let searchAPI = LyricsSearchAPI()
    
    // MARK: - Constants
    private struct APIConstants {
        // 网易云音乐歌词API（示例）
        static let neteaseLyricsAPI = "https://music.163.com/api/song/lyric"
        // QQ音乐歌词API（示例）
        static let qqMusicLyricsAPI = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg"
        // 酷狗音乐歌词API（示例）
        static let kugouLyricsAPI = "http://lyrics.kugou.com/search"
        
        static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15"
        static let timeout: TimeInterval = 30.0
    }
    
    // MARK: - Singleton
    static let shared = LyricsDownloadService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 下载歌词的主要方法
    /// - Parameters:
    ///   - song: 要下载歌词的歌曲
    ///   - completion: 完成回调，返回下载的歌词或错误
    func downloadLyrics(for song: Song, completion: @escaping (Result<Lyrics, LyricsDownloadError>) -> Void) {
        guard !isDownloading else {
            completion(.failure(.alreadyDownloading))
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        lastError = nil
        
        print("🔍 开始搜索歌词: \(song.artist) - \(song.title)")
        
        Task {
            do {
                let searchParams = LyricsSearchAPI.SearchParams(
                    title: song.title,
                    artist: song.artist,
                    album: song.album,
                    duration: song.duration
                )
                
                downloadProgress = 0.3
                let searchResults = try await searchAPI.searchLyrics(params: searchParams)
                
                downloadProgress = 0.8
                
                guard let bestResult = searchResults.first else {
                    throw LyricsDownloadError.noLyricsFound
                }
                
                let lyrics = parseLRCContent(bestResult.lyricsContent, for: song, source: .online)
                
                DispatchQueue.main.async { [weak self] in
                    self?.isDownloading = false
                    self?.downloadProgress = 1.0
                    
                    print("✅ 歌词下载成功: \(song.title) (来源: \(bestResult.source), 匹配度: \(String(format: "%.2f", bestResult.confidence)))")
                    self?.saveLyricsToLocal(lyrics, for: song)
                    completion(.success(lyrics))
                }
                
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isDownloading = false
                    self?.downloadProgress = 0.0
                    
                    let downloadError: LyricsDownloadError
                    if let searchError = error as? LyricsSearchError {
                        downloadError = .searchError(searchError)
                    } else {
                        downloadError = .networkError(error)
                    }
                    
                    print("❌ 歌词下载失败: \(downloadError.localizedDescription)")
                    self?.lastError = downloadError.localizedDescription
                    completion(.failure(downloadError))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 解析LRC格式歌词内容
    private func parseLRCContent(_ content: String, for song: Song, source: LyricsSource) -> Lyrics {
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
            } else if let lyricLine = parseLRCLine(trimmedLine) {
                lyricLines.append(lyricLine)
            }
        }
        
        return Lyrics(
            songId: song.id,
            title: title ?? song.title,
            artist: artist ?? song.artist,
            album: album ?? song.album,
            lines: lyricLines,
            source: source
        )
    }
    
    /// 解析LRC行
    private func parseLRCLine(_ line: String) -> LyricLine? {
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
        
        guard !text.isEmpty else { return nil }
        
        let timeStamp = TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0
        
        return LyricLine(timeStamp: timeStamp, text: text)
    }
    
    /// 提取元数据
    private func extractMetadata(from line: String, prefix: String, suffix: String) -> String? {
        guard line.hasPrefix(prefix) && line.hasSuffix(suffix) else { return nil }
        let startIndex = line.index(line.startIndex, offsetBy: prefix.count)
        let endIndex = line.index(line.endIndex, offsetBy: -suffix.count)
        return String(line[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 保存歌词到本地
    private func saveLyricsToLocal(_ lyrics: Lyrics, for song: Song) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "\(song.artist) - \(song.title).lrc"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        let lrcContent = generateLRCContent(from: lyrics)
        
        do {
            try lrcContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ 歌词已保存到本地: \(fileName)")
        } catch {
            print("❌ 保存歌词失败: \(error.localizedDescription)")
        }
    }
    
    /// 生成LRC格式内容
    private func generateLRCContent(from lyrics: Lyrics) -> String {
        var content = ""
        
        // 添加元数据
        if let title = lyrics.title {
            content += "[ti:\(title)]\n"
        }
        if let artist = lyrics.artist {
            content += "[ar:\(artist)]\n"
        }
        if let album = lyrics.album {
            content += "[al:\(album)]\n"
        }
        content += "[by:mPlayer]\n\n"
        
        // 添加歌词行
        for line in lyrics.lines {
            let minutes = Int(line.timeStamp) / 60
            let seconds = Int(line.timeStamp) % 60
            let milliseconds = Int((line.timeStamp.truncatingRemainder(dividingBy: 1)) * 100)
            content += String(format: "[%02d:%02d.%02d]%@\n", minutes, seconds, milliseconds, line.text)
        }
        
        return content
    }
}

// MARK: - 歌词下载错误枚举
enum LyricsDownloadError: LocalizedError {
    case alreadyDownloading
    case invalidURL
    case networkError(Error)
    case noData
    case parseError
    case noLyricsFound
    case sourceNotAvailable
    case searchError(LyricsSearchError)
    
    var errorDescription: String? {
        switch self {
        case .alreadyDownloading:
            return "正在下载中，请稍候"
        case .invalidURL:
            return "无效的URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .noData:
            return "未收到数据"
        case .parseError:
            return "解析数据失败"
        case .noLyricsFound:
            return "未找到匹配的歌词"
        case .sourceNotAvailable:
            return "歌词源不可用"
        case .searchError(let searchError):
            return searchError.localizedDescription
        }
    }
}

 