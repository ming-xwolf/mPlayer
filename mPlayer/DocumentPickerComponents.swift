import SwiftUI
import UniformTypeIdentifiers

// MARK: - 文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onDocumentsPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsPicked(urls)
        }
    }
}

// MARK: - 扫描结果视图
struct ScanResultsView: View {
    @Binding var scanResults: [Song]
    @Binding var isPresented: Bool
    let onAddSelected: ([Song]) -> Void
    
    @State private var selectedSongs: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            VStack {
                if scanResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.slash")
                            .font(.system(size: 60))
                            .foregroundColor(MusicConstants.grayMedium)
                        
                        Text("未找到音频文件")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("请选择包含 MP3、M4A、WAV 等音频格式的文件")
                            .font(.body)
                            .foregroundColor(MusicConstants.grayMedium)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        Section(header: 
                            HStack {
                                Text("找到 \(scanResults.count) 个音频文件")
                                    .foregroundColor(.white)
                                Spacer()
                                Button(selectedSongs.count == scanResults.count ? "取消全选" : "全选") {
                                    if selectedSongs.count == scanResults.count {
                                        selectedSongs.removeAll()
                                    } else {
                                        selectedSongs = Set(scanResults.map { $0.id })
                                    }
                                }
                                .foregroundColor(MusicConstants.primaryColor)
                            }
                        ) {
                            ForEach(scanResults) { song in
                                ScanResultRow(
                                    song: song,
                                    isSelected: selectedSongs.contains(song.id)
                                ) {
                                    if selectedSongs.contains(song.id) {
                                        selectedSongs.remove(song.id)
                                    } else {
                                        selectedSongs.insert(song.id)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.grouped)
                }
            }
            .background(MusicConstants.darkBackground)
            .navigationTitle("扫描结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(MusicConstants.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加(\(selectedSongs.count))") {
                        let songsToAdd = scanResults.filter { selectedSongs.contains($0.id) }
                        onAddSelected(songsToAdd)
                        isPresented = false
                    }
                    .foregroundColor(MusicConstants.primaryColor)
                    .disabled(selectedSongs.isEmpty)
                }
            }
        }
        .onAppear {
            // 默认选中所有歌曲
            selectedSongs = Set(scanResults.map { $0.id })
        }
    }
}

// MARK: - 扫描结果行
struct ScanResultRow: View {
    let song: Song
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? MusicConstants.primaryColor : MusicConstants.grayMedium)
                    .font(.title2)
            }
            
            RoundedRectangle(cornerRadius: 6)
                .fill(MusicConstants.grayDark)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(MusicConstants.grayMedium)
                        .font(.caption)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(song.artist) · \(song.album)")
                    .font(.caption)
                    .foregroundColor(MusicConstants.grayMedium)
                    .lineLimit(1)
                
                Text(song.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(MusicConstants.grayMedium)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - 扫描加载视图
struct ScanningOverlay: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(MusicConstants.primaryColor)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
                
                Text("正在扫描音频文件...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("请稍候")
                    .font(.body)
                    .foregroundColor(MusicConstants.grayMedium)
            }
            .padding(24)
            .background(MusicConstants.grayDark)
            .cornerRadius(16)
        }
    }
}

#Preview {
    ScanResultsView(
        scanResults: .constant([]),
        isPresented: .constant(true),
        onAddSelected: { _ in }
    )
    .preferredColorScheme(.dark)
} 