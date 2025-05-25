import SwiftUI

// MARK: - 播放队列视图
struct PlayQueueView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 当前播放歌曲
                if let currentSong = musicPlayer.currentSong {
                    CurrentPlayingSection(song: currentSong)
                }
                
                // 播放队列
                if musicPlayer.playQueue.isEmpty {
                    EmptyQueueView()
                } else {
                    QueueListView()
                }
            }
            .background(MusicConstants.darkBackground)
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        isPresented = false
                    }
                    .foregroundColor(MusicConstants.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") {
                        musicPlayer.clearQueue()
                    }
                    .foregroundColor(MusicConstants.primaryColor)
                    .disabled(musicPlayer.playQueue.isEmpty)
                }
            }
        }
    }
}

// MARK: - 当前播放部分
struct CurrentPlayingSection: View {
    let song: Song
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // 专辑封面
                RoundedRectangle(cornerRadius: 8)
                    .fill(MusicConstants.grayDark)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(MusicConstants.grayMedium)
                            .font(.title2)
                    )
                
                // 歌曲信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(MusicConstants.grayMedium)
                        .lineLimit(1)
                    
                    Text("正在播放")
                        .font(.caption)
                        .foregroundColor(MusicConstants.primaryColor)
                }
                
                Spacer()
                
                // 播放状态指示器
                Image(systemName: musicPlayer.playbackState == .playing ? "speaker.wave.2.fill" : "speaker.fill")
                    .foregroundColor(MusicConstants.primaryColor)
                    .font(.title2)
            }
            .padding(.horizontal)
            
            Divider()
                .background(MusicConstants.grayDark)
        }
        .padding(.vertical)
    }
}

// MARK: - 空队列视图
struct EmptyQueueView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(MusicConstants.grayMedium)
            
            VStack(spacing: 8) {
                Text("播放队列为空")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("添加歌曲到队列以在此查看")
                    .font(.body)
                    .foregroundColor(MusicConstants.grayMedium)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 队列列表视图
struct QueueListView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        List {
            Section {
                ForEach(musicPlayer.playQueue) { queueItem in
                    QueueItemRow(queueItem: queueItem)
                        .listRowBackground(MusicConstants.darkBackground)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("删除", role: .destructive) {
                                musicPlayer.removeFromQueue(queueItem)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button("下一首播放") {
                                musicPlayer.removeFromQueue(queueItem)
                                musicPlayer.addToQueueNext(queueItem.song, source: queueItem.source)
                            }
                            .tint(MusicConstants.primaryColor)
                        }
                }
                .onMove { source, destination in
                    musicPlayer.moveQueueItem(from: source, to: destination)
                }
            } header: {
                HStack {
                    Text("接下来播放")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(musicPlayer.playQueue.count) 首歌曲")
                        .font(.caption)
                        .foregroundColor(MusicConstants.grayMedium)
                }
                .padding(.horizontal, -16)
                .textCase(nil)
            }
        }
        .listStyle(PlainListStyle())
        .background(MusicConstants.darkBackground)
    }
}

