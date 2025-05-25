import SwiftUI

// MARK: - 主标签页视图
struct MainTabView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @State private var selectedTab = 0
    @State private var showingExpandedPlayer = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 主内容区域（不包含tab按钮）
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    LibraryView()
                case 2:
                    SearchView()
                case 3:
                    ProfileView()
                default:
                    HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            
            // 迷你播放器（在tab按钮上方）
            if musicPlayer.currentSong != nil {
                MiniPlayerView(showingExpandedPlayer: $showingExpandedPlayer)
                    .background(MusicConstants.darkBackground)
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(MusicConstants.grayDark)
                            .offset(y: -0.25), alignment: .top
                    )
            }
            
            // 自定义Tab按钮栏
            CustomTabBar(selectedTab: $selectedTab)
        }
        .background(MusicConstants.darkBackground)
        .preferredColorScheme(.dark)
        .overlay(
            // 全屏播放器
            Group {
                if showingExpandedPlayer {
                    ExpandedPlayerView(isPresented: $showingExpandedPlayer)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .zIndex(2)
                        .animation(.easeInOut(duration: 0.3), value: showingExpandedPlayer)
                }
            }
        )
    }
}

// MARK: - 自定义Tab按钮栏
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs = [
        (icon: "house", selectedIcon: "house.fill", title: "首页"),
        (icon: "music.note", selectedIcon: "music.note.list", title: "资料库"),
        (icon: "magnifyingglass", selectedIcon: "magnifyingglass", title: "搜索"),
        (icon: "person", selectedIcon: "person.fill", title: "我的")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: selectedTab == index ? tabs[index].selectedIcon : tabs[index].icon)
                            .font(.system(size: 20))
                            .foregroundColor(selectedTab == index ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                        
                        Text(tabs[index].title)
                            .font(.caption2)
                            .foregroundColor(selectedTab == index ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(MusicConstants.darkBackground)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(MusicConstants.grayDark)
                .offset(y: -0.25), alignment: .top
        )
        .padding(.bottom, max(safeAreaInsets.bottom - 24, 0))
    }
    
    private var safeAreaInsets: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return .zero
        }
        return window.safeAreaInsets
    }
}

// MARK: - 首页视图
struct HomeView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @StateObject private var dataManager = MusicDataManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 顶部标题
                    HStack {
                        Text("为你推荐")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "bell")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 热门专辑
                    VStack(alignment: .leading, spacing: 16) {
                        Text("热门专辑")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                            ForEach(dataManager.albums.prefix(4)) { album in
                                AlbumCard(album: album)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 最近播放
                    VStack(alignment: .leading, spacing: 16) {
                        Text("最近播放")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(musicPlayer.getRecentlyPlayed(limit: 5)) { song in
                                SongRowView(song: song)
                                    .onTapGesture {
                                        musicPlayer.playSong(song, from: dataManager.songs)
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 16) // 优化底部间距
            }
            .background(MusicConstants.darkBackground)
        }
    }
}

// MARK: - 专辑卡片
struct AlbumCard: View {
    let album: Album
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MusicConstants.grayDark)
                    .aspectRatio(1, contentMode: .fit)
                
                // 模拟专辑封面
                Image(systemName: "music.note")
                    .font(.system(size: 50))
                    .foregroundColor(MusicConstants.grayMedium)
                
                // 播放按钮覆盖层
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if let firstSong = album.songs.first {
                                musicPlayer.playSong(firstSong, from: album.songs)
                            }
                        }) {
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(MusicConstants.primaryColor)
                                .clipShape(Circle())
                        }
                        .padding(12)
                    }
                }
            }
            
            Text(album.title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(album.artist)
                .font(.caption)
                .foregroundColor(MusicConstants.grayMedium)
                .lineLimit(1)
        }
    }
}

// MARK: - 歌曲行视图
struct SongRowView: View {
    let song: Song
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @StateObject private var dataManager = MusicDataManager.shared
    
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
                Text(song.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(MusicConstants.grayMedium)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 16) {
                Button(action: {
                    dataManager.toggleFavorite(for: song)
                }) {
                    Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(song.isFavorite ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                }
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(MusicConstants.grayMedium)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
        )
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
} 