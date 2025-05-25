import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - 资料库视图
struct LibraryView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @StateObject private var dataManager = MusicDataManager.shared
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showingSearch = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showingAddMusicAlert = false
    @State private var showingAddOptions = false
    @State private var showingNewPlaylistAlert = false
    @State private var showingDocumentPicker = false
    @State private var newPlaylistName = ""
    @State private var isScanning = false
    @State private var scanResults: [Song] = []
    @State private var showingScanResults = false
    
    let tabs = ["全部音乐", "专辑", "艺术家", "播放列表"]
    
    var filteredSongs: [Song] {
        return dataManager.searchSongs(query: searchText)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部标题和操作
                if showingSearch {
                    // 搜索模式的标题栏
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(MusicConstants.grayMedium)
                            
                            TextField("搜索歌曲、艺术家或专辑", text: $searchText)
                                .foregroundColor(.white)
                                .onSubmit {
                                    // 处理搜索提交
                                }
                                .focused($isSearchFieldFocused)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(MusicConstants.grayDark)
                        .cornerRadius(12)
                        
                        Button("取消") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingSearch = false
                                searchText = ""
                                isSearchFieldFocused = false
                            }
                        }
                        .foregroundColor(MusicConstants.primaryColor)
                        .font(.body)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    // 正常模式的标题栏
                    HStack {
                        Text("资料库")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                showingAddOptions = true
                            }) {
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(Color.clear)
                                    .contentShape(Rectangle())
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingSearch = true
                                }
                                // 延迟设置焦点，等待动画完成
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFieldFocused = true
                                }
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white)
                                    .font(.title2)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 标签页选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 32) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            VStack(spacing: 8) {
                                Text(tabs[index])
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedTab == index ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                                
                                if selectedTab == index {
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(MusicConstants.primaryColor)
                                        .frame(height: 2)
                                } else {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .onTapGesture {
                                selectedTab = index
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    // 全部音乐
                    allMusicView
                        .tag(0)
                    
                    // 专辑
                    albumsView
                        .tag(1)
                    
                    // 艺术家
                    artistsView
                        .tag(2)
                    
                    // 播放列表
                    playlistsView
                        .tag(3)
                }
                #if os(iOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                #endif
            }
            .background(MusicConstants.darkBackground)
        }
        .confirmationDialog("添加音乐", isPresented: $showingAddOptions) {
            Button("从音乐库导入") {
                showingAddMusicAlert = true
            }
            Button("扫描本地文件") {
                showingDocumentPicker = true
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("选择添加音乐的方式")
        }
        .alert("添加音乐", isPresented: $showingAddMusicAlert) {
            Button("确定") {
                showingAddMusicAlert = false
            }
        } message: {
            Text(scanResults.isEmpty && !isScanning ? 
                 "未找到可用的音频文件。请选择 MP3、M4A、WAV 等格式的音频文件。" : 
                 "此功能需要连接到真实的音乐文件系统。请使用扫描本地文件功能来添加音乐。")
        }
        .alert("新建播放列表", isPresented: $showingNewPlaylistAlert) {
            TextField("播放列表名称", text: $newPlaylistName)
            Button("创建") {
                if !newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    _ = dataManager.createPlaylist(title: newPlaylistName)
                    newPlaylistName = ""
                }
            }
            Button("取消", role: .cancel) {
                newPlaylistName = ""
            }
        } message: {
            Text("请输入播放列表的名称")
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(
                allowedTypes: [.audio],
                allowsMultipleSelection: true
            ) { urls in
                scanAudioFiles(urls: urls)
            }
        }
        .sheet(isPresented: $showingScanResults) {
            ScanResultsView(
                scanResults: $scanResults,
                isPresented: $showingScanResults,
                onAddSelected: addSelectedSongs
            )
        }
        .overlay(
            Group {
                if isScanning {
                    ScanningOverlay()
                }
            }
        )
        .onAppear {
            // 数据管理器会自动处理数据初始化
        }
    }
    
    // MARK: - 扫描音频文件的方法
    private func scanAudioFiles(urls: [URL]) {
        isScanning = true
        scanResults.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var scannedSongs: [Song] = []
            
            for url in urls {
                if let song = self.parseSongFromURL(url) {
                    // 将文件复制到Documents目录以便后续访问
                    if self.copyAudioFileToDocuments(from: url, song: song) {
                        scannedSongs.append(song)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isScanning = false
                self.scanResults = scannedSongs
                if !scannedSongs.isEmpty {
                    self.showingScanResults = true
                } else {
                    // 显示无音频文件的提示
                    self.showingAddMusicAlert = true
                }
            }
        }
    }
    
    // 将音频文件复制到Documents目录
    private func copyAudioFileToDocuments(from sourceURL: URL, song: Song) -> Bool {
        guard sourceURL.startAccessingSecurityScopedResource() else {
            print("❌ 无法访问源文件")
            return false
        }
        
        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(song.fileName)
        
        do {
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // 复制文件
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("✅ 音频文件已复制到: \(destinationURL.path)")
            return true
        } catch {
            print("❌ 复制音频文件失败: \(error)")
            return false
        }
    }
    
    private func parseSongFromURL(_ url: URL) -> Song? {
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ 无法访问文件: \(url.path)")
            return nil
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        let asset = AVAsset(url: url)
        let fileName = url.lastPathComponent
        
        // 获取音频文件的时长 - 使用同步方式获取更可靠的时长
        var duration: TimeInterval = 0
        let group = DispatchGroup()
        group.enter()
        
        Task {
            do {
                let assetDuration = try await asset.load(.duration)
                duration = assetDuration.seconds
                print("✅ 成功获取音频时长: \(duration) 秒")
            } catch {
                print("❌ 无法获取音频时长: \(error)")
                duration = 180 // 默认3分钟
            }
            group.leave()
        }
        
        // 等待时长获取完成（最多等待2秒）
        _ = group.wait(timeout: .now() + 2)
        
        // 获取元数据
        var title = fileName.replacingOccurrences(of: ".\(url.pathExtension)", with: "")
        var artist = "未知艺术家"
        var album = "未知专辑"
        
        // 尝试从元数据中获取信息
        let group2 = DispatchGroup()
        group2.enter()
        
        Task {
            do {
                let metadata = try await asset.load(.metadata)
                for item in metadata {
                    guard let key = item.commonKey?.rawValue,
                          let value = try? await item.load(.stringValue) else { continue }
                    
                    switch key {
                    case "title":
                        title = value
                    case "artist":
                        artist = value
                    case "albumName":
                        album = value
                    default:
                        break
                    }
                }
                print("✅ 成功解析音频元数据: \(title) - \(artist)")
            } catch {
                print("❌ 解析元数据失败: \(error)")
            }
            group2.leave()
        }
        
        // 等待元数据获取完成（最多等待1秒）
        _ = group2.wait(timeout: .now() + 1)
        
        // 确保时长是有效的
        if !duration.isFinite || duration <= 0 {
            duration = 180 // 默认3分钟
        }
        
        print("📱 创建歌曲对象: \(title) (\(Int(duration))秒)")
        
        return Song(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            albumArtwork: "default_album",
            fileName: fileName
        )
    }
    
    private func addSelectedSongs(_ selectedSongs: [Song]) {
        dataManager.addSongs(selectedSongs)
        
        print("✅ 成功添加 \(selectedSongs.count) 首歌曲")
        print("📊 当前共有: \(dataManager.songs.count) 首歌曲, \(dataManager.albums.count) 个专辑, \(dataManager.artists.count) 个艺术家")
    }
    
    // MARK: - 全部音乐视图
    private var allMusicView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(filteredSongs.enumerated()), id: \.element.id) { index, song in
                    LibrarySongRow(song: song, index: index + 1)
                        .onTapGesture {
                            musicPlayer.playSong(song, from: filteredSongs)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .refreshable {
            // 下拉刷新时显示搜索框
            withAnimation(.easeInOut(duration: 0.3)) {
                showingSearch = true
            }
            // 延迟设置焦点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
    }
    
    // MARK: - 专辑视图
    private var albumsView: some View {
        ScrollView {
            if dataManager.albums.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 60))
                        .foregroundColor(MusicConstants.grayMedium)
                    
                    Text("暂无专辑")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("添加音乐后会自动生成专辑信息")
                        .font(.body)
                        .foregroundColor(MusicConstants.grayMedium)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(dataManager.albums) { album in
                        AlbumCard(album: album)
                            .onTapGesture {
                                // 播放专辑中的第一首歌
                                if let firstSong = album.songs.first {
                                    musicPlayer.playSong(firstSong, from: album.songs)
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .refreshable {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingSearch = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
    }
    
    // MARK: - 艺术家视图
    private var artistsView: some View {
        ScrollView {
            if dataManager.artists.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.system(size: 60))
                        .foregroundColor(MusicConstants.grayMedium)
                    
                    Text("暂无艺术家")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("添加音乐后会自动生成艺术家信息")
                        .font(.body)
                        .foregroundColor(MusicConstants.grayMedium)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(dataManager.artists) { artist in
                        ArtistRow(artist: artist)
                            .onTapGesture {
                                // 播放艺术家的所有歌曲
                                let allSongs = artist.albums.flatMap { $0.songs }
                                if let firstSong = allSongs.first {
                                    musicPlayer.playSong(firstSong, from: allSongs)
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .refreshable {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingSearch = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
    }
    
    // MARK: - 播放列表视图
    private var playlistsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 创建播放列表按钮
                Button(action: {
                    showingNewPlaylistAlert = true
                }) {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(MusicConstants.grayDark)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .font(.title2)
                            )
                        
                        Text("新建播放列表")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                // 播放列表
                LazyVStack(spacing: 12) {
                    ForEach(dataManager.playlists, id: \.id) { playlist in
                        PlaylistRow(
                            title: playlist.title,
                            songCount: playlist.songs.count,
                            artwork: "playlist1"
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 16)
        }
        .refreshable {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingSearch = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
    }
}

#Preview {
    LibraryView()
        .preferredColorScheme(.dark)
} 