import SwiftUI

// MARK: - 专辑封面持久化设置视图
struct ArtworkPersistenceSettingsView: View {
    
    @StateObject private var persistenceManager = AlbumArtworkPersistenceManager.shared
    @StateObject private var musicDataManager = MusicDataManager.shared
    
    @State private var showingCleanupAlert = false
    @State private var showingExportAlert = false
    @State private var exportProgress: (success: Int, failure: Int) = (0, 0)
    @State private var isExporting = false
    @State private var selectedArtworkSource = "全部"
    
    private let artworkSources = ["全部", "iTunes", "Last.fm", "Default Music", "Default Color", "Download"]
    
    var body: some View {
        NavigationView {
            List {
                // 存储统计部分
                Section("存储统计") {
                    storageStatisticsSection
                }
                
                // 来源统计部分
                Section("来源统计") {
                    sourceStatisticsSection
                }
                
                // 最近添加部分
                Section("最近添加") {
                    recentArtworksSection
                }
                
                // 管理操作部分
                Section("管理操作") {
                    managementActionsSection
                }
                
                // 导出功能部分
                Section("导出功能") {
                    exportSection
                }
                
                // 高级设置部分
                Section("高级设置") {
                    advancedSettingsSection
                }
            }
            .navigationTitle("专辑封面存储")
            .navigationBarTitleDisplayMode(.large)
            .alert("清理完成", isPresented: $showingCleanupAlert) {
                Button("确定") { }
            } message: {
                Text("已清理未使用的专辑封面文件")
            }
            .alert("导出完成", isPresented: $showingExportAlert) {
                Button("确定") { }
            } message: {
                Text("成功导出 \(exportProgress.success) 张专辑封面，失败 \(exportProgress.failure) 张")
            }
        }
    }
    
