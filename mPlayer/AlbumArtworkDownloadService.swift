import Foundation
import SwiftUI
import Combine

// MARK: - 专辑封面下载错误
enum AlbumArtworkDownloadError: Error, LocalizedError {
    case noArtworkFound
    case invalidImageData
    case networkError(Error)
    case alreadyDownloading
    case saveError(Error)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .noArtworkFound:
            return "未找到专辑封面"
        case .invalidImageData:
            return "无效的图片数据"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .alreadyDownloading:
            return "正在下载中，请稍候"
        case .saveError(let error):
            return "保存失败: \(error.localizedDescription)"
        case .invalidURL:
            return "无效的URL"
        }
    }
}

// MARK: - 专辑封面搜索结果
struct AlbumArtworkSearchResult {
    let imageURL: String
    let thumbnailURL: String?
    let size: CGSize?
    let source: String
    let confidence: Double
}

// MARK: - 专辑封面下载服务
class AlbumArtworkDownloadService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var lastError: String?
    
    // MARK: - Private Properties
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    private struct APIConstants {
        // iTunes Search API
        static let itunesSearchAPI = "https://itunes.apple.com/search"
        // Last.fm API
        static let lastfmAPI = "https://ws.audioscrobbler.com/2.0/"
        static let lastfmAPIKey = "YOUR_LASTFM_API_KEY" // 需要申请API密钥
        // MusicBrainz API
        static let musicBrainzAPI = "https://musicbrainz.org/ws/2/"
        // Cover Art Archive API
        static let coverArtArchiveAPI = "https://coverartarchive.org/"
        
        static let userAgent = "mPlayer/1.0 (iOS Music Player)"
        static let timeout: TimeInterval = 30.0
        static let maxImageSize: Int = 1024 * 1024 * 5 // 5MB
    }
    
    // MARK: - Singleton
    static let shared = AlbumArtworkDownloadService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 检查歌曲是否需要下载专辑封面
    func needsArtworkDownload(for song: Song) -> Bool {
        return song.albumArtwork.isEmpty || 
               song.albumArtwork == "default_album" ||
               !isLocalArtworkExists(for: song)
    }
    
    /// 下载专辑封面的主要方法（带降级策略）
    func downloadArtwork(for song: Song, completion: @escaping (Result<String, AlbumArtworkDownloadError>) -> Void) {
        guard !isDownloading else {
            completion(.failure(.alreadyDownloading))
            return
        }
        
        guard needsArtworkDownload(for: song) else {
            completion(.success(song.albumArtwork))
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        lastError = nil
        
        print("🎨 开始搜索专辑封面: \(song.artist) - \(song.album)")
        
        Task {
            do {
                downloadProgress = 0.1
                
                // 第一步：尝试搜索专辑封面
                var searchResults = try await searchAlbumArtwork(artist: song.artist, album: song.album)
                
                downloadProgress = 0.3
                
                // 第二步：如果没找到专辑封面，尝试搜索艺术家照片
                if searchResults.isEmpty {
                    print("🎭 未找到专辑封面，尝试搜索艺术家照片: \(song.artist)")
                    searchResults = try await searchArtistPhoto(artist: song.artist)
                }
                
                downloadProgress = 0.5
                
                // 第三步：如果还没找到，使用默认封面
                if searchResults.isEmpty {
                    print("🖼️ 未找到艺术家照片，使用默认封面")
                    searchResults = try await getDefaultArtwork()
                }
                
                downloadProgress = 0.7
                
                guard let bestResult = searchResults.first else {
                    throw AlbumArtworkDownloadError.noArtworkFound
                }
                
                // 下载图片
                let imageData = try await downloadImageData(from: bestResult.imageURL)
                
                downloadProgress = 0.9
                
                // 保存到本地
                let localPath = try saveArtworkToLocal(imageData, for: song)
                
                DispatchQueue.main.async { [weak self] in
                    self?.isDownloading = false
                    self?.downloadProgress = 1.0
                    
                    print("✅ 封面下载成功: \(song.album) (来源: \(bestResult.source))")
                    completion(.success(localPath))
                }
                
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.isDownloading = false
                    self?.downloadProgress = 0.0
                    
                    let downloadError: AlbumArtworkDownloadError
                    if let artworkError = error as? AlbumArtworkDownloadError {
                        downloadError = artworkError
                    } else {
                        downloadError = .networkError(error)
                    }
                    
                    print("❌ 封面下载失败: \(downloadError.localizedDescription)")
                    self?.lastError = downloadError.localizedDescription
                    completion(.failure(downloadError))
                }
            }
        }
    }
    
    /// 批量下载专辑封面
    func downloadArtworkForSongs(_ songs: [Song], completion: @escaping (Int, Int) -> Void) {
        let songsNeedingArtwork = songs.filter { needsArtworkDownload(for: $0) }
        
        guard !songsNeedingArtwork.isEmpty else {
            completion(0, 0)
            return
        }
        
        var successCount = 0
        var failureCount = 0
        let totalCount = songsNeedingArtwork.count
        
        print("🎨 开始批量下载专辑封面，共 \(totalCount) 首歌曲需要下载")
        
        let group = DispatchGroup()
        
        for song in songsNeedingArtwork {
            group.enter()
            
            downloadArtwork(for: song) { result in
                switch result {
                case .success(let artworkPath):
                    successCount += 1
                    // 更新歌曲的专辑封面路径
                    self.updateSongArtwork(song, artworkPath: artworkPath)
                case .failure:
                    failureCount += 1
                }
                
                group.leave()
                
                // 添加延迟避免API限制
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {}
            }
        }
        
        group.notify(queue: .main) {
            print("✅ 批量下载完成: 成功 \(successCount)，失败 \(failureCount)")
            completion(successCount, failureCount)
        }
    }
    
    // MARK: - Private Methods
    
    /// 检查本地专辑封面是否存在
    private func isLocalArtworkExists(for song: Song) -> Bool {
        return AlbumArtworkPersistenceManager.shared.hasArtwork(for: song)
    }
    
    /// 搜索专辑封面（综合多个来源）
    private func searchAlbumArtwork(artist: String, album: String) async throws -> [AlbumArtworkSearchResult] {
        // 首先尝试iTunes Search API
        var searchResults = try await searchArtworkFromItunes(artist: artist, album: album)
        
        // 如果iTunes没有找到，尝试Last.fm API
        if searchResults.isEmpty {
            searchResults = try await searchArtworkFromLastfm(artist: artist, album: album)
        }
        
        return searchResults
    }
    
    /// 从iTunes Search API搜索专辑封面
    private func searchArtworkFromItunes(artist: String, album: String) async throws -> [AlbumArtworkSearchResult] {
        let query = "\(artist) \(album)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(APIConstants.itunesSearchAPI)?term=\(query)&media=music&entity=album&limit=5"
        
        guard let url = URL(string: urlString) else {
            throw AlbumArtworkDownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(APIConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = APIConstants.timeout
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }
        
        var searchResults: [AlbumArtworkSearchResult] = []
        
        for result in results {
            guard let artworkUrl100 = result["artworkUrl100"] as? String else { continue }
            
            // 将100x100的图片URL替换为更高分辨率
            let artworkUrl = artworkUrl100.replacingOccurrences(of: "100x100", with: "600x600")
            
            let albumName = result["collectionName"] as? String ?? ""
            let artistName = result["artistName"] as? String ?? ""
            
            // 计算匹配度
            let confidence = calculateMatchConfidence(
                searchArtist: artist,
                searchAlbum: album,
                resultArtist: artistName,
                resultAlbum: albumName
            )
            
            let searchResult = AlbumArtworkSearchResult(
                imageURL: artworkUrl,
                thumbnailURL: artworkUrl100,
                size: CGSize(width: 600, height: 600),
                source: "iTunes",
                confidence: confidence
            )
            
            searchResults.append(searchResult)
        }
        
        return searchResults.sorted { $0.confidence > $1.confidence }
    }
    
    /// 从Last.fm API搜索专辑封面
    private func searchArtworkFromLastfm(artist: String, album: String) async throws -> [AlbumArtworkSearchResult] {
        let artistEncoded = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let albumEncoded = album.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "\(APIConstants.lastfmAPI)?method=album.getinfo&api_key=\(APIConstants.lastfmAPIKey)&artist=\(artistEncoded)&album=\(albumEncoded)&format=json"
        
        guard let url = URL(string: urlString) else {
            throw AlbumArtworkDownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(APIConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = APIConstants.timeout
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let albumInfo = json["album"] as? [String: Any],
              let images = albumInfo["image"] as? [[String: Any]] else {
            return []
        }
        
        var searchResults: [AlbumArtworkSearchResult] = []
        
        // 查找最大尺寸的图片
        for image in images {
            guard let size = image["size"] as? String,
                  let imageUrl = image["#text"] as? String,
                  !imageUrl.isEmpty,
                  size == "extralarge" || size == "large" else { continue }
            
            let searchResult = AlbumArtworkSearchResult(
                imageURL: imageUrl,
                thumbnailURL: nil,
                size: nil,
                source: "Last.fm",
                confidence: 0.8
            )
            
            searchResults.append(searchResult)
            break // 只取第一个合适的图片
        }
        
        return searchResults
    }
    
    /// 搜索艺术家照片
    private func searchArtistPhoto(artist: String) async throws -> [AlbumArtworkSearchResult] {
        // 尝试从iTunes搜索艺术家信息
        let artistEncoded = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(APIConstants.itunesSearchAPI)?term=\(artistEncoded)&media=music&entity=musicArtist&limit=5"
        
        guard let url = URL(string: urlString) else {
            throw AlbumArtworkDownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(APIConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = APIConstants.timeout
        
        let (data, _) = try await session.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return []
        }
        
        var searchResults: [AlbumArtworkSearchResult] = []
        
        for result in results {
            // 尝试获取艺术家头像
            if let artistImageUrl = result["artworkUrl100"] as? String {
                let highResImageUrl = artistImageUrl.replacingOccurrences(of: "100x100", with: "600x600")
                
                let artistName = result["artistName"] as? String ?? ""
                let confidence = stringSimilarity(artist.lowercased(), artistName.lowercased())
                
                let searchResult = AlbumArtworkSearchResult(
                    imageURL: highResImageUrl,
                    thumbnailURL: artistImageUrl,
                    size: CGSize(width: 600, height: 600),
                    source: "iTunes Artist",
                    confidence: confidence
                )
                
                searchResults.append(searchResult)
            }
        }
        
        // 如果iTunes没有找到艺术家照片，尝试获取音乐相关的艺术图片
        if searchResults.isEmpty {
            searchResults = try await searchMusicArtwork(query: "\(artist) music")
        }
        
        return searchResults.sorted { $0.confidence > $1.confidence }
    }
    
    /// 搜索音乐相关的艺术图片
    private func searchMusicArtwork(query: String) async throws -> [AlbumArtworkSearchResult] {
        // 使用免费的Pixabay API搜索音乐相关图片
        let queryEncoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://pixabay.com/api/?key=YOUR_PIXABAY_KEY&q=\(queryEncoded)&image_type=photo&orientation=all&category=music&min_width=400&min_height=400&per_page=5"
        
        guard let url = URL(string: urlString) else {
            // 如果API不可用，返回默认音乐图片
            return try await getDefaultMusicArtwork()
        }
        
        var request = URLRequest(url: url)
        request.setValue(APIConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = APIConstants.timeout
        
        do {
            let (data, _) = try await session.data(for: request)
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hits = json["hits"] as? [[String: Any]] else {
                return try await getDefaultMusicArtwork()
            }
            
            var searchResults: [AlbumArtworkSearchResult] = []
            
            for hit in hits {
                if let webformatURL = hit["webformatURL"] as? String {
                    let searchResult = AlbumArtworkSearchResult(
                        imageURL: webformatURL,
                        thumbnailURL: hit["previewURL"] as? String,
                        size: CGSize(width: 640, height: 640),
                        source: "Music Art",
                        confidence: 0.6
                    )
                    
                    searchResults.append(searchResult)
                }
            }
            
            return searchResults.isEmpty ? try await getDefaultMusicArtwork() : searchResults
        } catch {
            // API失败时返回默认音乐图片
            print("⚠️ 音乐图片API请求失败: \(error.localizedDescription)")
            return try await getDefaultMusicArtwork()
        }
    }
    
    /// 获取默认音乐封面
    private func getDefaultMusicArtwork() async throws -> [AlbumArtworkSearchResult] {
        // 提供一些精美的默认音乐封面URL（使用免费的Unsplash图片）
        let defaultArtworkUrls = [
            "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&h=600&fit=crop&crop=center", // 音乐设备
            "https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?w=600&h=600&fit=crop&crop=center", // 音乐工作室
            "https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=600&h=600&fit=crop&crop=center", // 音乐笔记
            "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&h=600&fit=crop&crop=center", // 耳机
            "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=600&fit=crop&crop=center"  // 音响设备
        ]
        
        // 随机选择一个默认封面
        let randomUrl = defaultArtworkUrls.randomElement() ?? defaultArtworkUrls[0]
        
        let defaultResult = AlbumArtworkSearchResult(
            imageURL: randomUrl,
            thumbnailURL: nil,
            size: CGSize(width: 600, height: 600),
            source: "Default Music",
            confidence: 0.3
        )
        
        return [defaultResult]
    }
    
    /// 获取默认封面（最后的降级选项）
    private func getDefaultArtwork() async throws -> [AlbumArtworkSearchResult] {
        // 如果所有方法都失败，使用本地默认图片或简单的颜色封面
        let colorArtworkUrls = [
            "https://via.placeholder.com/600x600/FF6B6B/FFFFFF?text=♪", // 红色
            "https://via.placeholder.com/600x600/4ECDC4/FFFFFF?text=♫", // 青色
            "https://via.placeholder.com/600x600/45B7D1/FFFFFF?text=♪", // 蓝色
            "https://via.placeholder.com/600x600/96CEB4/FFFFFF?text=♫", // 绿色
            "https://via.placeholder.com/600x600/FFEAA7/333333?text=♪"  // 黄色
        ]
        
        let randomUrl = colorArtworkUrls.randomElement() ?? colorArtworkUrls[0]
        
        let defaultResult = AlbumArtworkSearchResult(
            imageURL: randomUrl,
            thumbnailURL: nil,
            size: CGSize(width: 600, height: 600),
            source: "Default Color",
            confidence: 0.1
        )
        
        return [defaultResult]
    }
    
    /// 下载图片数据
    private func downloadImageData(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw AlbumArtworkDownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(APIConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = APIConstants.timeout
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AlbumArtworkDownloadError.networkError(URLError(.badServerResponse))
        }
        
        guard data.count <= APIConstants.maxImageSize else {
            throw AlbumArtworkDownloadError.invalidImageData
        }
        
        // 验证是否为有效的图片数据
        guard UIImage(data: data) != nil else {
            throw AlbumArtworkDownloadError.invalidImageData
        }
        
        return data
    }
    
    /// 保存专辑封面到本地
    private func saveArtworkToLocal(_ imageData: Data, for song: Song) throws -> String {
        // 使用持久化管理器保存
        if let fileName = AlbumArtworkPersistenceManager.shared.saveArtwork(imageData, for: song, source: "Download") {
            return fileName
        } else {
            throw AlbumArtworkDownloadError.saveError(NSError(domain: "ArtworkSave", code: -1, userInfo: [NSLocalizedDescriptionKey: "持久化管理器保存失败"]))
        }
    }
    
    /// 计算匹配度
    private func calculateMatchConfidence(searchArtist: String, searchAlbum: String, 
                                        resultArtist: String, resultAlbum: String) -> Double {
        let artistSimilarity = stringSimilarity(searchArtist.lowercased(), resultArtist.lowercased())
        let albumSimilarity = stringSimilarity(searchAlbum.lowercased(), resultAlbum.lowercased())
        
        return (artistSimilarity * 0.4 + albumSimilarity * 0.6)
    }
    
    /// 计算字符串相似度
    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        if longer.isEmpty { return 1.0 }
        
        let editDistance = levenshteinDistance(str1, str2)
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
    
    /// 更新歌曲的专辑封面路径
    private func updateSongArtwork(_ song: Song, artworkPath: String) {
        let updatedSong = Song(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: song.duration,
            albumArtwork: artworkPath,
            fileName: song.fileName,
            isFavorite: song.isFavorite
        )
        
        MusicDataManager.shared.updateSong(updatedSong)
    }
    
    /// 获取本地专辑封面路径
    func getLocalArtworkPath(for song: Song) -> URL? {
        return AlbumArtworkPersistenceManager.shared.getArtworkPath(for: song)
    }
    
    /// 清理未使用的专辑封面文件
    func cleanupUnusedArtworks() {
        AlbumArtworkPersistenceManager.shared.cleanupUnusedArtworks()
    }
} 