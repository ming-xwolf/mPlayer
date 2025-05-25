import Foundation
import Combine

// MARK: - 歌词搜索API
class LyricsSearchAPI {
    
    // MARK: - 搜索结果模型
    struct SearchResult {
        let title: String
        let artist: String
        let album: String?
        let duration: TimeInterval?
        let lyricsContent: String
        let source: String
        let confidence: Double // 匹配度 0.0-1.0
    }
    
    // MARK: - 搜索参数
    struct SearchParams {
        let title: String
        let artist: String
        let album: String?
        let duration: TimeInterval?
        
        var searchQuery: String {
            return "\(artist) \(title)".trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    // MARK: - 私有属性
    private let session: URLSession
    private let timeout: TimeInterval = 15.0
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 公共方法
    
    /// 搜索歌词
    func searchLyrics(params: SearchParams) async throws -> [SearchResult] {
        var results: [SearchResult] = []
        
        // 并发搜索多个源
        async let neteaseResults = searchNeteaseLyrics(params: params)
        async let lrcLibResults = searchLrcLibLyrics(params: params)
        async let geniusResults = searchGeniusLyrics(params: params)
        
        // 收集所有结果
        do {
            let netease = try await neteaseResults
            results.append(contentsOf: netease)
        } catch {
            print("网易云音乐搜索失败: \(error)")
        }
        
        do {
            let lrcLib = try await lrcLibResults
            results.append(contentsOf: lrcLib)
        } catch {
            print("LrcLib搜索失败: \(error)")
        }
        
        do {
            let genius = try await geniusResults
            results.append(contentsOf: genius)
        } catch {
            print("Genius搜索失败: \(error)")
        }
        
        // 按匹配度排序
        return results.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - 网易云音乐API
    
    private func searchNeteaseLyrics(params: SearchParams) async throws -> [SearchResult] {
        // 由于网易云音乐API需要复杂的加密和认证，这里提供一个简化的示例
        // 实际使用时可能需要使用第三方API或者自建代理服务
        
        let keywords = params.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = "https://music.163.com/api/search/get/web?s=\(keywords)&type=1&offset=0&total=true&limit=5"
        
        guard let url = URL(string: searchURL) else {
            throw LyricsSearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            return []
        }
        
        var results: [SearchResult] = []
        
        for song in songs.prefix(3) {
            guard let songId = song["id"] as? Int,
                  let name = song["name"] as? String,
                  let artists = song["artists"] as? [[String: Any]],
                  let firstArtist = artists.first,
                  let artistName = firstArtist["name"] as? String else {
                continue
            }
            
            // 获取歌词
            if let lyricsContent = try? await fetchNeteaseLyrics(songId: songId) {
                let confidence = calculateConfidence(
                    searchTitle: params.title,
                    searchArtist: params.artist,
                    resultTitle: name,
                    resultArtist: artistName
                )
                
                let searchResult = SearchResult(
                    title: name,
                    artist: artistName,
                    album: (song["album"] as? [String: Any])?["name"] as? String,
                    duration: (song["duration"] as? Double).map { $0 / 1000 },
                    lyricsContent: lyricsContent,
                    source: "网易云音乐",
                    confidence: confidence
                )
                
                results.append(searchResult)
            }
        }
        
        return results
    }
    
    private func fetchNeteaseLyrics(songId: Int) async throws -> String {
        let lyricsURL = "https://music.163.com/api/song/lyric?id=\(songId)&lv=1&kv=1&tv=-1"
        
        guard let url = URL(string: lyricsURL) else {
            throw LyricsSearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrc = json["lrc"] as? [String: Any],
              let lyricText = lrc["lyric"] as? String else {
            throw LyricsSearchError.noLyricsFound
        }
        
        return lyricText
    }
    
    // MARK: - LrcLib API (开源歌词库)
    
    private func searchLrcLibLyrics(params: SearchParams) async throws -> [SearchResult] {
        let baseURL = "https://lrclib.net/api/search"
        var components = URLComponents(string: baseURL)!
        
        components.queryItems = [
            URLQueryItem(name: "track_name", value: params.title),
            URLQueryItem(name: "artist_name", value: params.artist)
        ]
        
        if let album = params.album {
            components.queryItems?.append(URLQueryItem(name: "album_name", value: album))
        }
        
        guard let url = components.url else {
            throw LyricsSearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("mPlayer/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        
        guard let searchResults = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var results: [SearchResult] = []
        
        for item in searchResults.prefix(3) {
            guard let trackName = item["trackName"] as? String,
                  let artistName = item["artistName"] as? String,
                  let plainLyrics = item["plainLyrics"] as? String,
                  !plainLyrics.isEmpty else {
                continue
            }
            
            // 优先使用同步歌词，如果没有则使用纯文本歌词
            let lyricsContent = (item["syncedLyrics"] as? String) ?? plainLyrics
            
            let confidence = calculateConfidence(
                searchTitle: params.title,
                searchArtist: params.artist,
                resultTitle: trackName,
                resultArtist: artistName
            )
            
            let searchResult = SearchResult(
                title: trackName,
                artist: artistName,
                album: item["albumName"] as? String,
                duration: (item["duration"] as? Double),
                lyricsContent: lyricsContent,
                source: "LrcLib",
                confidence: confidence
            )
            
            results.append(searchResult)
        }
        
        return results
    }
    
    // MARK: - Genius API (简化版本)
    
    private func searchGeniusLyrics(params: SearchParams) async throws -> [SearchResult] {
        // Genius API 需要 API Key，这里提供一个简化的示例
        // 实际使用时需要注册 Genius API 并获取 access token
        
        let query = params.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = "https://api.genius.com/search?q=\(query)"
        
        guard let url = URL(string: searchURL) else {
            throw LyricsSearchError.invalidURL
        }
        
        var request = URLRequest(url: url)
        // 需要添加 Authorization header: "Bearer YOUR_ACCESS_TOKEN"
        // request.setValue("Bearer YOUR_ACCESS_TOKEN", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // 由于没有 API Key，这里返回空结果
        // 实际实现时需要解析 Genius API 响应并提取歌词
        return []
    }
    
    // MARK: - 辅助方法
    
    /// 计算匹配度
    private func calculateConfidence(searchTitle: String, searchArtist: String, resultTitle: String, resultArtist: String) -> Double {
        let titleSimilarity = stringSimilarity(searchTitle.lowercased(), resultTitle.lowercased())
        let artistSimilarity = stringSimilarity(searchArtist.lowercased(), resultArtist.lowercased())
        
        // 艺术家匹配权重更高
        return titleSimilarity * 0.6 + artistSimilarity * 0.4
    }
    
    /// 计算字符串相似度（简化版本）
    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        if longer.isEmpty {
            return 1.0
        }
        
        let editDistance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    /// 计算编辑距离
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        for i in 0...str1Count {
            matrix[i][0] = i
        }
        
        for j in 0...str2Count {
            matrix[0][j] = j
        }
        
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i-1] == str2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
}

// MARK: - 错误类型
enum LyricsSearchError: LocalizedError {
    case invalidURL
    case noLyricsFound
    case networkError(Error)
    case parseError
    case rateLimited
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noLyricsFound:
            return "未找到歌词"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .parseError:
            return "解析数据失败"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .unauthorized:
            return "API认证失败"
        }
    }
} 