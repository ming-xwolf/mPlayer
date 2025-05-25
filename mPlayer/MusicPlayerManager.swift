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
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    // MARK: - Singleton
    static let shared = MusicPlayerManager()
    
    override init() {
        super.init()
        setupAudioSession()
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
            print("▶️ 播放音频")
        } else {
            // 如果没有音频播放器，使用模拟播放
            playbackState = .playing
            startTimer()
            print("▶️ 模拟播放")
        }
    }
    
    func pause() {
        if let player = audioPlayer {
            player.pause()
            playbackState = .paused
            stopTimer()
            print("⏸️ 暂停音频")
        } else {
            playbackState = .paused
            stopTimer()
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
            if let index = playlist.firstIndex(where: { $0.id == song.id }) {
                currentIndex = index
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
        
        switch repeatMode {
        case .one:
            // 单曲循环，重新播放当前歌曲
            seek(to: 0)
            play()
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
        }
    }
    
    func playPrevious() {
        guard !playlist.isEmpty else { return }
        
        if currentTime > 3.0 {
            // 如果已播放超过3秒，重新播放当前歌曲
            seek(to: 0)
        } else {
            // 播放上一首
            currentIndex = currentIndex > 0 ? currentIndex - 1 : playlist.count - 1
            playSong(playlist[currentIndex], from: playlist)
        }
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
            shufflePlaylist()
        }
    }
    
    private func shufflePlaylist() {
        guard let currentSong = currentSong else { return }
        playlist.shuffle()
        if let newIndex = playlist.firstIndex(where: { $0.id == currentSong.id }) {
            currentIndex = newIndex
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
                
                // 自动播放下一首
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.playNext()
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
                
                // 自动播放下一首
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.playNext()
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