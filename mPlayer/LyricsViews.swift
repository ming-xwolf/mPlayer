import SwiftUI

// MARK: - 歌词显示视图
struct LyricsView: View {
    @StateObject private var lyricsManager = LyricsManager.shared
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if let lyrics = lyricsManager.currentLyrics {
                // 歌词内容
                switch lyricsManager.displayMode {
                case .scroll:
                    ScrollingLyricsView(lyrics: lyrics)
                case .karaoke:
                    KaraokeLyricsView(lyrics: lyrics)
                case .static:
                    StaticLyricsView(lyrics: lyrics)
                }
            } else {
                // 无歌词状态
                NoLyricsView()
            }
        }
        .background(MusicConstants.darkBackground.opacity(0.95))
        .onReceive(musicPlayer.$currentTime) { currentTime in
            lyricsManager.updateCurrentLyrics(currentTime: currentTime)
        }
        .onReceive(musicPlayer.$currentSong) { song in
            if let song = song {
                lyricsManager.loadLyrics(for: song)
            } else {
                lyricsManager.clearCurrentLyrics()
            }
        }
    }
}

// MARK: - 滚动歌词视图
struct ScrollingLyricsView: View {
    let lyrics: Lyrics
    @StateObject private var lyricsManager = LyricsManager.shared
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 顶部间距
                    Spacer()
                        .frame(height: 100)
                    
                    ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                        LyricLineView(
                            line: line,
                            isCurrentLine: lyricsManager.currentLineIndex == index,
                            showTranslation: lyricsManager.showTranslation
                        )
                        .id(line.id)
                        .onTapGesture {
                            // 点击歌词行跳转到对应时间
                            musicPlayer.seek(to: line.timeStamp)
                        }
                    }
                    
                    // 底部间距
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: lyricsManager.currentLineIndex) { newIndex in
                if let index = newIndex, index < lyrics.lines.count {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(lyrics.lines[index].id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - 卡拉OK歌词视图
struct KaraokeLyricsView: View {
    let lyrics: Lyrics
    @StateObject private var lyricsManager = LyricsManager.shared
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 当前歌词行
            if let currentLine = lyricsManager.currentLine {
                VStack(spacing: 12) {
                    Text(currentLine.text)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .scaleEffect(1.1)
                        .animation(.easeInOut(duration: 0.3), value: currentLine.id)
                    
                    if lyricsManager.showTranslation, let translation = currentLine.translation {
                        Text(translation)
                            .font(.body)
                            .foregroundColor(MusicConstants.grayMedium)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            } else {
                Text("♪ 音乐播放中 ♪")
                    .font(.title2)
                    .foregroundColor(MusicConstants.grayMedium)
            }
            
            Spacer()
            
            // 下一行预览
            if let nextLine = lyrics.getNextLine(after: musicPlayer.currentTime) {
                VStack(spacing: 8) {
                    Text("即将播放")
                        .font(.caption)
                        .foregroundColor(MusicConstants.grayMedium)
                    
                    Text(nextLine.text)
                        .font(.body)
                        .foregroundColor(MusicConstants.grayLight)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .opacity(0.7)
                }
                .padding(.bottom, 40)
            }
        }
        .padding()
    }
}

// MARK: - 静态歌词视图
struct StaticLyricsView: View {
    let lyrics: Lyrics
    @StateObject private var lyricsManager = LyricsManager.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                    HStack(alignment: .top, spacing: 12) {
                        // 时间戳
                        Text(line.formattedTime)
                            .font(.caption)
                            .foregroundColor(MusicConstants.grayMedium)
                            .frame(width: 60, alignment: .leading)
                        
                        // 歌词文本
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.text)
                                .font(.body)
                                .foregroundColor(lyricsManager.currentLineIndex == index ? MusicConstants.primaryColor : .white)
                                .fontWeight(lyricsManager.currentLineIndex == index ? .semibold : .regular)
                            
                            if lyricsManager.showTranslation, let translation = line.translation {
                                Text(translation)
                                    .font(.caption)
                                    .foregroundColor(MusicConstants.grayMedium)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 20)
        }
    }
}

// MARK: - 歌词行视图
struct LyricLineView: View {
    let line: LyricLine
    let isCurrentLine: Bool
    let showTranslation: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(line.text)
                .font(isCurrentLine ? .title3 : .body)
                .fontWeight(isCurrentLine ? .bold : .medium)
                .foregroundColor(isCurrentLine ? .white : MusicConstants.grayLight)
                .multilineTextAlignment(.center)
                .scaleEffect(isCurrentLine ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isCurrentLine)
            
            if showTranslation, let translation = line.translation {
                Text(translation)
                    .font(.caption)
                    .foregroundColor(isCurrentLine ? MusicConstants.grayLight : MusicConstants.grayMedium)
                    .multilineTextAlignment(.center)
                    .opacity(isCurrentLine ? 1.0 : 0.7)
            }
        }
        .padding(.vertical, 8)
        .background(
            isCurrentLine ?
            MusicConstants.primaryColor.opacity(0.1) :
            Color.clear
        )
        .cornerRadius(8)
    }
}

