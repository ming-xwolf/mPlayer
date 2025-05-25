import SwiftUI

// MARK: - 个人页面视图
struct ProfileView: View {
    @StateObject private var musicPlayer = MusicPlayerManager.shared
    @StateObject private var dataManager = MusicDataManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 用户信息
                    VStack(spacing: 16) {
                        Circle()
                            .fill(MusicConstants.grayDark)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(MusicConstants.grayMedium)
                                    .font(.system(size: 40))
                            )
                        
                        VStack(spacing: 4) {
                            Text("音乐爱好者")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("已收听 \(dataManager.totalSongs) 首歌曲")
                                .font(.caption)
                                .foregroundColor(MusicConstants.grayMedium)
                        }
                    }
                    
                    // 统计信息
                    HStack(spacing: 32) {
                        StatItem(title: "播放时长", value: dataManager.formattedTotalDuration)
                        StatItem(title: "喜欢的歌曲", value: "\(dataManager.favoriteSongs.count)")
                        StatItem(title: "播放列表", value: "\(dataManager.totalPlaylists)")
                    }
                    
                    // 功能菜单
                    VStack(spacing: 16) {
                        MenuRow(icon: "heart.fill", title: "我喜欢的音乐", iconColor: MusicConstants.primaryColor)
                        MenuRow(icon: "clock.fill", title: "最近播放", iconColor: MusicConstants.secondaryColor)
                        MenuRow(icon: "arrow.down.circle.fill", title: "已下载", iconColor: .green)
                        MenuRow(icon: "person.2.fill", title: "关注的艺术家", iconColor: .orange)
                    }
                    
                    Divider()
                        .background(MusicConstants.grayDark)
                    
                    // 设置菜单
                    VStack(spacing: 16) {
                        MenuRow(icon: "gearshape.fill", title: "设置", iconColor: MusicConstants.grayMedium)
                        MenuRow(icon: "questionmark.circle.fill", title: "帮助与反馈", iconColor: MusicConstants.grayMedium)
                        MenuRow(icon: "info.circle.fill", title: "关于", iconColor: MusicConstants.grayMedium)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(MusicConstants.darkBackground)
            .navigationTitle("我的")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
} 