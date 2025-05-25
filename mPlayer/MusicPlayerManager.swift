import Foundation
import AVFoundation
import AudioToolbox
import Combine

// MARK: - 音乐播放器管理器
class MusicPlayerManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentSong: Song?
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.7
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .off
    @Published var playlist: [Song] = []
    @Published var currentIndex: Int = 0
    
    // MARK: - 播放队列和历史
    @Published var playQueue: [QueueItem] = [] // 播放队列
    @Published var playHistory: [PlayHistoryItem] = [] // 播放历史
    @Published var showingQueue = false // 是否显示队列界面
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var originalPlaylist: [Song] = [] // 保存原始播放列表
    private var shuffledIndices: [Int] = [] // 随机播放的索引序列
    private var shuffleIndex: Int = 0 // 当前在随机序列中的位置
    private var currentPlayStartTime: Date? // 当前歌曲开始播放的时间
    private var totalPlayTime: TimeInterval = 0 // 当前歌曲累计播放时间
    
    // MARK: - Singleton
    static let shared = MusicPlayerManager()
    
    override init() {
        super.init()
        setupAudioSession()
        loadPlayHistory()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
        #endif
    }
    
    // MARK: - 播放控制
    func play() {
        if let player = audioPlayer {
            player.play()
            playbackState = .playing
            startTimer()
            recordPlayStart()
            print("▶️ 播放音频")
        } else {
            // 如果没有音频播放器，使用模拟播放
            playbackState = .playing
            startTimer()
            recordPlayStart()
            print("▶️ 模拟播放")
        }
    }
    
    func pause() {
        if let player = audioPlayer {
            player.pause()
            playbackState = .paused
            stopTimer()
            recordPlayPause()
            print("⏸️ 暂停音频")
        } else {
            playbackState = .paused
            stopTimer()
            recordPlayPause()
            print("⏸️ 模拟暂停")
        }
    }
    
    func stop() {
        if let player = audioPlayer {
            player.stop()
            player.currentTime = 0
            playbackState = .stopped
            currentTime = 0
            stopTimer()
            print("⏹️ 停止音频")
        } else {
            playbackState = .stopped
            currentTime = 0
            stopTimer()
            print("⏹️ 模拟停止")
        }
    }
    
    func togglePlayPause() {
        switch playbackState {
        case .playing:
            pause()
        case .paused, .stopped:
            play()
        }
    }
    
    // MARK: - 歌曲播放
    func playSong(_ song: Song, from playlist: [Song] = []) {
        currentSong = song
        
        if !playlist.isEmpty {
            self.playlist = playlist
            self.originalPlaylist = playlist // 保存原始播放列表
            
            if let index = playlist.firstIndex(where: { $0.id == song.id }) {
                currentIndex = index
                
                // 如果开启了随机播放，重新生成随机序列
                if isShuffled {
                    generateShuffleSequence(startingWith: index)
                }
            }
        }
        
        // 尝试加载真实的音频文件，如果失败则使用演示音频
        loadAudio(for: song)
    }
    
    // 加载音频文件
    private func loadAudio(for song: Song) {
        // 停止当前播放
        stop()
        
        // 首先尝试从扫描的音频文件中加载（如果有真实文件路径）
        if let realAudioURL = tryLoadRealAudioFile(for: song) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: realAudioURL)
                audioPlayer?.delegate = self
                audioPlayer?.volume = volume
                audioPlayer?.prepareToPlay()
                
                duration = audioPlayer?.duration ?? song.duration
                currentTime = 0
                playbackState = .playing
                audioPlayer?.play()
                startTimer()
                
                print("✅ 成功加载真实音频文件: \(song.title)")
                return
            } catch {
                print("❌ 真实音频文件加载失败: \(error)")
            }
        }
        
        // 如果没有找到真实音频文件，使用模拟播放
        print("ℹ️ 未找到音频文件，使用模拟播放")
        simulateAudioLoading(for: song)
    }
    
    // 尝试加载真实的音频文件
    private func tryLoadRealAudioFile(for song: Song) -> URL? {
        // 检查Documents目录中是否有匹配的音频文件
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let formats = ["aiff", "mp3", "wav", "m4a", "flac"]
        
        // 首先尝试完全匹配文件名
        for format in formats {
            let exactURL = documentsPath.appendingPathComponent(song.fileName)
            if FileManager.default.fileExists(atPath: exactURL.path) {
                print("✅ 找到匹配的音频文件: \(song.fileName)")
                return exactURL
            }
        }
        
        // 然后尝试匹配歌曲标题
        for format in formats {
            let titleURL = documentsPath.appendingPathComponent("\(song.title).\(format)")
            if FileManager.default.fileExists(atPath: titleURL.path) {
                print("✅ 找到标题匹配的音频文件: \(song.title).\(format)")
                return titleURL
            }
        }
        
        return nil
    }
    
    // 获取音频文件URL
    private func getAudioURL(for fileName: String) -> URL? {
        // 尝试从Documents目录加载用户添加的音频文件
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: audioURL.path) {
            print("✅ 找到音频文件: \(fileName)")
            return audioURL
        }
        
        print("❌ 未找到音频文件: \(fileName)")
        return nil
    }
    
    
    
    // 模拟音频文件加载（作为备用方案）
    private func simulateAudioLoading(for song: Song) {
        duration = song.duration
        currentTime = 0
        playbackState = .playing
        startTimer()
        print("🎵 使用模拟播放模式")
    }
    
    // MARK: - 播放列表控制
    func playNext() {
        guard !playlist.isEmpty else { return }
        
        if repeatMode == .one {
            // 单曲循环，重新播放当前歌曲
            seek(to: 0)
            play()
            return
        }
        
        if isShuffled {
            // 随机播放模式
            playNextShuffled()
        } else {
            // 顺序播放模式
            playNextSequential()
        }
    }
    
    func playPrevious() {
        guard !playlist.isEmpty else { return }
        
        if currentTime > 3.0 {
            // 如果已播放超过3秒，重新播放当前歌曲
            seek(to: 0)
            return
        }
        
        if isShuffled {
            // 随机播放模式
            playPreviousShuffled()
        } else {
            // 顺序播放模式
            playPreviousSequential()
        }
    }
    
    // MARK: - 顺序播放控制
    private func playNextSequential() {
        switch repeatMode {
        case .all:
            // 列表循环
            currentIndex = (currentIndex + 1) % playlist.count
            playSong(playlist[currentIndex], from: playlist)
        case .off:
            // 不循环
            if currentIndex < playlist.count - 1 {
                currentIndex += 1
                playSong(playlist[currentIndex], from: playlist)
            } else {
                stop()
            }
        case .one:
            // 这种情况在上面已经处理
            break
        }
    }
    
    private func playPreviousSequential() {
        currentIndex = currentIndex > 0 ? currentIndex - 1 : playlist.count - 1
        playSong(playlist[currentIndex], from: playlist)
    }
    
    // MARK: - 随机播放控制
    private func playNextShuffled() {
        guard !shuffledIndices.isEmpty else {
            generateShuffleSequence()
            return
        }
        
        switch repeatMode {
        case .all:
            // 列表循环 - 移动到下一个随机索引
            shuffleIndex = (shuffleIndex + 1) % shuffledIndices.count
            currentIndex = shuffledIndices[shuffleIndex]
            playSong(playlist[currentIndex], from: playlist)
        case .off:
            // 不循环 - 如果还有下一首就播放，否则停止
            if shuffleIndex < shuffledIndices.count - 1 {
                shuffleIndex += 1
                currentIndex = shuffledIndices[shuffleIndex]
                playSong(playlist[currentIndex], from: playlist)
            } else {
                stop()
            }
        case .one:
            // 这种情况在上面已经处理
            break
        }
    }
    
    private func playPreviousShuffled() {
        guard !shuffledIndices.isEmpty else {
            generateShuffleSequence()
            return
        }
        
        // 移动到上一个随机索引
        shuffleIndex = shuffleIndex > 0 ? shuffleIndex - 1 : shuffledIndices.count - 1
        currentIndex = shuffledIndices[shuffleIndex]
        playSong(playlist[currentIndex], from: playlist)
    }
    
    // MARK: - 播放位置控制
    func seek(to time: TimeInterval) {
        currentTime = time
        if let player = audioPlayer {
            player.currentTime = time
            print("🎯 定位到: \(formattedTime(time))")
        } else {
            print("🎯 模拟定位到: \(formattedTime(time))")
        }
    }
    
    func setVolume(_ volume: Float) {
        self.volume = volume
        audioPlayer?.volume = volume
    }
    
    // MARK: - 播放模式控制
    func toggleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }
    
    func toggleShuffle() {
        isShuffled.toggle()
        
        if isShuffled {
            // 开启随机播放 - 生成随机序列
            generateShuffleSequence(startingWith: currentIndex)
            print("🔀 开启随机播放")
        } else {
            // 关闭随机播放 - 清除随机序列
            shuffledIndices.removeAll()
            shuffleIndex = 0
            print("📋 关闭随机播放，恢复顺序播放")
        }
    }
    
    // MARK: - 随机播放序列管理
    private func generateShuffleSequence(startingWith currentIdx: Int? = nil) {
        guard !playlist.isEmpty else { return }
        
        // 生成所有索引
        shuffledIndices = Array(0..<playlist.count)
        
        // 随机打乱
        shuffledIndices.shuffle()
        
        // 如果指定了当前歌曲索引，确保它在序列的第一位
        if let currentIdx = currentIdx,
           let shuffledPosition = shuffledIndices.firstIndex(of: currentIdx) {
            shuffledIndices.swapAt(0, shuffledPosition)
            shuffleIndex = 0
        } else {
            shuffleIndex = 0
        }
        
        print("🔀 生成随机播放序列: \(shuffledIndices.prefix(5))...")
    }
    
    // 获取下一首歌曲（用于预览，不改变播放状态）
    func getNextSong() -> Song? {
        guard !playlist.isEmpty else { return nil }
        
        if repeatMode == .one {
            return currentSong
        }
        
        if isShuffled {
            guard !shuffledIndices.isEmpty else { return nil }
            let nextShuffleIndex = (shuffleIndex + 1) % shuffledIndices.count
            let nextIndex = shuffledIndices[nextShuffleIndex]
            return playlist[nextIndex]
        } else {
            let nextIndex = (currentIndex + 1) % playlist.count
            return playlist[nextIndex]
        }
    }
    
    // 获取上一首歌曲（用于预览，不改变播放状态）
    func getPreviousSong() -> Song? {
        guard !playlist.isEmpty else { return nil }
        
        if isShuffled {
            guard !shuffledIndices.isEmpty else { return nil }
            let prevShuffleIndex = shuffleIndex > 0 ? shuffleIndex - 1 : shuffledIndices.count - 1
            let prevIndex = shuffledIndices[prevShuffleIndex]
            return playlist[prevIndex]
        } else {
            let prevIndex = currentIndex > 0 ? currentIndex - 1 : playlist.count - 1
            return playlist[prevIndex]
        }
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateProgress() {
        guard playbackState == .playing else { return }
        
        if let player = audioPlayer {
            // 使用真实播放器的时间
            currentTime = player.currentTime
            
            // 检查是否播放完成
            if !player.isPlaying && currentTime >= duration - 0.1 {
                currentTime = duration
                playbackState = .stopped
                stopTimer()
                
                // 记录播放完成
                recordPlayCompletion()
                
                // 自动播放下一首
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.playNextWithQueue()
                }
            }
        } else {
            // 模拟播放进度
            currentTime += 0.1
            
            // 检查是否播放完成
            if currentTime >= duration {
                currentTime = duration
                playbackState = .stopped
                stopTimer()
                
                // 记录播放完成
                recordPlayCompletion()
                
                // 自动播放下一首
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.playNextWithQueue()
                }
            }
        }
    }
    
    // MARK: - 播放进度百分比
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    // MARK: - 格式化时间
    func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    deinit {
        stopTimer()
        savePlayHistory()
    }
    
    // MARK: - 播放队列管理
    func addToQueue(_ song: Song, source: QueueSource = .user) {
        let queueItem = QueueItem(song: song, source: source)
        playQueue.append(queueItem)
        print("➕ 添加到播放队列: \(song.title)")
    }
    
    func addToQueueNext(_ song: Song, source: QueueSource = .user) {
        let queueItem = QueueItem(song: song, source: source)
        playQueue.insert(queueItem, at: 0)
        print("⏭️ 添加到队列下一首: \(song.title)")
    }
    
    func removeFromQueue(_ queueItem: QueueItem) {
        playQueue.removeAll { $0.id == queueItem.id }
        print("➖ 从播放队列移除: \(queueItem.song.title)")
    }
    
    func clearQueue() {
        playQueue.removeAll()
        print("🗑️ 清空播放队列")
    }
    
    func moveQueueItem(from source: IndexSet, to destination: Int) {
        playQueue.move(fromOffsets: source, toOffset: destination)
        print("🔄 调整播放队列顺序")
    }
    
    func playFromQueue(_ queueItem: QueueItem) {
        // 播放队列中的歌曲
        playSong(queueItem.song, from: [queueItem.song])
        // 从队列中移除已播放的歌曲
        removeFromQueue(queueItem)
    }
    
    func playNextFromQueue() {
        guard let nextItem = playQueue.first else {
            // 队列为空，继续正常的下一首逻辑
            playNext()
            return
        }
        
        // 播放队列中的下一首
        playFromQueue(nextItem)
    }
    
    // MARK: - 播放历史管理
    private func loadPlayHistory() {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: "PlayHistory"),
           let history = try? JSONDecoder().decode([PlayHistoryItem].self, from: data) {
            playHistory = history
            print("✅ 加载播放历史: \(history.count) 条记录")
        } else {
            playHistory = []
            print("ℹ️ 未找到播放历史数据")
        }
    }
    
    private func savePlayHistory() {
        let userDefaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(playHistory) {
            userDefaults.set(encoded, forKey: "PlayHistory")
            print("✅ 保存播放历史: \(playHistory.count) 条记录")
        } else {
            print("❌ 播放历史保存失败")
        }
    }
    
    private func recordPlayStart() {
        currentPlayStartTime = Date()
        totalPlayTime = 0
    }
    
    private func recordPlayPause() {
        guard let startTime = currentPlayStartTime else { return }
        let sessionTime = Date().timeIntervalSince(startTime)
        totalPlayTime += sessionTime
        currentPlayStartTime = nil
    }
    
    private func recordPlayCompletion() {
        guard let song = currentSong else { return }
        
        // 如果正在播放，先记录当前会话时间
        if let startTime = currentPlayStartTime {
            let sessionTime = Date().timeIntervalSince(startTime)
            totalPlayTime += sessionTime
        }
        
        let completionPercentage = duration > 0 ? totalPlayTime / duration : 0
        
        let historyItem = PlayHistoryItem(
            song: song,
            playDuration: totalPlayTime,
            completionPercentage: min(completionPercentage, 1.0)
        )
        
        // 添加到历史记录
        playHistory.insert(historyItem, at: 0)
        
        // 限制历史记录数量（保留最近1000条）
        if playHistory.count > 1000 {
            playHistory = Array(playHistory.prefix(1000))
        }
        
        // 保存历史记录
        savePlayHistory()
        
        // 重置计时器
        currentPlayStartTime = nil
        totalPlayTime = 0
        
        print("📊 记录播放历史: \(song.title) - 播放时长: \(Int(totalPlayTime))秒, 完成度: \(Int(completionPercentage * 100))%")
    }
    
    func getRecentlyPlayed(limit: Int = 20) -> [Song] {
        return Array(playHistory.prefix(limit).map { $0.song })
    }
    
    func getMostPlayed(limit: Int = 20) -> [Song] {
        // 统计每首歌的播放次数
        let songPlayCounts = Dictionary(grouping: playHistory) { $0.song.id }
            .mapValues { $0.count }
        
        // 按播放次数排序
        let sortedSongs = songPlayCounts.sorted { $0.value > $1.value }
        
        // 获取对应的歌曲对象
        let mostPlayedSongs = sortedSongs.prefix(limit).compactMap { (songId, _) in
            playHistory.first { $0.song.id == songId }?.song
        }
        
        return mostPlayedSongs
    }
    
    func clearPlayHistory() {
        playHistory.removeAll()
        savePlayHistory()
        print("🗑️ 清空播放历史")
    }
    
    // MARK: - 队列相关的播放逻辑修改
    private func playNextWithQueue() {
        // 优先播放队列中的歌曲
        if !playQueue.isEmpty {
            playNextFromQueue()
        } else {
            // 队列为空，使用原有逻辑
            playNext()
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension MusicPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playNext()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("音频播放错误: \(error?.localizedDescription ?? "未知错误")")
        playbackState = .stopped
        stopTimer()
    }
} 