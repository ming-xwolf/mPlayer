import SwiftUI

// MARK: - 迷你播放器视图
struct MiniPlayerView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @Binding var showingExpandedPlayer: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 专辑封面
            RoundedRectangle(cornerRadius: 8)
                .fill(MusicConstants.grayDark)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(MusicConstants.grayMedium)
                )
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 2) {
                Text(musicPlayer.currentSong?.title ?? "")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(musicPlayer.currentSong?.artist ?? "")
                    .font(.caption)
                    .foregroundColor(MusicConstants.grayMedium)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 播放控制按钮
            HStack(spacing: 16) {
                // 随机播放指示器
                if musicPlayer.isShuffled {
                    Image(systemName: "shuffle")
                        .font(.caption)
                        .foregroundColor(MusicConstants.primaryColor)
                }
                
                Button(action: {
                    // 切换喜欢状态
                }) {
                    Image(systemName: musicPlayer.currentSong?.isFavorite == true ? "heart.fill" : "heart")
                        .foregroundColor(musicPlayer.currentSong?.isFavorite == true ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                }
                
                Button(action: {
                    musicPlayer.togglePlayPause()
                }) {
                    Image(systemName: musicPlayer.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 35, height: 35)
                        .background(MusicConstants.primaryColor)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(MusicConstants.darkBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingExpandedPlayer = true
            }
        }
    }
}

// MARK: - 全屏播放器视图
struct ExpandedPlayerView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @StateObject private var lyricsManager = LyricsManager.shared
    @Binding var isPresented: Bool
    @State private var isDraggingProgress = false
    @State private var tempProgress: Double = 0
    @State private var selectedTab: PlayerTab = .artwork
    
    enum PlayerTab: String, CaseIterable {
        case artwork = "专辑封面"
        case lyrics = "歌词"
        
        var iconName: String {
            switch self {
            case .artwork: return "music.note"
            case .lyrics: return "text.quote"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部控制栏
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        lyricsManager.toggleLyricsVisibility()
                    }) {
                        Image(systemName: lyricsManager.hasLyrics(for: musicPlayer.currentSong?.id ?? UUID()) ? "text.quote.fill" : "text.quote")
                            .font(.title2)
                            .foregroundColor(lyricsManager.hasLyrics(for: musicPlayer.currentSong?.id ?? UUID()) ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                            .frame(width: 44, height: 44)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // 标签页切换 - 移到安全区域内
                HStack(spacing: 0) {
                    ForEach(PlayerTab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = tab
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.iconName)
                                    .font(.caption)
                                Text(tab.rawValue)
                                    .font(.caption2)
                            }
                            .foregroundColor(selectedTab == tab ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .background(MusicConstants.grayDark.opacity(0.5))
                .cornerRadius(20)
                .padding(.top, 16)
                
                // 主要内容区域
                TabView(selection: $selectedTab) {
                    // 专辑封面页面
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(minHeight: 20, maxHeight: 40)
                        
                        ZStack {
                            Circle()
                                .fill(MusicConstants.grayDark)
                                .frame(width: min(geometry.size.width * 0.75, 300), height: min(geometry.size.width * 0.75, 300))
                            
                            // 旋转动画
                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundColor(MusicConstants.grayMedium)
                                .rotationEffect(.degrees(musicPlayer.playbackState == .playing ? 360 : 0))
                                .animation(
                                    musicPlayer.playbackState == .playing ?
                                    Animation.linear(duration: 20).repeatForever(autoreverses: false) :
                                    .default,
                                    value: musicPlayer.playbackState
                                )
                            
                            // 中心圆点
                            Circle()
                                .fill(MusicConstants.darkBackground)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: 4)
                                )
                        }
                        
                        // 歌曲信息
                        VStack(spacing: 8) {
                            Text(musicPlayer.currentSong?.title ?? "")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            
                            Text(musicPlayer.currentSong?.artist ?? "")
                                .font(.body)
                                .foregroundColor(MusicConstants.grayMedium)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 20)
                        
                        // 迷你歌词显示
                        MiniLyricsView()
                        
                        Spacer()
                            .frame(minHeight: 20, maxHeight: 30)
                    }
                    .tag(PlayerTab.artwork)
                    
                    // 歌词页面
                    VStack(spacing: 0) {
                        LyricsView()
                        
                        // 歌词控制栏
                        if lyricsManager.currentLyrics != nil {
                            LyricsControlBar()
                        }
                    }
                    .tag(PlayerTab.lyrics)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 播放进度
                VStack(spacing: 16) {
                    // 进度条
                    VStack(spacing: 8) {
                        HStack {
                            Text(musicPlayer.formattedTime(isDraggingProgress ? tempProgress * musicPlayer.duration : musicPlayer.currentTime))
                                .font(.caption)
                                .foregroundColor(MusicConstants.grayMedium)
                            
                            Spacer()
                            
                            Text(musicPlayer.formattedTime(musicPlayer.duration))
                                .font(.caption)
                                .foregroundColor(MusicConstants.grayMedium)
                        }
                        
                        ProgressSlider(
                            value: isDraggingProgress ? $tempProgress : .constant(musicPlayer.progress),
                            onEditingChanged: { editing in
                                isDraggingProgress = editing
                                if !editing {
                                    musicPlayer.seek(to: tempProgress * musicPlayer.duration)
                                }
                            },
                            onValueChanged: { value in
                                tempProgress = value
                            }
                        )
                    }
                    
                    // 播放控制按钮
                    HStack(spacing: 40) {
                        Button(action: {
                            musicPlayer.toggleShuffle()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.title2)
                                .foregroundColor(musicPlayer.isShuffled ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                        }
                        
                        Button(action: {
                            musicPlayer.playPrevious()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            musicPlayer.togglePlayPause()
                        }) {
                            Image(systemName: musicPlayer.playbackState == .playing ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(MusicConstants.primaryColor)
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            musicPlayer.playNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            musicPlayer.toggleRepeatMode()
                        }) {
                            Image(systemName: musicPlayer.repeatMode.iconName)
                                .font(.title2)
                                .foregroundColor(musicPlayer.repeatMode == .off ? MusicConstants.grayMedium : MusicConstants.primaryColor)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                // 底部附加功能
                VStack(spacing: 16) {
                    // 功能按钮
                    HStack(spacing: 40) {
                        Button(action: {
                            musicPlayer.showingQueue = true
                        }) {
                            Image(systemName: "list.bullet")
                                .font(.title2)
                                .foregroundColor(MusicConstants.grayMedium)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: musicPlayer.currentSong?.isFavorite == true ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(musicPlayer.currentSong?.isFavorite == true ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(MusicConstants.grayMedium)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "airplayaudio")
                                .font(.title2)
                                .foregroundColor(MusicConstants.grayMedium)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                                .foregroundColor(MusicConstants.grayMedium)
                        }
                    }
                    
                    // 音量控制
                    HStack(spacing: 16) {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(MusicConstants.grayMedium)
                        
                        VolumeSlider(volume: $musicPlayer.volume)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(MusicConstants.grayMedium)
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 30)
            }
        }
        .background(MusicConstants.darkBackground)
        .ignoresSafeArea(.all, edges: [.bottom])
        .safeAreaInset(edge: .top) {
            // 为顶部安全区域添加透明间距
            Color.clear.frame(height: 0)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 向下滑动超过100点时关闭播放器
                    if value.translation.height > 100 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                }
        )
        .sheet(isPresented: $musicPlayer.showingQueue) {
            PlayQueueView(isPresented: $musicPlayer.showingQueue)
        }
    }
}

// MARK: - 进度滑动条
struct ProgressSlider: View {
    @Binding var value: Double
    let onEditingChanged: (Bool) -> Void
    let onValueChanged: (Double) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 2)
                    .fill(MusicConstants.grayDark)
                    .frame(height: 4)
                
                // 进度轨道
                RoundedRectangle(cornerRadius: 2)
                    .fill(MusicConstants.primaryColor)
                    .frame(width: geometry.size.width * value, height: 4)
                
                // 滑块
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .offset(x: geometry.size.width * value - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { gestureValue in
                                let newValue = min(max(0, gestureValue.location.x / geometry.size.width), 1)
                                onValueChanged(newValue)
                            }
                            .onEnded { _ in
                                onEditingChanged(false)
                            }
                    )
                    .onTapGesture { /* 防止点击传递 */ }
            }
        }
        .frame(height: 16)
        .contentShape(Rectangle())
        .onTapGesture { location in
            #if os(iOS)
            let screenWidth = UIScreen.main.bounds.width
            #else
            let screenWidth = NSScreen.main?.frame.width ?? 800
            #endif
            let newValue = location.x / screenWidth
            onValueChanged(min(max(0, newValue), 1))
            onEditingChanged(false)
        }
    }
}

