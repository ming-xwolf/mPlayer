import Foundation
import SwiftUI
import Combine

// MARK: - 专辑封面持久化管理器
class AlbumArtworkPersistenceManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var artworkCount: Int = 0
    @Published var totalStorageSize: Int64 = 0
    
    // MARK: - Public Types
    struct PublicArtworkMetadata {
        let source: String
        let createdAt: Date
        let fileSize: Int64
        let originalURL: String?
        let thumbnailFileName: String?
        
        fileprivate init(from metadata: ArtworkMetadata) {
            self.source = metadata.source
            self.createdAt = metadata.createdAt
            self.fileSize = metadata.fileSize
            self.originalURL = metadata.originalURL
            self.thumbnailFileName = metadata.thumbnailFileName
        }
    }
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private let artworkDirectory: URL
    private let thumbnailDirectory: URL
    private var artworkMetadata: [String: ArtworkMetadata] = [:]
    
    // MARK: - Constants
    private struct Constants {
        static let artworkFolderName = "Artworks"
        static let thumbnailFolderName = "Thumbnails"
        static let metadataFileName = "artwork_metadata.json"
        static let maxThumbnailSize: CGFloat = 150
        static let compressionQuality: CGFloat = 0.8
        static let thumbnailCompressionQuality: CGFloat = 0.6
    }
    
    // MARK: - Artwork Metadata
    fileprivate struct ArtworkMetadata: Codable {
        let songId: UUID
        let fileName: String
        let thumbnailFileName: String?
        let originalURL: String?
        let source: String
        let createdAt: Date
        let fileSize: Int64
        let dimensions: CGSize?
        
        enum CodingKeys: String, CodingKey {
            case songId, fileName, thumbnailFileName, originalURL, source, createdAt, fileSize, dimensions
        }
    }
    
    // MARK: - Singleton
    static let shared = AlbumArtworkPersistenceManager()
    
    // MARK: - Initialization
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.artworkDirectory = documentsPath.appendingPathComponent(Constants.artworkFolderName)
        self.thumbnailDirectory = documentsPath.appendingPathComponent(Constants.thumbnailFolderName)
        
        setupDirectories()
        loadMetadata()
        updateStatistics()
    }
    
    // MARK: - Setup
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
            print("✅ 专辑封面目录创建成功")
        } catch {
            print("❌ 创建专辑封面目录失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// 保存专辑封面到本地
    func saveArtwork(_ imageData: Data, for song: Song, source: String) -> String? {
        guard let image = UIImage(data: imageData) else {
            print("❌ 无效的图片数据")
            return nil
        }
        
        let fileName = generateFileName(for: song)
        let filePath = artworkDirectory.appendingPathComponent(fileName)
        
        do {
            // 压缩并保存原图
            guard let compressedData = image.jpegData(compressionQuality: Constants.compressionQuality) else {
                print("❌ 图片压缩失败")
                return nil
            }
            
            try compressedData.write(to: filePath)
            
            // 生成并保存缩略图
            let thumbnailFileName = generateThumbnailFileName(for: song)
            let thumbnailPath = thumbnailDirectory.appendingPathComponent(thumbnailFileName)
            
            if let thumbnail = generateThumbnail(from: image),
               let thumbnailData = thumbnail.jpegData(compressionQuality: Constants.thumbnailCompressionQuality) {
                try thumbnailData.write(to: thumbnailPath)
            }
            
            // 保存元数据
            let metadata = ArtworkMetadata(
                songId: song.id,
                fileName: fileName,
                thumbnailFileName: thumbnailFileName,
                originalURL: nil,
                source: source,
                createdAt: Date(),
                fileSize: Int64(compressedData.count),
                dimensions: CGSize(width: image.size.width, height: image.size.height)
            )
            
            artworkMetadata[song.id.uuidString] = metadata
            saveMetadata()
            updateStatistics()
            
            print("✅ 专辑封面保存成功: \(fileName)")
            return fileName
            
        } catch {
            print("❌ 保存专辑封面失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 检查歌曲是否有本地专辑封面
    func hasArtwork(for song: Song) -> Bool {
        guard let metadata = artworkMetadata[song.id.uuidString] else {
            return false
        }
        
        let filePath = artworkDirectory.appendingPathComponent(metadata.fileName)
        return fileManager.fileExists(atPath: filePath.path)
    }
    
    /// 获取专辑封面图片
    func getArtworkImage(for song: Song, useThumbnail: Bool = false) -> UIImage? {
        guard let metadata = artworkMetadata[song.id.uuidString] else {
            return nil
        }
        
        if useThumbnail, let thumbnailFileName = metadata.thumbnailFileName {
            let thumbnailPath = thumbnailDirectory.appendingPathComponent(thumbnailFileName)
            if let image = UIImage(contentsOfFile: thumbnailPath.path) {
                return image
            }
        }
        
        let filePath = artworkDirectory.appendingPathComponent(metadata.fileName)
        return UIImage(contentsOfFile: filePath.path)
    }
    
    /// 获取专辑封面文件路径
    func getArtworkPath(for song: Song) -> URL? {
        guard let metadata = artworkMetadata[song.id.uuidString] else {
            return nil
        }
        
        let filePath = artworkDirectory.appendingPathComponent(metadata.fileName)
        return fileManager.fileExists(atPath: filePath.path) ? filePath : nil
    }
    
    /// 删除歌曲的专辑封面
    func removeArtwork(for song: Song) {
        guard let metadata = artworkMetadata[song.id.uuidString] else {
            return
        }
        
        // 删除原图
        let filePath = artworkDirectory.appendingPathComponent(metadata.fileName)
        try? fileManager.removeItem(at: filePath)
        
        // 删除缩略图
        if let thumbnailFileName = metadata.thumbnailFileName {
            let thumbnailPath = thumbnailDirectory.appendingPathComponent(thumbnailFileName)
            try? fileManager.removeItem(at: thumbnailPath)
        }
        
        // 删除元数据
        artworkMetadata.removeValue(forKey: song.id.uuidString)
        saveMetadata()
        updateStatistics()
        
        print("✅ 已删除专辑封面: \(metadata.fileName)")
    }
    
    /// 清理未使用的专辑封面文件
    func cleanupUnusedArtworks() {
        let allSongs = MusicDataManager.shared.songs
        let usedSongIds = Set(allSongs.map { $0.id.uuidString })
        
        var removedCount = 0
        var removedSize: Int64 = 0
        
        for (songIdString, metadata) in artworkMetadata {
            if !usedSongIds.contains(songIdString) {
                // 删除文件
                let filePath = artworkDirectory.appendingPathComponent(metadata.fileName)
                if fileManager.fileExists(atPath: filePath.path) {
                    try? fileManager.removeItem(at: filePath)
                    removedSize += metadata.fileSize
                    removedCount += 1
                }
                
                // 删除缩略图
                if let thumbnailFileName = metadata.thumbnailFileName {
                    let thumbnailPath = thumbnailDirectory.appendingPathComponent(thumbnailFileName)
                    try? fileManager.removeItem(at: thumbnailPath)
                }
                
                // 删除元数据
                artworkMetadata.removeValue(forKey: songIdString)
            }
        }
        
        if removedCount > 0 {
            saveMetadata()
            updateStatistics()
            print("✅ 清理完成: 删除了 \(removedCount) 个未使用的专辑封面，释放空间 \(formatFileSize(removedSize))")
        } else {
            print("✅ 没有需要清理的专辑封面")
        }
    }
    
    /// 获取所有专辑封面的统计信息
    func getArtworkStatistics() -> (count: Int, totalSize: Int64, averageSize: Int64) {
        let count = artworkMetadata.count
        let totalSize = artworkMetadata.values.reduce(0) { $0 + $1.fileSize }
        let averageSize = count > 0 ? totalSize / Int64(count) : 0
        
        return (count: count, totalSize: totalSize, averageSize: averageSize)
    }
    
    /// 格式化文件大小
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 导出专辑封面到相册
    func exportArtworkToPhotos(for song: Song, completion: @escaping (Bool, String?) -> Void) {
        guard let image = getArtworkImage(for: song) else {
            completion(false, "未找到专辑封面")
            return
        }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        completion(true, nil)
    }
    
    /// 批量导出所有专辑封面
    func exportAllArtworksToPhotos(completion: @escaping (Int, Int) -> Void) {
        let allSongs = MusicDataManager.shared.songs.filter { hasArtwork(for: $0) }
        var successCount = 0
        var failureCount = 0
        
        for song in allSongs {
            exportArtworkToPhotos(for: song) { success, _ in
                if success {
                    successCount += 1
                } else {
                    failureCount += 1
                }
                
                if successCount + failureCount == allSongs.count {
                    completion(successCount, failureCount)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 生成文件名
    private func generateFileName(for song: Song) -> String {
        let sanitizedArtist = sanitizeFileName(song.artist)
        let sanitizedAlbum = sanitizeFileName(song.album)
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(sanitizedArtist)_\(sanitizedAlbum)_\(timestamp).jpg"
    }
    
    /// 生成缩略图文件名
    private func generateThumbnailFileName(for song: Song) -> String {
        let sanitizedArtist = sanitizeFileName(song.artist)
        let sanitizedAlbum = sanitizeFileName(song.album)
        let timestamp = Int(Date().timeIntervalSince1970)
        return "thumb_\(sanitizedArtist)_\(sanitizedAlbum)_\(timestamp).jpg"
    }
    
    /// 清理文件名中的非法字符
    private func sanitizeFileName(_ string: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return string.components(separatedBy: invalidCharacters).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(50)
            .description
    }
    
    /// 生成缩略图
    private func generateThumbnail(from image: UIImage) -> UIImage? {
        let size = CGSize(width: Constants.maxThumbnailSize, height: Constants.maxThumbnailSize)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// 加载元数据
    private func loadMetadata() {
        let metadataPath = artworkDirectory.appendingPathComponent(Constants.metadataFileName)
        
        guard fileManager.fileExists(atPath: metadataPath.path),
              let data = try? Data(contentsOf: metadataPath),
              let metadata = try? JSONDecoder().decode([String: ArtworkMetadata].self, from: data) else {
            print("📝 未找到专辑封面元数据文件，将创建新的")
            return
        }
        
        artworkMetadata = metadata
        print("✅ 已加载 \(metadata.count) 个专辑封面元数据")
    }
    
    /// 保存元数据
    private func saveMetadata() {
        let metadataPath = artworkDirectory.appendingPathComponent(Constants.metadataFileName)
        
        do {
            let data = try JSONEncoder().encode(artworkMetadata)
            try data.write(to: metadataPath)
        } catch {
            print("❌ 保存专辑封面元数据失败: \(error.localizedDescription)")
        }
    }
    
    /// 更新统计信息
    private func updateStatistics() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.artworkCount = self.artworkMetadata.count
            self.totalStorageSize = self.artworkMetadata.values.reduce(0) { $0 + $1.fileSize }
        }
    }
}

// MARK: - 专辑封面元数据扩展
extension AlbumArtworkPersistenceManager {
    
    /// 获取专辑封面元数据
    func getArtworkMetadata(for song: Song) -> (source: String, createdAt: Date, fileSize: Int64, dimensions: CGSize?)? {
        guard let metadata = artworkMetadata[song.id.uuidString] else {
            return nil
        }
        
        return (
            source: metadata.source,
            createdAt: metadata.createdAt,
            fileSize: metadata.fileSize,
            dimensions: metadata.dimensions
        )
    }
    
    /// 获取所有专辑封面的来源统计
    func getSourceStatistics() -> [String: Int] {
        var sourceStats: [String: Int] = [:]
        
        for metadata in artworkMetadata.values {
            sourceStats[metadata.source, default: 0] += 1
        }
        
        return sourceStats
    }
    
    /// 获取最近添加的专辑封面
    func getRecentArtworks(limit: Int = 10) -> [(song: Song?, metadata: PublicArtworkMetadata)] {
        let allSongs = MusicDataManager.shared.songs
        let songDict = Dictionary(uniqueKeysWithValues: allSongs.map { ($0.id.uuidString, $0) })
        
        return artworkMetadata.values
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { metadata in
                (song: songDict[metadata.songId.uuidString], metadata: PublicArtworkMetadata(from: metadata))
            }
    }
} 