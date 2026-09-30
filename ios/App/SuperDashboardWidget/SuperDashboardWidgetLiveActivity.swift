import ActivityKit
import WidgetKit
import SwiftUI

public struct SuperDashboardWidgetLiveActivity: Widget {
    public init() {}
    
    // 桃園捷運專屬尊榮配色 (高質感黑曜石與捷運尊榮紫)
    private let metroPurple = Color(red: 0.55, green: 0.18, blue: 0.91)
    private let metroPurpleGlow = Color(red: 0.69, green: 0.38, blue: 1.0)
    private let goldAccent = Color(red: 0.83, green: 0.69, blue: 0.22)
    private let darkBg = Color(red: 0.05, green: 0.04, blue: 0.08)

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaoyuanMetroAttributes.self) { context in
            // 鎖定螢幕／橫幅通知介面
            VStack(alignment: .leading, spacing: 12) {
                // 頂部：捷運路線、車次與狀態
                HStack(alignment: .center) {
                    HStack(spacing: 7) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 15))
                            .foregroundColor(metroPurpleGlow)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.lineName)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(context.attributes.trainType)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(metroPurpleGlow)
                        }
                    }
                    
                    Spacer()
                    
                    // 即將抵達倒數徽章
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.36, green: 0.84, blue: 0.54))
                            .frame(width: 7, height: 7)
                        Text(context.state.statusText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.36, green: 0.84, blue: 0.54))
                        Text("\(context.state.etaMinutes) 分鐘")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(goldAccent)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
                }
                
                // 中間：擬真捷運站點軌道進度條
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // 軌道底線
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 5)
                            
                            // 已行駛紫光進度條
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [metroPurple, metroPurpleGlow],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(context.state.progress), height: 5)
                            
                            // 站點圓點
                            HStack {
                                Circle().fill(Color.white).frame(width: 9, height: 9)
                                Spacer()
                                Circle().fill(metroPurpleGlow).frame(width: 11, height: 11)
                                Spacer()
                                Circle().fill(Color.white.opacity(0.4)).frame(width: 9, height: 9)
                            }
                        }
                    }
                    .frame(height: 12)
                    
                    // 站點名稱對照
                    HStack {
                        Text("A12 機場一航")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                        Spacer()
                        Text("A18 高鐵桃園 (即將抵達)")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(metroPurpleGlow)
                        Spacer()
                        Text("A21 環北")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
                
                // 底部票價扣除與感應狀態
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 11))
                            .foregroundColor(goldAccent)
                        Text("悠遊卡扣款 \(context.state.fare)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(goldAccent)
                    }
                    
                    Spacer()
                    
                    Text("出示悠遊卡")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.05, blue: 0.12), Color(red: 0.03, green: 0.02, blue: 0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .activityBackgroundTint(Color(red: 0.06, green: 0.04, blue: 0.09))
            .activitySystemActionForegroundColor(metroPurpleGlow)

        } dynamicIsland: { context in
            DynamicIsland {
                // 展開式動態島 (長按動態島展開 - 加高設計，排版充足寬敞，文字不重疊)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 14))
                            .foregroundColor(metroPurpleGlow)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("桃捷 機場線")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(context.attributes.trainType)
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(metroPurpleGlow)
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.top, 4)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0.36, green: 0.84, blue: 0.54))
                                .frame(width: 6, height: 6)
                            Text(context.state.statusText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.36, green: 0.84, blue: 0.54))
                        }
                        HStack(spacing: 2) {
                            Text("\(context.state.etaMinutes)")
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundColor(goldAccent)
                            Text("分鐘")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }
                    .padding(.trailing, 6)
                    .padding(.top, 4)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        // 路線與車資行
                        HStack {
                            Text("\(context.state.currentStation) → \(context.state.destination)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.75))
                            
                            Spacer()
                            
                            HStack(spacing: 3) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(goldAccent)
                                Text("扣款 \(context.state.fare)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(goldAccent)
                            }
                        }
                        
                        // 軌道進度條
                        VStack(spacing: 5) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 5)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [metroPurple, metroPurpleGlow],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(context.state.progress), height: 5)
                                    
                                    HStack {
                                        Circle().fill(Color.white).frame(width: 8, height: 8)
                                        Spacer()
                                        Circle().fill(metroPurpleGlow).frame(width: 11, height: 11)
                                        Spacer()
                                        Circle().fill(Color.white.opacity(0.3)).frame(width: 8, height: 8)
                                    }
                                }
                            }
                            .frame(height: 12)
                            
                            HStack {
                                Text("A12 機場一航")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.55))
                                Spacer()
                                Text("A18 高鐵桃園")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(metroPurpleGlow)
                                Spacer()
                                Text("A21 環北")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.55))
                            }
                        }
                        
                        // 下一站到達預告看板（獨立卡片結構，提供充足垂直高度與清晰字體）
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("下一站抵達")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.55))
                                Text(context.state.nextStation)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("車次型態")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.55))
                                Text(context.attributes.trainType)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(metroPurpleGlow)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 11))
                        .foregroundColor(metroPurpleGlow)
                    Text("桃捷")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 2) {
                    Text("\(context.state.etaMinutes)")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(goldAccent)
                    Text("分")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .padding(.trailing, 4)
            } minimal: {
                Image(systemName: "tram.fill")
                    .foregroundColor(metroPurpleGlow)
            }
            .widgetURL(URL(string: "superdashboard://wallet?card=easycard"))
            .keylineTint(metroPurpleGlow)
        }
    }
}
