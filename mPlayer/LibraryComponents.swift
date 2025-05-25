import SwiftUI

// MARK: - 资料库歌曲行
struct LibrarySongRow: View {
    let song: Song
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .foregroundColor(MusicConstants.grayMedium)
                .frame(width: 20)
            
            EnhancedAsyncArtworkView(
                song: song,
                size: .small,
                style: .rounded,
                useThumbnail: true
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Text("\(song.artist) · \(song.album)")
                        .font(.caption)
                        .foregroundColor(MusicConstants.grayMedium)
                        .lineLimit(1)
                    
                    if !AlbumArtworkPersistenceManager.shared.hasArtwork(for: song) {
                        Image(systemName: "photo.badge.plus")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Text(song.formattedDuration)
                    .font(.caption)
                    .foregroundColor(MusicConstants.grayMedium)
                
                Menu {
                    Button(action: {
                        MusicPlayerManager.shared.addToQueue(song, source: .user)
                    }) {
                        Label("添加到队列", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    
                    Button(action: {
                        MusicPlayerManager.shared.addToQueueNext(song, source: .user)
                    }) {
                        Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    
                    Divider()
                    
                    if AlbumArtworkDownloadService.shared.needsArtworkDownload(for: song) {
                        Button(action: {
                            AlbumArtworkManager.shared.downloadArtworkIfNeeded(for: song) { _ in }
                        }) {
                            Label("下载专辑封面", systemImage: "photo.badge.plus")
                        }
                        
                        Divider()
                    }
                    
                    Button(action: {
                        // TODO: 添加到播放列表功能
                    }) {
                        Label("添加到播放列表", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(MusicConstants.grayMedium)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 艺术家行
struct ArtistRow: View {
    let artist: Artist
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(MusicConstants.grayDark)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(MusicConstants.grayMedium)
                        .font(.title2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("\(artist.songCount) 首歌曲")
                    .font(.caption)
                    .foregroundColor(MusicConstants.grayMedium)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(MusicConstants.grayMedium)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 播放列表行
struct PlaylistRow: View {
    let title: String
    let songCount: Int
    let artwork: String
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(MusicConstants.grayDark)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note.list")
                        .foregroundColor(MusicConstants.grayMedium)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("\(songCount) 首歌曲")
                    .font(.caption)
                    .foregroundColor(MusicConstants.grayMedium)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .foregroundColor(MusicConstants.grayMedium)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 16) {
        LibrarySongRow(
            song: Song(
                title: "示例歌曲",
                artist: "示例艺术家",
                album: "示例专辑",
                duration: 180,
                albumArtwork: "default_album",
                fileName: "example.mp3"
            ),
            index: 1
        )
        
        ArtistRow(
            artist: Artist(
                name: "示例艺术家",
                artwork: "default_artist",
                albums: []
            )
        )
        
        PlaylistRow(
            title: "我的播放列表",
            songCount: 10,
            artwork: "playlist1"
        )
    }
    .padding()
    .background(MusicConstants.darkBackground)
    .preferredColorScheme(.dark)
} 