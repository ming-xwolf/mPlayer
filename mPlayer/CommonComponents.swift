import SwiftUI

// MARK: - 统计项组件
struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(MusicConstants.grayMedium)
        }
    }
}

// MARK: - 菜单行组件
struct MenuRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title2)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(MusicConstants.grayMedium)
                .font(.caption)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 16) {
        StatItem(title: "播放时长", value: "2小时30分")
        
        Divider()
            .background(MusicConstants.grayDark)
        
        MenuRow(icon: "heart.fill", title: "我喜欢的音乐", iconColor: MusicConstants.primaryColor)
        MenuRow(icon: "clock.fill", title: "最近播放", iconColor: MusicConstants.secondaryColor)
        MenuRow(icon: "gearshape.fill", title: "设置", iconColor: MusicConstants.grayMedium)
    }
    .padding()
    .background(MusicConstants.darkBackground)
    .preferredColorScheme(.dark)
} 