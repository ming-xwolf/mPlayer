import Foundation
import SwiftUI

// MARK: - 歌曲模型
struct Song: Identifiable, Codable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let albumArtwork: String
    let fileName: String
    var isFavorite: Bool
    
    init(id: UUID = UUID(), title: String, artist: String, album: String, duration: TimeInterval, albumArtwork: String, fileName: String, isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.albumArtwork = albumArtwork
        self.fileName = fileName
        self.isFavorite = isFavorite
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 专辑模型
struct Album: Identifiable, Codable {
    let id: UUID
    let title: String
    let artist: String
    let artwork: String
    let songs: [Song]
    
    init(id: UUID = UUID(), title: String, artist: String, artwork: String, songs: [Song]) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.songs = songs
    }
    
    var songCount: Int {
        songs.count
    }
}

// MARK: - 艺术家模型
struct Artist: Identifiable, Codable {
    let id: UUID
    let name: String
    let artwork: String
    let albums: [Album]
    
    init(id: UUID = UUID(), name: String, artwork: String, albums: [Album]) {
        self.id = id
        self.name = name
        self.artwork = artwork
        self.albums = albums
    }
    
    var songCount: Int {
        albums.reduce(0) { $0 + $1.songCount }
    }
}


// MARK: - 播放列表模型
struct Playlist: Identifiable, Codable {
    let id: UUID
    var title: String
    var songs: [Song]
    let createdDate: Date
    var artwork: String?
    
    init(id: UUID = UUID(), title: String, songs: [Song], createdDate: Date, artwork: String? = nil) {
        self.id = id
        self.title = title
        self.songs = songs
        self.createdDate = createdDate
        self.artwork = artwork
    }
    
    var duration: TimeInterval {
        songs.reduce(0) { $0 + $1.duration }
    }
    
    var formattedDuration: String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - 播放状态枚举
enum PlaybackState {
    case stopped
    case playing
    case paused
}

// MARK: - 播放模式枚举
enum RepeatMode: CaseIterable {
    case off
    case all
    case one
    
    var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    var description: String {
        switch self {
        case .off: return "不循环"
        case .all: return "列表循环"
        case .one: return "单曲循环"
        }
    }
}

// MARK: - 播放历史记录模型
struct PlayHistoryItem: Identifiable, Codable {
    let id: UUID
    let song: Song
    let playedAt: Date
    let playDuration: TimeInterval // 实际播放时长
    let completionPercentage: Double // 播放完成百分比
    
    init(id: UUID = UUID(), song: Song, playedAt: Date = Date(), playDuration: TimeInterval, completionPercentage: Double) {
        self.id = id
        self.song = song
        self.playedAt = playedAt
        self.playDuration = playDuration
        self.completionPercentage = completionPercentage
    }
    
    var formattedPlayedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: playedAt)
    }
    
    var isCompleted: Bool {
        completionPercentage >= 0.8 // 播放超过80%算作完成
    }
}

// MARK: - 播放队列项模型
struct QueueItem: Identifiable, Codable {
    let id: UUID
    let song: Song
    let addedAt: Date
    let source: QueueSource // 来源（用户添加、自动添加等）
    
    init(id: UUID = UUID(), song: Song, addedAt: Date = Date(), source: QueueSource = .user) {
        self.id = id
        self.song = song
        self.addedAt = addedAt
        self.source = source
    }
}

// MARK: - 队列来源枚举
enum QueueSource: String, Codable, CaseIterable {
    case user = "user"           // 用户手动添加
    case playlist = "playlist"   // 来自播放列表
    case album = "album"         // 来自专辑
    case artist = "artist"       // 来自艺术家
    case shuffle = "shuffle"     // 随机播放添加
    case recommendation = "recommendation" // 推荐添加
    
    var displayName: String {
        switch self {
        case .user: return "手动添加"
        case .playlist: return "播放列表"
        case .album: return "专辑"
        case .artist: return "艺术家"
        case .shuffle: return "随机播放"
        case .recommendation: return "推荐"
        }
    }
}

