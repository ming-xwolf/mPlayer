import Foundation
import SwiftUI
import Combine

// MARK: - 音乐数据管理器
class MusicDataManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var songs: [Song] = []
    @Published var albums: [Album] = []
    @Published var artists: [Artist] = []
    @Published var playlists: [Playlist] = []
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let songsKey = "SavedSongs"
    private let playlistsKey = "SavedPlaylists"
    
    // MARK: - Singleton
    static let shared = MusicDataManager()
    
    private init() {
        loadData()
        setupDefaultData()
    }
    
    // MARK: - 数据加载
    private func loadData() {
        loadSongs()
        loadPlaylists()
        updateAlbumsAndArtists()
    }
    
    private func loadSongs() {
        if let data = userDefaults.data(forKey: songsKey),
           let decodedSongs = try? JSONDecoder().decode([Song].self, from: data) {
            songs = decodedSongs
            print("✅ 成功加载 \(songs.count) 首歌曲")
        } else {
            songs = []
            print("ℹ️ 未找到已保存的歌曲数据")
        }
    }
    
    private func loadPlaylists() {
        if let data = userDefaults.data(forKey: playlistsKey),
           let decodedPlaylists = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decodedPlaylists
            print("✅ 成功加载 \(playlists.count) 个播放列表")
        } else {
            // 创建默认播放列表
            playlists = [
                Playlist(title: "我的收藏", songs: [], createdDate: Date()),
                Playlist(title: "最近播放", songs: [], createdDate: Date()),
                Playlist(title: "喜欢的音乐", songs: [], createdDate: Date())
            ]
            savePlaylists()
            print("ℹ️ 创建默认播放列表")
        }
    }
    
    private func setupDefaultData() {
        // 初始化空的数据结构
        if songs.isEmpty {
            updateAlbumsAndArtists()
            print("ℹ️ 初始化空的音乐库")
        }
    }
    
    // MARK: - 数据保存
    private func saveSongs() {
        if let encoded = try? JSONEncoder().encode(songs) {
            userDefaults.set(encoded, forKey: songsKey)
            print("✅ 歌曲数据已保存")
        } else {
            print("❌ 歌曲数据保存失败")
        }
    }
    
    private func savePlaylists() {
        if let encoded = try? JSONEncoder().encode(playlists) {
            userDefaults.set(encoded, forKey: playlistsKey)
            print("✅ 播放列表数据已保存")
        } else {
            print("❌ 播放列表数据保存失败")
        }
    }
    
    // MARK: - 歌曲管理
    func addSong(_ song: Song) {
        songs.append(song)
        saveSongs()
        updateAlbumsAndArtists()
        
        // 自动下载专辑封面
        downloadArtworkIfNeeded(for: song)
        
        print("✅ 添加歌曲: \(song.title)")
    }
    
    func addSongs(_ newSongs: [Song]) {
        songs.append(contentsOf: newSongs)
        saveSongs()
        updateAlbumsAndArtists()
        
        // 批量下载专辑封面
        downloadArtworkForSongs(newSongs)
        
        print("✅ 添加 \(newSongs.count) 首歌曲")
    }
    
    func removeSong(_ song: Song) {
        songs.removeAll { $0.id == song.id }
        
        // 删除对应的专辑封面
        AlbumArtworkPersistenceManager.shared.removeArtwork(for: song)
        
        saveSongs()
        updateAlbumsAndArtists()
        print("✅ 删除歌曲: \(song.title)")
    }
    
    func updateSong(_ song: Song) {
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            songs[index] = song
            saveSongs()
            updateAlbumsAndArtists()
            print("✅ 更新歌曲: \(song.title)")
        }
    }
    
    func toggleFavorite(for song: Song) {
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            songs[index] = Song(
                id: song.id,
                title: song.title,
                artist: song.artist,
                album: song.album,
                duration: song.duration,
                albumArtwork: song.albumArtwork,
                fileName: song.fileName,
                isFavorite: !song.isFavorite
            )
            saveSongs()
            updateFavoritesPlaylist()
            print("✅ 切换收藏状态: \(song.title) - \(songs[index].isFavorite ? "已收藏" : "取消收藏")")
        }
    }
    
    // MARK: - 播放列表管理
    func createPlaylist(title: String) -> Playlist {
        let playlist = Playlist(title: title, songs: [], createdDate: Date())
        playlists.append(playlist)
        savePlaylists()
        print("✅ 创建播放列表: \(title)")
        return playlist
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
        print("✅ 删除播放列表: \(playlist.title)")
    }
    
    func addSongToPlaylist(_ song: Song, playlist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            if !playlists[index].songs.contains(where: { $0.id == song.id }) {
                playlists[index].songs.append(song)
                savePlaylists()
                print("✅ 添加歌曲到播放列表: \(song.title) -> \(playlist.title)")
            }
        }
    }
    
    func removeSongFromPlaylist(_ song: Song, playlist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index].songs.removeAll { $0.id == song.id }
            savePlaylists()
            print("✅ 从播放列表移除歌曲: \(song.title) <- \(playlist.title)")
        }
    }
    
    // MARK: - 专辑和艺术家更新
    private func updateAlbumsAndArtists() {
        albums = generateAlbumsFromSongs(songs)
        artists = generateArtistsFromAlbums(albums)
        updateFavoritesPlaylist()
    }
    
    private func updateFavoritesPlaylist() {
        // 更新"喜欢的音乐"播放列表
        if let index = playlists.firstIndex(where: { $0.title == "喜欢的音乐" }) {
            let favoriteSongs = songs.filter { $0.isFavorite }
            playlists[index].songs = favoriteSongs
            savePlaylists()
        }
    }
    
    // 从歌曲列表生成专辑
    private func generateAlbumsFromSongs(_ allSongs: [Song]) -> [Album] {
        let albumGroups = Dictionary(grouping: allSongs) { song in
            "\(song.album)_\(song.artist)"
        }
        
        var generatedAlbums: [Album] = []
        
        for (_, albumSongs) in albumGroups {
            guard let firstSong = albumSongs.first else { continue }
            
            let album = Album(
                title: firstSong.album,
                artist: firstSong.artist,
                artwork: firstSong.albumArtwork,
                songs: albumSongs.sorted { $0.title < $1.title }
            )
            
            generatedAlbums.append(album)
        }
        
        return generatedAlbums.sorted { $0.title < $1.title }
    }
    
    // 从专辑列表生成艺术家
    private func generateArtistsFromAlbums(_ allAlbums: [Album]) -> [Artist] {
        let artistGroups = Dictionary(grouping: allAlbums) { album in
            album.artist
        }
        
        var generatedArtists: [Artist] = []
        
        for (artistName, artistAlbums) in artistGroups {
            let representativeArtwork = artistAlbums.first?.artwork ?? "default_artist"
            
            let artist = Artist(
                name: artistName,
                artwork: representativeArtwork,
                albums: artistAlbums.sorted { $0.title < $1.title }
            )
            
            generatedArtists.append(artist)
        }
        
        return generatedArtists.sorted { $0.name < $1.name }
    }
    
    // MARK: - 搜索功能
    func searchSongs(query: String) -> [Song] {
        if query.isEmpty {
            return songs
        }
        
        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query) ||
            $0.album.localizedCaseInsensitiveContains(query)
        }
    }
    
    func searchAlbums(query: String) -> [Album] {
        if query.isEmpty {
            return albums
        }
        
        return albums.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query)
        }
    }
    
    func searchArtists(query: String) -> [Artist] {
        if query.isEmpty {
            return artists
        }
        
        return artists.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - 数据清理
    func clearAllData() {
        songs.removeAll()
        albums.removeAll()
        artists.removeAll()
        playlists.removeAll()
        
        userDefaults.removeObject(forKey: songsKey)
        userDefaults.removeObject(forKey: playlistsKey)
        
        // 清理Documents目录中的音频文件
        clearAudioFiles()
        
        setupDefaultData()
        print("✅ 清除所有数据并重置为默认状态")
    }
    
    private func clearAudioFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            
            for file in files {
                let fileName = file.lastPathComponent
                // 删除音频文件和演示文件
                if fileName.hasSuffix(".mp3") || fileName.hasSuffix(".wav") || 
                   fileName.hasSuffix(".aiff") || fileName.hasSuffix(".m4a") ||
                   fileName.hasPrefix("demo_") || fileName.hasPrefix("sample_") {
                    try FileManager.default.removeItem(at: file)
                    print("🗑️ 删除文件: \(fileName)")
                }
            }
        } catch {
            print("❌ 清理音频文件失败: \(error)")
        }
    }
    
    // MARK: - 统计信息
    var totalSongs: Int { songs.count }
    var totalAlbums: Int { albums.count }
    var totalArtists: Int { artists.count }
    var totalPlaylists: Int { playlists.count }
    var favoriteSongs: [Song] { songs.filter { $0.isFavorite } }
    
    var totalDuration: TimeInterval {
        songs.reduce(0) { $0 + $1.duration }
    }
    
    var formattedTotalDuration: String {
        let totalMinutes = Int(totalDuration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    // MARK: - 专辑封面管理
    
    /// 为单首歌曲下载专辑封面（如果需要）
    private func downloadArtworkIfNeeded(for song: Song) {
        guard AlbumArtworkDownloadService.shared.needsArtworkDownload(for: song) else {
            return
        }
        
        AlbumArtworkManager.shared.downloadArtworkIfNeeded(for: song) { [weak self] image in
            if image != nil {
                print("✅ 专辑封面下载完成: \(song.album)")
            }
        }
    }
    
    /// 批量下载专辑封面
    private func downloadArtworkForSongs(_ songs: [Song]) {
        let songsNeedingArtwork = songs.filter { 
            AlbumArtworkDownloadService.shared.needsArtworkDownload(for: $0) 
        }
        
        guard !songsNeedingArtwork.isEmpty else { return }
        
        print("🎨 开始为 \(songsNeedingArtwork.count) 首歌曲下载专辑封面")
        
        // 延迟执行，避免阻塞UI
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            AlbumArtworkDownloadService.shared.downloadArtworkForSongs(songsNeedingArtwork) { successCount, failureCount in
                DispatchQueue.main.async {
                    print("✅ 专辑封面批量下载完成: 成功 \(successCount)，失败 \(failureCount)")
                }
            }
        }
    }
    
    /// 手动触发所有歌曲的专辑封面下载
    func downloadAllArtworks(completion: @escaping (Int, Int) -> Void) {
        AlbumArtworkManager.shared.downloadArtworkForAllSongs(completion: completion)
    }
    
    /// 清理未使用的专辑封面
    func cleanupUnusedArtworks() {
        AlbumArtworkManager.shared.cleanupUnusedArtworks()
    }
} 