// MARK: - 队列项行视图
struct QueueItemRow: View {
    let queueItem: QueueItem
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 专辑封面
            RoundedRectangle(cornerRadius: 6)
                .fill(MusicConstants.grayDark)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(MusicConstants.grayMedium)
                        .font(.title3)
                )
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 4) {
                Text(queueItem.song.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(queueItem.song.artist)
                        .font(.subheadline)
                        .foregroundColor(MusicConstants.grayMedium)
                        .lineLimit(1)
                    
                    Text("•")
                        .foregroundColor(MusicConstants.grayMedium)
                    
                    Text(queueItem.source.displayName)
                        .font(.caption)
                        .foregroundColor(MusicConstants.primaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(MusicConstants.primaryColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // 播放按钮
            Button(action: {
                musicPlayer.playFromQueue(queueItem)
            }) {
                Image(systemName: "play.fill")
                    .foregroundColor(MusicConstants.primaryColor)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            musicPlayer.playFromQueue(queueItem)
        }
    }
}

// MARK: - 播放历史视图
struct PlayHistoryView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @State private var selectedFilter: HistoryFilter = .recent
    
    enum HistoryFilter: String, CaseIterable {
        case recent = "最近播放"
        case mostPlayed = "最多播放"
        case completed = "播放完成"
        
        var systemImage: String {
            switch self {
            case .recent: return "clock"
            case .mostPlayed: return "chart.bar"
            case .completed: return "checkmark.circle"
            }
        }
    }
    
    var filteredHistory: [PlayHistoryItem] {
        switch selectedFilter {
        case .recent:
            return Array(musicPlayer.playHistory.prefix(50))
        case .mostPlayed:
            let songCounts = Dictionary(grouping: musicPlayer.playHistory) { $0.song.id }
                .mapValues { $0.count }
            return musicPlayer.playHistory
                .sorted { songCounts[$0.song.id] ?? 0 > songCounts[$1.song.id] ?? 0 }
                .prefix(50)
                .map { $0 }
        case .completed:
            return Array(musicPlayer.playHistory.filter { $0.isCompleted }.prefix(50))
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 筛选器
                FilterSegmentedControl(selectedFilter: $selectedFilter)
                
                // 历史列表
                if filteredHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    HistoryListView(historyItems: filteredHistory)
                }
            }
            .background(MusicConstants.darkBackground)
            .navigationTitle("播放历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("清空历史记录", role: .destructive) {
                            musicPlayer.clearPlayHistory()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(MusicConstants.primaryColor)
                    }
                }
            }
        }
    }
}

// MARK: - 筛选器分段控制
struct FilterSegmentedControl: View {
    @Binding var selectedFilter: PlayHistoryView.HistoryFilter
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PlayHistoryView.HistoryFilter.allCases, id: \.self) { filter in
                Button(action: {
                    selectedFilter = filter
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: filter.systemImage)
                            .font(.caption)
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedFilter == filter ? .white : MusicConstants.grayMedium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        selectedFilter == filter ? 
                        MusicConstants.primaryColor : 
                        Color.clear
                    )
                    .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(MusicConstants.grayDark.opacity(0.3))
    }
}

// MARK: - 空历史视图
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(MusicConstants.grayMedium)
            
            VStack(spacing: 8) {
                Text("暂无播放历史")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("开始播放音乐后会在此显示历史记录")
                    .font(.body)
                    .foregroundColor(MusicConstants.grayMedium)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 历史列表视图
struct HistoryListView: View {
    let historyItems: [PlayHistoryItem]
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    
    var body: some View {
        List(historyItems) { historyItem in
            HistoryItemRow(historyItem: historyItem)
                .listRowBackground(MusicConstants.darkBackground)
                .onTapGesture {
                    musicPlayer.playSong(historyItem.song, from: [historyItem.song])
                }
        }
        .listStyle(PlainListStyle())
        .background(MusicConstants.darkBackground)
    }
}

// MARK: - 历史项行视图
struct HistoryItemRow: View {
    let historyItem: PlayHistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 专辑封面
            RoundedRectangle(cornerRadius: 6)
                .fill(MusicConstants.grayDark)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(MusicConstants.grayMedium)
                        .font(.title3)
                )
            
            // 歌曲信息
            VStack(alignment: .leading, spacing: 4) {
                Text(historyItem.song.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(historyItem.song.artist)
                    .font(.subheadline)
                    .foregroundColor(MusicConstants.grayMedium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(historyItem.formattedPlayedAt)
                        .font(.caption)
                        .foregroundColor(MusicConstants.grayMedium)
                    
                    if historyItem.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    Text("\(Int(historyItem.completionPercentage * 100))%")
                        .font(.caption)
                        .foregroundColor(MusicConstants.primaryColor)
                }
            }
            
            Spacer()
            
            // 播放时长
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(historyItem.playDuration))
                    .font(.caption)
                    .foregroundColor(MusicConstants.grayMedium)
                
                // 完成度进度条
                ProgressView(value: historyItem.completionPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: MusicConstants.primaryColor))
                    .frame(width: 40)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    PlayQueueView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
} 