// MARK: - 音量滑动条
struct VolumeSlider: View {
    @Binding var volume: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 2)
                    .fill(MusicConstants.grayDark)
                    .frame(height: 4)
                
                // 音量轨道
                RoundedRectangle(cornerRadius: 2)
                    .fill(MusicConstants.grayMedium)
                    .frame(width: geometry.size.width * CGFloat(volume), height: 4)
                
                // 滑块
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .offset(x: geometry.size.width * CGFloat(volume) - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { gestureValue in
                                let newValue = min(max(0, Float(gestureValue.location.x / geometry.size.width)), 1)
                                volume = newValue
                                MusicPlayerManager.shared.setVolume(newValue)
                            }
                    )
            }
        }
        .frame(height: 16)
        .contentShape(Rectangle())
        .onTapGesture { location in
            #if os(iOS)
            let screenWidth = UIScreen.main.bounds.width
            #else
            let screenWidth = NSScreen.main?.frame.width ?? 800
            #endif
            let newValue = min(max(0, Float(location.x / screenWidth)), 1)
            volume = newValue
            MusicPlayerManager.shared.setVolume(newValue)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            MiniPlayerView(showingExpandedPlayer: .constant(false))
        }
    }
    .onAppear {
        let player = MusicPlayerManager.shared
        // 创建一个示例歌曲用于预览
        let previewSong = Song(
            title: "预览歌曲",
            artist: "预览艺术家",
            album: "预览专辑",
            duration: 180,
            albumArtwork: "default_album",
            fileName: "preview.mp3"
        )
        player.currentSong = previewSong
        player.playbackState = .playing
    }
} 