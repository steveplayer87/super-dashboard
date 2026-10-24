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
                    VStack(alignment: .leading, spacing: 8) {
                        // 桃捷精確站距動態軌道 (A12 0% -> A18 63% -> A21 100%)
                        VStack(spacing: 5) {
                            GeometryReader { geo in
                                let totalW = geo.size.width
                                let progressClamped = max(0.04, min(1.0, CGFloat(context.state.progress)))
                                let trainX = totalW * progressClamped
                                let a18X = totalW * 0.63 // 桃捷官方時間比: 21分/33分 = 63.6%
                                
                                ZStack(alignment: .leading) {
                                    // 軌道底槽
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 5)
                                    
                                    // 已駛過亮色軌道
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [metroPurple, metroPurpleGlow],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .frame(width: trainX, height: 5)
                                    
                                    // 起點站 A12 標記
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 0)
                                    
                                    // 目標站 A18 標記 (精確坐標 63%)
                                    Circle()
                                        .fill(context.state.progress >= 0.63 ? metroPurpleGlow : Color.white.opacity(0.45))
                                        .frame(width: 9, height: 9)
                                        .offset(x: a18X - 4.5)
                                    
                                    // 終點站 A21 標記 (100%)
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 7, height: 7)
                                        .offset(x: totalW - 7)
                                    
                                    // 實時動態列車車標 (精確跟隨進度移動，在到達 A18 前絕對在 A18 左側)
                                    ZStack {
                                        Circle()
                                            .fill(metroPurpleGlow)
                                            .frame(width: 14, height: 14)
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 6, height: 6)
                                    }
                                    .offset(x: max(0, min(totalW - 14, trainX - 7)))
                                }
                            }
                            .frame(height: 14)
                            
                            HStack {
                                Text("A12 機場一航")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.55))
                                Spacer()
                                Text("A18 高鐵桃園")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(metroPurpleGlow)
                                    .offset(x: 10) // 依據 63% 比例微調視覺居中偏右
                                Spacer()
                                Text("A21 環北")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.55))
                            }
                        }
                        
                        // 下一站與車資（單張卡片，節省高度）
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
                                Text("扣款")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.55))
                                Text(context.state.fare)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(goldAccent)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .frame(minHeight: 92)
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