    // MARK: - 存储统计部分
    private var storageStatisticsSection: some View {
        Group {
            statisticRow(
                icon: "photo.stack",
                title: "专辑封面数量",
                value: "\(persistenceManager.artworkCount) 张",
                color: .blue
            )
            
            statisticRow(
                icon: "externaldrive",
                title: "总存储大小",
                value: persistenceManager.formatFileSize(persistenceManager.totalStorageSize),
                color: .green
            )
            
            let statistics = persistenceManager.getArtworkStatistics()
            statisticRow(
                icon: "chart.bar",
                title: "平均文件大小",
                value: persistenceManager.formatFileSize(statistics.averageSize),
                color: .orange
            )
            
            // 存储位置信息
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                VStack(alignment: .leading) {
                    Text("存储位置")
                        .font(.headline)
                    Text("Documents/Artworks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - 来源统计部分
    private var sourceStatisticsSection: some View {
        Group {
            let sourceStats = persistenceManager.getSourceStatistics()
            
            ForEach(sourceStats.sorted(by: { $0.value > $1.value }), id: \.key) { source, count in
                HStack {
                    Image(systemName: iconForSource(source))
                        .foregroundColor(colorForSource(source))
                        .frame(width: 20)
                    
                    Text(source)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.headline)
                        .foregroundColor(colorForSource(source))
                }
            }
            
            if sourceStats.isEmpty {
                HStack {
                    Image(systemName: "photo.badge.plus")
                        .foregroundColor(.gray)
                    
                    Text("暂无专辑封面")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 最近添加部分
    private var recentArtworksSection: some View {
        Group {
            let recentArtworks = persistenceManager.getRecentArtworks(limit: 5)
            
            ForEach(recentArtworks.indices, id: \.self) { index in
                let item = recentArtworks[index]
                
                HStack {
                    // 专辑封面缩略图
                    if let song = item.song,
                       let image = persistenceManager.getArtworkImage(for: song, useThumbnail: true) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipped()
                            .cornerRadius(6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let song = item.song {
                            Text(song.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(song.artist) - \(song.album)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("未知歌曲")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(formatDate(item.metadata.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(item.metadata.source)
                            .font(.caption)
                            .foregroundColor(colorForSource(item.metadata.source))
                        
                        Text(persistenceManager.formatFileSize(item.metadata.fileSize))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if recentArtworks.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                    
                    Text("暂无最近添加的专辑封面")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 管理操作部分
    private var managementActionsSection: some View {
        Group {
            Button(action: cleanupUnusedArtworks) {
                HStack {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("清理未使用的封面")
                            .foregroundColor(.primary)
                        Text("删除不再关联任何歌曲的专辑封面")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            NavigationLink(destination: ArtworkDetailListView()) {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("查看所有专辑封面")
                        Text("浏览和管理所有已保存的专辑封面")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button(action: refreshStatistics) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.green)
                    
                    Text("刷新统计信息")
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - 导出功能部分
    private var exportSection: some View {
        Group {
            Button(action: exportAllArtworks) {
                HStack {
                    Image(systemName: "square.and.arrow.up.circle")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("导出到相册")
                            .foregroundColor(.primary)
                        Text("将所有专辑封面保存到系统相册")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .disabled(isExporting || persistenceManager.artworkCount == 0)
        }
    }
    
    // MARK: - 高级设置部分
    private var advancedSettingsSection: some View {
        Group {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading) {
                    Text("压缩质量")
                        .font(.headline)
                    Text("原图: 80%, 缩略图: 60%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Image(systemName: "photo.badge.plus")
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading) {
                    Text("缩略图尺寸")
                        .font(.headline)
                    Text("150x150 像素")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading) {
                    Text("元数据存储")
                        .font(.headline)
                    Text("JSON 格式，包含来源和创建时间")
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
    
    // MARK: - Helper Methods
    private func iconForSource(_ source: String) -> String {
        switch source {
        case "iTunes":
            return "music.note.house"
        case "Last.fm":
            return "waveform.circle"
        case "Default Music":
            return "music.quarternote.3"
        case "Default Color":
            return "paintpalette"
        case "Download":
            return "arrow.down.circle"
        default:
            return "questionmark.circle"
        }
    }
    
    private func colorForSource(_ source: String) -> Color {
        switch source {
        case "iTunes":
            return .blue
        case "Last.fm":
            return .red
        case "Default Music":
            return .green
        case "Default Color":
            return .orange
        case "Download":
            return .purple
        default:
            return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    private func cleanupUnusedArtworks() {
        persistenceManager.cleanupUnusedArtworks()
        showingCleanupAlert = true
    }
    
    private func exportAllArtworks() {
        isExporting = true
        
        persistenceManager.exportAllArtworksToPhotos { success, failure in
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportProgress = (success, failure)
                self.showingExportAlert = true
            }
        }
    }
    
    private func refreshStatistics() {
        // 触发统计信息更新
        persistenceManager.objectWillChange.send()
    }
}

// MARK: - 专辑封面详细列表视图
struct ArtworkDetailListView: View {
    
    @StateObject private var persistenceManager = AlbumArtworkPersistenceManager.shared
    @StateObject private var musicDataManager = MusicDataManager.shared
    
    @State private var searchText = ""
    @State private var selectedSource = "全部"
    
    private let sources = ["全部", "iTunes", "Last.fm", "Default Music", "Default Color", "Download"]
    
    var body: some View {
        List {
            ForEach(filteredSongs, id: \.id) { song in
                ArtworkDetailRow(song: song)
            }
        }
        .navigationTitle("专辑封面详情")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "搜索歌曲或艺术家")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu("筛选") {
                    ForEach(sources, id: \.self) { source in
                        Button(source) {
                            selectedSource = source
                        }
                    }
                }
            }
        }
    }
    
    private var filteredSongs: [Song] {
        let songsWithArtwork = musicDataManager.songs.filter { song in
            persistenceManager.hasArtwork(for: song)
        }
        
        var filtered = songsWithArtwork
        
        // 按来源筛选
        if selectedSource != "全部" {
            filtered = filtered.filter { song in
                if let metadata = persistenceManager.getArtworkMetadata(for: song) {
                    return metadata.source == selectedSource
                }
                return false
            }
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { song in
                song.title.localizedCaseInsensitiveContains(searchText) ||
                song.artist.localizedCaseInsensitiveContains(searchText) ||
                song.album.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { $0.title < $1.title }
    }
}

// MARK: - 专辑封面详细行视图
struct ArtworkDetailRow: View {
    
    let song: Song
    @StateObject private var persistenceManager = AlbumArtworkPersistenceManager.shared
    
    var body: some View {
        HStack {
            // 专辑封面
            if let image = persistenceManager.getArtworkImage(for: song) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(song.artist) - \(song.album)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let metadata = persistenceManager.getArtworkMetadata(for: song) {
                    HStack {
                        Text(metadata.source)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorForSource(metadata.source).opacity(0.2))
                            .foregroundColor(colorForSource(metadata.source))
                            .cornerRadius(4)
                        
                        Text(persistenceManager.formatFileSize(metadata.fileSize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let dimensions = metadata.dimensions {
                            Text("\(Int(dimensions.width))×\(Int(dimensions.height))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func colorForSource(_ source: String) -> Color {
        switch source {
        case "iTunes": return .blue
        case "Last.fm": return .red
        case "Default Music": return .green
        case "Default Color": return .orange
        case "Download": return .purple
        default: return .gray
        }
    }
}

// MARK: - 预览
struct ArtworkPersistenceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ArtworkPersistenceSettingsView()
    }
} 