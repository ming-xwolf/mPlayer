import SwiftUI

// MARK: - 专辑封面设置视图
struct AlbumArtworkSettingsView: View {
    
    @StateObject private var artworkManager = AlbumArtworkManager.shared
    @StateObject private var downloadService = AlbumArtworkDownloadService.shared
    @StateObject private var musicDataManager = MusicDataManager.shared
    
    @State private var showingDownloadAlert = false
    @State private var downloadProgress: (success: Int, failure: Int) = (0, 0)
    @State private var isDownloading = false
    @State private var showingCleanupAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // 下载状态部分
                Section("下载状态") {
                    downloadStatusSection
                }
                
                // 批量操作部分
                Section("批量操作") {
                    batchOperationsSection
                }
                
                // 缓存管理部分
                Section("缓存管理") {
                    cacheManagementSection
                }
                
                // 统计信息部分
                Section("统计信息") {
                    statisticsSection
                }
                
                // 设置部分
                Section("设置") {
                    settingsSection
                }
                
                // 持久化存储部分
                Section("存储管理") {
                    persistenceSection
                }
            }
            .navigationTitle("专辑封面管理")
            .navigationBarTitleDisplayMode(.large)
            .alert("下载完成", isPresented: $showingDownloadAlert) {
                Button("确定") { }
            } message: {
                Text("成功下载 \(downloadProgress.success) 个专辑封面，失败 \(downloadProgress.failure) 个")
            }
            .alert("清理完成", isPresented: $showingCleanupAlert) {
                Button("确定") { }
            } message: {
                Text("已清理未使用的专辑封面文件")
            }
        }
    }
    
    // MARK: - 下载状态部分
    private var downloadStatusSection: some View {
        Group {
            HStack {
                Image(systemName: downloadService.isDownloading ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .foregroundColor(downloadService.isDownloading ? .blue : .gray)
                
                VStack(alignment: .leading) {
                    Text("下载状态")
                        .font(.headline)
                    Text(downloadService.isDownloading ? "正在下载..." : "空闲")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if downloadService.isDownloading {
                    ProgressView(value: downloadService.downloadProgress)
                        .frame(width: 60)
                }
            }
            
            if let error = downloadService.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("最近错误")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 批量操作部分
    private var batchOperationsSection: some View {
        Group {
            Button(action: downloadAllArtworks) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("下载所有专辑封面")
                            .foregroundColor(.primary)
                        Text("为所有缺少封面的歌曲下载专辑封面")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isDownloading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(downloadService.isDownloading || isDownloading)
            
            Button(action: preloadArtworks) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("预加载专辑封面")
                            .foregroundColor(.primary)
                        Text("将本地专辑封面加载到缓存中")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 缓存管理部分
    private var cacheManagementSection: some View {
        Group {
            HStack {
                Image(systemName: "externaldrive")
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading) {
                    Text("缓存大小")
                        .font(.headline)
                    Text("\(artworkManager.artworkCache.count) 张图片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("清理") {
                    artworkManager.clearCache()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Button(action: cleanupUnusedArtworks) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("清理未使用的文件")
                            .foregroundColor(.primary)
                        Text("删除不再使用的专辑封面文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 统计信息部分
    private var statisticsSection: some View {
        Group {
            statisticRow(
                icon: "music.note.list",
                title: "总歌曲数",
                value: "\(musicDataManager.totalSongs)",
                color: .blue
            )
            
            statisticRow(
                icon: "photo",
                title: "有封面的歌曲",
                value: "\(songsWithArtwork)",
                color: .green
            )
            
            statisticRow(
                icon: "photo.badge.plus",
                title: "需要下载封面",
                value: "\(songsNeedingArtwork)",
                color: .orange
            )
            
            statisticRow(
                icon: "arrow.down.circle",
                title: "正在下载",
                value: "\(artworkManager.downloadingArtworks.count)",
                color: .purple
            )
        }
    }
    
    // MARK: - 设置部分
    private var settingsSection: some View {
        Group {
            NavigationLink(destination: ArtworkSourceSettingsView()) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                    Text("下载源设置")
                }
            }
            
            NavigationLink(destination: ArtworkQualitySettingsView()) {
                HStack {
                    Image(systemName: "photo.badge.checkmark")
                        .foregroundColor(.gray)
                    Text("图片质量设置")
                }
            }
        }
    }
    
    // MARK: - 持久化存储部分
    private var persistenceSection: some View {
        Group {
            NavigationLink(destination: ArtworkPersistenceSettingsView()) {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("专辑封面存储")
                        Text("管理本地存储的专辑封面")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundColor(.green)
                
                VStack(alignment: .leading) {
                    Text("存储使用情况")
                        .font(.headline)
                    Text("\(AlbumArtworkPersistenceManager.shared.artworkCount) 张图片，\(AlbumArtworkPersistenceManager.shared.formatFileSize(AlbumArtworkPersistenceManager.shared.totalStorageSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Helper Views
    private func statisticRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
    }
    
    // MARK: - Computed Properties
    private var songsWithArtwork: Int {
        musicDataManager.songs.filter { song in
            !downloadService.needsArtworkDownload(for: song)
        }.count
    }
    
    private var songsNeedingArtwork: Int {
        musicDataManager.songs.filter { song in
            downloadService.needsArtworkDownload(for: song)
        }.count
    }
    
    // MARK: - Actions
    private func downloadAllArtworks() {
        isDownloading = true
        
        musicDataManager.downloadAllArtworks { success, failure in
            DispatchQueue.main.async {
                self.isDownloading = false
                self.downloadProgress = (success, failure)
                self.showingDownloadAlert = true
            }
        }
    }
    
    private func preloadArtworks() {
        let songs = musicDataManager.songs
        artworkManager.preloadArtworks(for: songs)
    }
    
    private func cleanupUnusedArtworks() {
        musicDataManager.cleanupUnusedArtworks()
        showingCleanupAlert = true
    }
}

// MARK: - 下载源设置视图
struct ArtworkSourceSettingsView: View {
    @State private var enableiTunes = true
    @State private var enableLastfm = false
    @State private var lastfmAPIKey = ""
    
    var body: some View {
        List {
            Section("下载源") {
                Toggle("iTunes Search API", isOn: $enableiTunes)
                
                VStack(alignment: .leading) {
                    Toggle("Last.fm API", isOn: $enableLastfm)
                    
                    if enableLastfm {
                        TextField("Last.fm API Key", text: $lastfmAPIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.caption)
                    }
                }
            }
            
            Section("下载策略") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("1️⃣")
                        Text("优先搜索专辑封面")
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("2️⃣")
                        Text("如果没找到，搜索艺术家照片")
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("3️⃣")
                        Text("如果还没找到，使用精美的音乐艺术图片")
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("4️⃣")
                        Text("最后使用彩色默认封面")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Section("说明") {
                Text("iTunes Search API 是免费的，但可能不包含所有专辑。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Last.fm API 需要申请免费的API密钥，覆盖范围更广。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("智能降级策略确保每首歌曲都能获得合适的封面。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("下载源设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 图片质量设置视图
struct ArtworkQualitySettingsView: View {
    @State private var preferredSize = "600x600"
    @State private var maxFileSize = "5MB"
    @State private var imageFormat = "JPEG"
    
    private let sizeOptions = ["300x300", "600x600", "1000x1000"]
    private let fileSizeOptions = ["1MB", "5MB", "10MB"]
    private let formatOptions = ["JPEG", "PNG"]
    
    var body: some View {
        List {
            Section("图片尺寸") {
                Picker("首选尺寸", selection: $preferredSize) {
                    ForEach(sizeOptions, id: \.self) { size in
                        Text(size).tag(size)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section("文件大小") {
                Picker("最大文件大小", selection: $maxFileSize) {
                    ForEach(fileSizeOptions, id: \.self) { size in
                        Text(size).tag(size)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section("图片格式") {
                Picker("保存格式", selection: $imageFormat) {
                    ForEach(formatOptions, id: \.self) { format in
                        Text(format).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section("说明") {
                Text("更高的图片质量会占用更多存储空间和下载时间。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("图片质量设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 预览
struct AlbumArtworkSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AlbumArtworkSettingsView()
    }
} 