import SwiftUI
import Combine

// MARK: - 专辑封面显示样式
enum ArtworkDisplayStyle {
    case square          // 正方形
    case rounded         // 圆角
    case circle          // 圆形
    case card            // 卡片样式
    case thumbnail       // 缩略图
}

// MARK: - 专辑封面尺寸预设
enum ArtworkSize {
    case tiny           // 30x30
    case small          // 50x50
    case medium         // 80x80
    case large          // 120x120
    case extraLarge     // 200x200
    case custom(CGFloat) // 自定义尺寸
    
    var value: CGFloat {
        switch self {
        case .tiny: return 30
        case .small: return 50
        case .medium: return 80
        case .large: return 120
        case .extraLarge: return 200
        case .custom(let size): return size
        }
    }
}

// MARK: - 增强版异步专辑封面视图
struct EnhancedAsyncArtworkView: View {
    
    // MARK: - Properties
    let song: Song
    let size: ArtworkSize
    let style: ArtworkDisplayStyle
    let showLoadingIndicator: Bool
    let showDownloadButton: Bool
    let useThumbnail: Bool
    
    // MARK: - State
    @StateObject private var artworkManager = AlbumArtworkManager.shared
    @StateObject private var persistenceManager = AlbumArtworkPersistenceManager.shared
    @State private var artworkImage: UIImage?
    @State private var isLoading = false
    @State private var loadingError: String?
    @State private var showingDownloadSheet = false
    
    // MARK: - Initialization
    init(
        song: Song,
        size: ArtworkSize = .medium,
        style: ArtworkDisplayStyle = .rounded,
        showLoadingIndicator: Bool = true,
        showDownloadButton: Bool = false,
        useThumbnail: Bool = false
    ) {
        self.song = song
        self.size = size
        self.style = style
        self.showLoadingIndicator = showLoadingIndicator
        self.showDownloadButton = showDownloadButton
        self.useThumbnail = useThumbnail
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // 主要内容
            artworkContent
            
            // 加载指示器
            if isLoading && showLoadingIndicator {
                loadingOverlay
            }
            
            // 下载按钮
            if showDownloadButton && !persistenceManager.hasArtwork(for: song) {
                downloadButtonOverlay
            }
            
            // 错误指示器
            if let error = loadingError {
                errorOverlay(error)
            }
        }
        .onAppear {
            loadArtwork()
        }
        .onChange(of: song.id) {
            loadArtwork()
        }
        .sheet(isPresented: $showingDownloadSheet) {
            ArtworkDownloadSheet(song: song)
        }
    }
    
    // MARK: - 专辑封面内容
    @ViewBuilder
    private var artworkContent: some View {
        if let image = artworkImage {
            artworkImageView(image)
        } else {
            placeholderView
        }
    }
    
    // MARK: - 专辑封面图片视图
    private func artworkImageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.value, height: size.value)
            .clipped()
            .modifier(StyleModifier(style: style, size: size.value))
    }
    
    // MARK: - 占位符视图
    private var placeholderView: some View {
        ZStack {
            // 背景
            backgroundForStyle
            
            // 图标
            Image(systemName: iconForPlaceholder)
                .font(.system(size: size.value * 0.4))
                .foregroundColor(colorForPlaceholder)
        }
        .frame(width: size.value, height: size.value)
        .modifier(StyleModifier(style: style, size: size.value))
    }
    
    // MARK: - 加载覆盖层
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
        }
        .frame(width: size.value, height: size.value)
        .modifier(StyleModifier(style: style, size: size.value))
    }
    
    // MARK: - 下载按钮覆盖层
    private var downloadButtonOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    showingDownloadSheet = true
                }) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: size.value * 0.25))
                        .foregroundColor(.blue)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .padding(4)
            }
        }
        .frame(width: size.value, height: size.value)
    }
    
    // MARK: - 错误覆盖层
    private func errorOverlay(_ error: String) -> some View {
        ZStack {
            Color.red.opacity(0.1)
            
            VStack(spacing: 2) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: size.value * 0.3))
                    .foregroundColor(.red)
                
                if size.value >= 80 {
                    Text("加载失败")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .frame(width: size.value, height: size.value)
        .modifier(StyleModifier(style: style, size: size.value))
    }
    
    // MARK: - 样式相关计算属性
    private var backgroundForStyle: some View {
        switch style {
        case .square, .rounded, .card:
            return AnyView(Color.gray.opacity(0.2))
        case .circle, .thumbnail:
            return AnyView(Color.gray.opacity(0.3))
        }
    }
    
    private var iconForPlaceholder: String {
        switch style {
        case .square, .rounded:
            return "music.note"
        case .circle:
            return "person.circle"
        case .card:
            return "opticaldisc"
        case .thumbnail:
            return "photo"
        }
    }
    
    private var colorForPlaceholder: Color {
        switch style {
        case .square, .rounded, .card:
            return .gray
        case .circle:
            return .blue
        case .thumbnail:
            return .orange
        }
    }
    
    // MARK: - 加载方法
    private func loadArtwork() {
        loadingError = nil
        
        // 首先尝试从持久化管理器获取
        if let image = persistenceManager.getArtworkImage(for: song, useThumbnail: useThumbnail) {
            artworkImage = image
            return
        }
        
        // 然后尝试从缓存获取
        if let cachedImage = artworkManager.getArtworkImage(for: song) {
            artworkImage = cachedImage
            return
        }
        
        // 最后异步加载
        isLoading = true
        artworkManager.getArtworkImageAsync(for: song) { image in
            DispatchQueue.main.async {
                isLoading = false
                
                if let image = image {
                    artworkImage = image
                } else {
                    loadingError = "无法加载专辑封面"
                }
            }
        }
    }
}