// MARK: - 常量定义
struct MusicConstants {
    static let primaryColor = Color(red: 1.0, green: 0.176, blue: 0.333) // #FF2D55
    static let secondaryColor = Color(red: 0.0, green: 0.478, blue: 1.0) // #007AFF
    static let darkBackground = Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
    static let grayDark = Color(red: 0.227, green: 0.227, blue: 0.235) // #3A3A3C
    static let grayMedium = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93
    static let grayLight = Color(red: 0.78, green: 0.78, blue: 0.8) // #C7C7CC
}

// MARK: - 歌词相关模型

// 歌词行模型
struct LyricLine: Identifiable, Codable {
    let id: UUID
    let timeStamp: TimeInterval // 时间戳（秒）
    let text: String // 歌词文本
    let translation: String? // 翻译（可选）
    
    init(id: UUID = UUID(), timeStamp: TimeInterval, text: String, translation: String? = nil) {
        self.id = id
        self.timeStamp = timeStamp
        self.text = text
        self.translation = translation
    }
    
    // 格式化时间戳为 mm:ss.xx 格式
    var formattedTime: String {
        let minutes = Int(timeStamp) / 60
        let seconds = Int(timeStamp) % 60
        let milliseconds = Int((timeStamp.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

// 歌词文件模型
struct Lyrics: Identifiable, Codable {
    let id: UUID
    let songId: UUID // 关联的歌曲ID
    let title: String? // 歌曲标题
    let artist: String? // 艺术家
    let album: String? // 专辑
    let lines: [LyricLine] // 歌词行数组
    let hasTranslation: Bool // 是否有翻译
    let source: LyricsSource // 歌词来源
    
    init(id: UUID = UUID(), songId: UUID, title: String? = nil, artist: String? = nil, album: String? = nil, lines: [LyricLine], hasTranslation: Bool = false, source: LyricsSource = .local) {
        self.id = id
        self.songId = songId
        self.title = title
        self.artist = artist
        self.album = album
        self.lines = lines.sorted { $0.timeStamp < $1.timeStamp } // 按时间排序
        self.hasTranslation = hasTranslation
        self.source = source
    }
    
    // 获取指定时间的当前歌词行
    func getCurrentLine(at currentTime: TimeInterval) -> LyricLine? {
        // 找到当前时间应该显示的歌词行
        var currentLine: LyricLine?
        for line in lines {
            if line.timeStamp <= currentTime {
                currentLine = line
            } else {
                break
            }
        }
        return currentLine
    }
    
    // 获取指定时间的当前歌词行索引
    func getCurrentLineIndex(at currentTime: TimeInterval) -> Int? {
        for (index, line) in lines.enumerated() {
            if index == lines.count - 1 {
                // 最后一行
                if line.timeStamp <= currentTime {
                    return index
                }
            } else {
                // 检查当前行和下一行的时间
                let nextLine = lines[index + 1]
                if line.timeStamp <= currentTime && currentTime < nextLine.timeStamp {
                    return index
                }
            }
        }
        return nil
    }
    
    // 获取下一行歌词
    func getNextLine(after currentTime: TimeInterval) -> LyricLine? {
        return lines.first { $0.timeStamp > currentTime }
    }
}

// 歌词来源枚举
enum LyricsSource: String, Codable, CaseIterable {
    case local = "local"         // 本地文件
    case embedded = "embedded"   // 音频文件内嵌
    case online = "online"       // 在线获取
    case manual = "manual"       // 手动输入
    
    var displayName: String {
        switch self {
        case .local: return "本地文件"
        case .embedded: return "内嵌歌词"
        case .online: return "在线歌词"
        case .manual: return "手动输入"
        }
    }
}

// 歌词显示模式枚举
enum LyricsDisplayMode: String, CaseIterable {
    case scroll = "scroll"       // 滚动模式
    case karaoke = "karaoke"     // 卡拉OK模式
    case `static` = "static"     // 静态模式
    
    var displayName: String {
        switch self {
        case .scroll: return "滚动显示"
        case .karaoke: return "卡拉OK"
        case .static: return "静态显示"
        }
    }
    
    var iconName: String {
        switch self {
        case .scroll: return "text.alignleft"
        case .karaoke: return "music.mic"
        case .static: return "text.justify"
        }
    }
} 
