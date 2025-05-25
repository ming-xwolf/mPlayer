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

// MARK: - 常量定义
struct MusicConstants {
    static let primaryColor = Color(red: 1.0, green: 0.176, blue: 0.333) // #FF2D55
    static let secondaryColor = Color(red: 0.0, green: 0.478, blue: 1.0) // #007AFF
    static let darkBackground = Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
    static let grayDark = Color(red: 0.227, green: 0.227, blue: 0.235) // #3A3A3C
    static let grayMedium = Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93
    static let grayLight = Color(red: 0.78, green: 0.78, blue: 0.8) // #C7C7CC
    

} 
