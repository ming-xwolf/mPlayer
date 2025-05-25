import SwiftUI

// MARK: - 搜索视图
struct SearchView: View {
    @StateObject private var dataManager = MusicDataManager.shared
    @State private var searchText = ""
    @State private var recentSearches: [String] = []
    @State private var selectedCategory = 0
    
    let categories = ["全部", "歌曲", "专辑", "艺术家", "播放列表", "MV"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                VStack(spacing: 16) {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(MusicConstants.grayMedium)
                            
                            TextField("搜索音乐、艺术家或专辑", text: $searchText)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(MusicConstants.grayDark)
                        .cornerRadius(20)
                        
                        if !searchText.isEmpty {
                            Button("取消") {
                                searchText = ""
                            }
                            .foregroundColor(MusicConstants.primaryColor)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 搜索分类
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<categories.count, id: \.self) { index in
                                Button(action: {
                                    selectedCategory = index
                                }) {
                                    Text(categories[index])
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedCategory == index ?
                                            MusicConstants.primaryColor :
                                                MusicConstants.grayDark
                                        )
                                        .foregroundColor(.white)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
                
                if searchText.isEmpty {
                    // 空状态：显示最近搜索和推荐
                    emptySearchView
                } else {
                    // 搜索结果
                    searchResultsView
                }
            }
            .background(MusicConstants.darkBackground)
        }
    }
    
    // MARK: - 空搜索状态
    private var emptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 最近搜索
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("最近搜索")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 12) {
                            ForEach(recentSearches, id: \.self) { search in
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(MusicConstants.grayMedium)
                                    
                                    Text(search)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        recentSearches.removeAll { $0 == search }
                                    }) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(MusicConstants.grayMedium)
                                    }
                                }
                                .padding(.vertical, 8)
                                .onTapGesture {
                                    searchText = search
                                }
                            }
                        }
                        
                        Button("清除全部历史记录") {
                            recentSearches.removeAll()
                        }
                        .foregroundColor(MusicConstants.grayMedium)
                        .font(.caption)
                    }
                    .padding(.horizontal)
                }
                
                // 推荐艺术家
                VStack(alignment: .leading, spacing: 16) {
                    Text("推荐艺术家")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(dataManager.artists.prefix(6)) { artist in
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(MusicConstants.grayDark)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(MusicConstants.grayMedium)
                                            .font(.title)
                                    )
                                
                                Text(artist.name)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Text("\(artist.songCount) 首歌曲")
                                    .font(.caption)
                                    .foregroundColor(MusicConstants.grayMedium)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - 搜索结果视图
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(dataManager.searchSongs(query: searchText)) { song in
                    SongRowView(song: song)
                        .onTapGesture {
                            MusicPlayerManager.shared.playSong(song, from: dataManager.songs)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
}

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
} 