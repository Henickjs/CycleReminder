import Foundation

struct SoundOption: Identifiable, Hashable {
    /// 稳定标识，随规则一起持久化
    let id: String
    /// Bundle 中的音频文件名；nil 表示使用系统默认提示音
    let fileName: String?
    let displayName: String
}

enum SoundCatalog {
    static let systemDefault = SoundOption(id: "system", fileName: nil, displayName: "系统默认")

    static let all: [SoundOption] = [
        systemDefault,
        SoundOption(id: "chime", fileName: "chime.wav", displayName: "清脆钟声"),
        SoundOption(id: "soft", fileName: "soft.wav", displayName: "柔和提示"),
        SoundOption(id: "alert", fileName: "alert.wav", displayName: "急促提醒"),
        SoundOption(id: "water", fileName: "water.wav", displayName: "水滴"),
        SoundOption(id: "bird", fileName: "bird.wav", displayName: "鸟鸣"),
        SoundOption(id: "ring", fileName: "ring.wav", displayName: "经典铃声"),
        SoundOption(id: "upbeat", fileName: "upbeat.wav", displayName: "上扬音"),
    ]

    /// 新建规则的默认铃声
    static let defaultSound = all[1]

    static func option(for id: String) -> SoundOption {
        all.first { $0.id == id } ?? defaultSound
    }
}
