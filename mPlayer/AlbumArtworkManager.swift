import Foundation
import SwiftUI
import Combine

// MARK: - 专辑封面管理器
class AlbumArtworkManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var downloadingArtworks: Set<UUID> = []
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var artworkCache: [String: UIImage] = [:]
    
    // MARK: - Private Properties
    private let downloadService = AlbumArtworkDownloadService.shared
    private var cancellables = Set<AnyCancellable>()
    private let cacheQueue = DispatchQueue(label: "artwork.cache", qos: .utility)
    
    // MARK: - Constants
    private struct CacheConstants {
        static let maxCacheSize = 50 // 最大缓存图片数量
        static let defaultArtworkName = "default_album"
    }
    
    // MARK: - Singleton
    static let shared = AlbumArtworkManager()
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        downloadService.$isDownloading
            .sink { _ in
                // 可以在这里处理全局下载状态
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 获取歌曲的专辑封面图片
    func getArtworkImage(for song: Song) -> UIImage? {
        // 首先尝试从持久化管理器获取
        if let persistedImage = AlbumArtworkPersistenceManager.shared.getArtworkImage(for: song) {
            // 缓存到内存中以提高性能
            let cacheKey = song.id.uuidString
            cacheArtwork(persistedImage, for: cacheKey)
            return persistedImage
        }
        
        // 然后检查内存缓存
        let cacheKey = song.id.uuidString
        if let cachedImage = artworkCache[cacheKey] {
            return cachedImage
        }
        
        // 尝试从旧的本地文件加载（向后兼容）
        if let localImage = loadLocalArtwork(for: song) {
            cacheArtwork(localImage, for: cacheKey)
            return localImage
        }
        
        // 返回默认图片
        return UIImage(named: CacheConstants.defaultArtworkName)
    }
    
    /// 异步获取专辑封面，如果本地没有则自动下载
    func getArtworkImageAsync(for song: Song, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = song.id.uuidString
        
        // 首先尝试从持久化管理器获取
        if let persistedImage = AlbumArtworkPersistenceManager.shared.getArtworkImage(for: song) {
            cacheArtwork(persistedImage, for: cacheKey)
            completion(persistedImage)
            return
        }
        
        // 然后检查内存缓存
        if let cachedImage = artworkCache[cacheKey] {
            completion(cachedImage)
            return
        }
        
        // 尝试从本地文件加载
        cacheQueue.async { [weak self] in
            if let localImage = self?.loadLocalArtwork(for: song) {
                DispatchQueue.main.async {
                    self?.cacheArtwork(localImage, for: cacheKey)
                    completion(localImage)
                }
                return
            }
            
            // 如果本地没有，检查是否需要下载
            DispatchQueue.main.async {
                if self?.downloadService.needsArtworkDownload(for: song) == true {
                    self?.downloadArtworkIfNeeded(for: song) { image in
                        completion(image)
                    }
                } else {
                    completion(UIImage(named: CacheConstants.defaultArtworkName))
                }
            }
        }
    }
    
    /// 为歌曲下载专辑封面（如果需要）
    func downloadArtworkIfNeeded(for song: Song, completion: @escaping (UIImage?) -> Void) {
        guard downloadService.needsArtworkDownload(for: song) else {
            completion(getArtworkImage(for: song))
            return
        }
        
        guard !downloadingArtworks.contains(song.id) else {
            completion(UIImage(named: CacheConstants.defaultArtworkName))
            return
        }
        
        downloadingArtworks.insert(song.id)
        downloadProgress[song.id] = 0.0
        
        downloadService.downloadArtwork(for: song) { [weak self] result in
            DispatchQueue.main.async {
                self?.downloadingArtworks.remove(song.id)
                self?.downloadProgress.removeValue(forKey: song.id)
                
                switch result {
                case .success(let artworkPath):
                    // 加载新下载的图片
                    if let image = self?.loadArtworkFromPath(artworkPath) {
                        let cacheKey = song.id.uuidString
                        self?.cacheArtwork(image, for: cacheKey)
                        completion(image)
                    } else {
                        completion(UIImage(named: CacheConstants.defaultArtworkName))
                    }
                    
                case .failure(let error):
                    print("❌ 专辑封面下载失败: \(error.localizedDescription)")
                    completion(UIImage(named: CacheConstants.defaultArtworkName))
                }
            }
        }
    }
    
    /// 批量下载专辑封面
    func downloadArtworkForAllSongs(completion: @escaping (Int, Int) -> Void) {
        let songs = MusicDataManager.shared.songs
        downloadService.downloadArtworkForSongs(songs, completion: completion)
    }
    
    /// 检查歌曲是否正在下载专辑封面
    func isDownloadingArtwork(for song: Song) -> Bool {
        return downloadingArtworks.contains(song.id)
    }
    
    /// 获取歌曲的下载进度
    func getDownloadProgress(for song: Song) -> Double {
        return downloadProgress[song.id] ?? 0.0
    }
    
    /// 清理缓存
    func clearCache() {
        artworkCache.removeAll()
        print("✅ 专辑封面缓存已清理")
    }
    
    /// 清理未使用的专辑封面文件
    func cleanupUnusedArtworks() {
        downloadService.cleanupUnusedArtworks()
    }
    
    /// 预加载专辑封面
    func preloadArtworks(for songs: [Song]) {
        cacheQueue.async { [weak self] in
            for song in songs {
                let cacheKey = song.id.uuidString
                if self?.artworkCache[cacheKey] == nil {
                    if let image = self?.loadLocalArtwork(for: song) {
                        DispatchQueue.main.async {
                            self?.cacheArtwork(image, for: cacheKey)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 从本地文件加载专辑封面
    private func loadLocalArtwork(for song: Song) -> UIImage? {
        // 首先尝试从持久化管理器获取
        if let image = AlbumArtworkPersistenceManager.shared.getArtworkImage(for: song) {
            return image
        }
        
        // 如果持久化管理器没有，尝试从旧的路径加载
        guard !song.albumArtwork.isEmpty && song.albumArtwork != CacheConstants.defaultArtworkName else {
            return nil
        }
        
        if let artworkPath = downloadService.getLocalArtworkPath(for: song) {
            return UIImage(contentsOfFile: artworkPath.path)
        }
        
        return nil
    }
    
    /// 从路径加载专辑封面
    private func loadArtworkFromPath(_ fileName: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let artworkPath = documentsPath.appendingPathComponent("Artworks").appendingPathComponent(fileName)
        
        return UIImage(contentsOfFile: artworkPath.path)
    }
    
    /// 缓存专辑封面
    private func cacheArtwork(_ image: UIImage, for key: String) {
        // 检查缓存大小，如果超过限制则清理最旧的
        if artworkCache.count >= CacheConstants.maxCacheSize {
            let keysToRemove = Array(artworkCache.keys.prefix(10))
            for key in keysToRemove {
                artworkCache.removeValue(forKey: key)
            }
        }
        
        artworkCache[key] = image
    }
}

// MARK: - SwiftUI 扩展
extension AlbumArtworkManager {
    
    /// 创建异步加载的专辑封面视图
    func createArtworkView(for song: Song, size: CGFloat = 50) -> some View {
        AsyncArtworkView(song: song, size: size)
    }
}

// MARK: - 异步专辑封面视图
struct AsyncArtworkView: View {
    let song: Song
    let size: CGFloat
    
    @StateObject private var artworkManager = AlbumArtworkManager.shared
    @State private var artworkImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = artworkImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: size, height: size)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                            .font(.system(size: size * 0.4))
                    }
                }
            }
        }
        .onAppear {
            loadArtwork()
        }
        .onChange(of: song.id) {
            loadArtwork()
        }
    }
    
    private func loadArtwork() {
        // 首先尝试同步获取
        if let image = artworkManager.getArtworkImage(for: song) {
            artworkImage = image
            return
        }
        
        // 如果没有，异步加载
        isLoading = true
        artworkManager.getArtworkImageAsync(for: song) { image in
            DispatchQueue.main.async {
                self.artworkImage = image
                self.isLoading = false
            }
        }
    }
}

// MARK: - 专辑封面下载状态视图
struct ArtworkDownloadStatusView: View {
    let song: Song
    
    @StateObject private var artworkManager = AlbumArtworkManager.shared
    
    var body: some View {
        HStack {
            if artworkManager.isDownloadingArtwork(for: song) {
                ProgressView(value: artworkManager.getDownloadProgress(for: song))
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
                
                Text("下载中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if AlbumArtworkDownloadService.shared.needsArtworkDownload(for: song) {
                Button("下载封面") {
                    artworkManager.downloadArtworkIfNeeded(for: song) { _ in }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
} 