// MARK: - 样式修饰器
struct StyleModifier: ViewModifier {
    let style: ArtworkDisplayStyle
    let size: CGFloat
    
    func body(content: Content) -> some View {
        switch style {
        case .square:
            content
        case .rounded:
            content.cornerRadius(8)
        case .circle:
            content.clipShape(Circle())
        case .card:
            content
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        case .thumbnail:
            content
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - 专辑封面下载面板
struct ArtworkDownloadSheet: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadService = AlbumArtworkDownloadService.shared
    @State private var isDownloading = false
    @State private var downloadResult: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 歌曲信息
                VStack(spacing: 8) {
                    Text(song.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(song.artist) • \(song.album)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 当前状态
                EnhancedAsyncArtworkView(
                    song: song,
                    size: .extraLarge,
                    style: .card
                )
                
                // 下载按钮
                if !isDownloading {
                    Button(action: downloadArtwork) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("下载专辑封面")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                } else {
                    VStack(spacing: 8) {
                        ProgressView(value: downloadService.downloadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("正在下载...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 下载结果
                if let result = downloadResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("专辑封面")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") { dismiss() })
        }
    }
    
    private func downloadArtwork() {
        isDownloading = true
        downloadResult = nil
        
        downloadService.downloadArtwork(for: song) { result in
            DispatchQueue.main.async {
                isDownloading = false
                
                switch result {
                case .success:
                    downloadResult = "专辑封面下载成功！"
                case .failure(let error):
                    downloadResult = "下载失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 专辑封面网格视图
struct ArtworkGridView: View {
    let songs: [Song]
    let columns: Int
    let spacing: CGFloat
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(songs) { song in
                EnhancedAsyncArtworkView(
                    song: song,
                    size: .large,
                    style: .card,
                    showDownloadButton: true
                )
            }
        }
        .padding()
    }
}

// MARK: - 专辑封面轮播视图
struct ArtworkCarouselView: View {
    let songs: [Song]
    @State private var currentIndex = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    VStack(spacing: 16) {
                        EnhancedAsyncArtworkView(
                            song: song,
                            size: .extraLarge,
                            style: .card
                        )
                        
                        VStack(spacing: 4) {
                            Text(song.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text("\(song.artist) • \(song.album)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 300)
            
            // 页面指示器
            HStack {
                ForEach(0..<songs.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            currentIndex = index
                        }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 预览
struct EnhancedAsyncArtworkView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSong = Song(
            title: "Sample Song",
            artist: "Sample Artist",
            album: "Sample Album",
            duration: 180,
            albumArtwork: "",
            fileName: "sample.mp3"
        )
        
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                EnhancedAsyncArtworkView(song: sampleSong, size: .small, style: .circle)
                EnhancedAsyncArtworkView(song: sampleSong, size: .medium, style: .rounded)
                EnhancedAsyncArtworkView(song: sampleSong, size: .large, style: .card)
            }
            
            EnhancedAsyncArtworkView(
                song: sampleSong,
                size: .extraLarge,
                style: .card,
                showDownloadButton: true
            )
        }
        .padding()
    }
} 