// MARK: - 无歌词视图
struct NoLyricsView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @StateObject private var lyricsManager = LyricsManager.shared
    @StateObject private var downloadService = LyricsDownloadService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(MusicConstants.grayMedium)
            
            VStack(spacing: 8) {
                Text("暂无歌词")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if let song = musicPlayer.currentSong {
                    Text("正在播放：\(song.title)")
                        .font(.body)
                        .foregroundColor(MusicConstants.grayMedium)
                        .multilineTextAlignment(.center)
                    
                    Text("艺术家：\(song.artist)")
                        .font(.caption)
                        .foregroundColor(MusicConstants.grayMedium)
                        .multilineTextAlignment(.center)
                } else {
                    Text("请选择一首歌曲开始播放")
                        .font(.body)
                        .foregroundColor(MusicConstants.grayMedium)
                        .multilineTextAlignment(.center)
                }
                
                // 显示下载错误信息
                if let error = downloadService.lastError {
                    Text("下载失败：\(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            
            // 下载歌词按钮
            if let song = musicPlayer.currentSong {
                VStack(spacing: 12) {
                    if downloadService.isDownloading {
                        VStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: MusicConstants.primaryColor))
                            
                            Text("正在搜索歌词...")
                                .font(.caption)
                                .foregroundColor(MusicConstants.grayMedium)
                            
                            if downloadService.downloadProgress > 0 {
                                ProgressView(value: downloadService.downloadProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: MusicConstants.primaryColor))
                                    .frame(width: 200)
                            }
                        }
                    } else {
                        Button(action: {
                            lyricsManager.reloadLyrics(for: song, forceOnlineDownload: true)
                        }) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.down")
                                Text("在线搜索歌词")
                            }
                            .font(.body)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(MusicConstants.primaryColor)
                            .cornerRadius(25)
                        }
                        
                        Button(action: {
                            lyricsManager.reloadLyrics(for: song, forceOnlineDownload: false)
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("重新加载本地歌词")
                            }
                            .font(.caption)
                            .foregroundColor(MusicConstants.grayMedium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(MusicConstants.grayDark)
                            .cornerRadius(20)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 歌词控制栏
struct LyricsControlBar: View {
    @StateObject private var lyricsManager = LyricsManager.shared
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @StateObject private var downloadService = LyricsDownloadService.shared
    @State private var showReloadOptions = false
    
    var body: some View {
        HStack(spacing: 20) {
            // 显示模式切换
            Button(action: {
                lyricsManager.toggleDisplayMode()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: lyricsManager.displayMode.iconName)
                        .font(.title3)
                    Text(lyricsManager.displayMode.displayName)
                        .font(.caption2)
                }
                .foregroundColor(MusicConstants.primaryColor)
            }
            
            Spacer()
            
            // 重新加载歌词
            Button(action: {
                showReloadOptions = true
            }) {
                VStack(spacing: 4) {
                    ZStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                        
                        if downloadService.isDownloading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .progressViewStyle(CircularProgressViewStyle(tint: MusicConstants.primaryColor))
                        }
                    }
                    Text("重载")
                        .font(.caption2)
                }
                .foregroundColor(downloadService.isDownloading ? MusicConstants.grayMedium : MusicConstants.primaryColor)
            }
            .disabled(downloadService.isDownloading || musicPlayer.currentSong == nil)
            .actionSheet(isPresented: $showReloadOptions) {
                ActionSheet(
                    title: Text("重新加载歌词"),
                    message: Text("选择加载方式"),
                    buttons: [
                        .default(Text("从本地重新加载")) {
                            if let song = musicPlayer.currentSong {
                                lyricsManager.reloadLyrics(for: song, forceOnlineDownload: false)
                            }
                        },
                        .default(Text("在线下载歌词")) {
                            if let song = musicPlayer.currentSong {
                                lyricsManager.reloadLyrics(for: song, forceOnlineDownload: true)
                            }
                        },
                        .cancel(Text("取消"))
                    ]
                )
            }
            
            Spacer()
            
            // 翻译开关
            if lyricsManager.currentLyrics?.hasTranslation == true {
                Button(action: {
                    lyricsManager.toggleTranslation()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: lyricsManager.showTranslation ? "textformat.abc" : "textformat.abc.dottedunderline")
                            .font(.title3)
                        Text("翻译")
                            .font(.caption2)
                    }
                    .foregroundColor(lyricsManager.showTranslation ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                }
            }
            
            Spacer()
            
            // 歌词设置
            Button(action: {
                // TODO: 打开歌词设置
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                    Text("设置")
                        .font(.caption2)
                }
                .foregroundColor(MusicConstants.grayMedium)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(MusicConstants.grayDark.opacity(0.8))
    }
}

// MARK: - 迷你歌词视图（用于播放器底部）
struct MiniLyricsView: View {
    @StateObject private var lyricsManager = LyricsManager.shared
    
    var body: some View {
        if let currentLine = lyricsManager.currentLine {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(MusicConstants.primaryColor)
                    .font(.caption)
                
                Text(currentLine.text)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.3), value: currentLine.id)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(MusicConstants.darkBackground.opacity(0.9))
        }
    }
} 