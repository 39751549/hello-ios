import Foundation
import AVFoundation

/// 程序化音效系统(无需音频文件,实时合成)
final class SoundManager {
    static let shared = SoundManager()
    private let engine = AVAudioEngine()
    private var enabled = true

    private init() {
        // 预热引擎
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            print("[Sound] 引擎启动失败: \(error)")
        }
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        if on { try? engine.start() }
        else { engine.pause() }
    }

    // MARK: - 音效类型
    enum SFX: String {
        case attack    // 普攻挥砍
        case hit       // 命中
        case skill     // 技能释放
        case aoe       // AOE爆炸
        case levelup   // 升级
        case coin      // 金币
        case death     // 怪物死亡
        case heal      // 治疗
        case button    // 按钮点击
        case error     // 错误提示
    }

    func play(_ sfx: SFX) {
        guard enabled else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.generate(sfx)
        }
    }

    // MARK: - 合成
    private func generate(_ sfx: SFX) {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let sampleRate = 4410.0
        let frameCount: AVAudioFrameCount
        let fill: (UnsafeMutablePointer<Float>) -> Void

        switch sfx {
        case .attack:
            // 短促"嗖"声 - 下行频率
            frameCount = 4400
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let freq = 1200 - 900 * t / 0.1
                    let env = exp(-t * 30)
                    buf[i] = Float(env * sin(2 * .pi * freq * t) * 0.3)
                }
            }
        case .hit:
            // 命中"啪" - 噪声+低频
            frameCount = 3000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let env = exp(-t * 40)
                    let noise = Double.random(in: -1...1) * 0.4
                    let tone = sin(2 * .pi * 200 * t) * 0.3
                    buf[i] = Float(env * (noise + tone) * 0.5)
                }
            }
        case .skill:
            // 技能"呼" - 上行扫频
            frameCount = 8800
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let freq = 300 + 800 * t / 0.2
                    let env = exp(-t * 12)
                    buf[i] = Float(env * sin(2 * .pi * freq * t) * 0.35)
                }
            }
        case .aoe:
            // AOE 爆炸 - 低频轰鸣
            frameCount = 13200
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let env = exp(-t * 8)
                    let low = sin(2 * .pi * 80 * t) * 0.5
                    let noise = Double.random(in: -1...1) * 0.3
                    buf[i] = Float(env * (low + noise) * 0.6)
                }
            }
        case .levelup:
            // 升级 - 上升音阶
            frameCount = 22000
            fill = { buf in
                let notes: [Double] = [523, 659, 784, 1047]  // C E G C
                let noteLen = Int(frameCount) / notes.count
                for i in 0..<Int(frameCount) {
                    let noteIdx = min(i / noteLen, notes.count - 1)
                    let localT = Double(i % noteLen) / 44100.0
                    let env = exp(-localT * 4)
                    buf[i] = Float(env * sin(2 * .pi * notes[noteIdx] * localT) * 0.3)
                }
            }
        case .coin:
            // 金币"叮"
            frameCount = 6000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let env = exp(-t * 10)
                    buf[i] = Float(env * (sin(2 * .pi * 1318 * t) + sin(2 * .pi * 1976 * t)) * 0.15)
                }
            }
        case .death:
            // 死亡 - 下降吼叫
            frameCount = 11000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let freq = 200 - 150 * t / 0.25
                    let env = exp(-t * 6)
                    buf[i] = Float(env * sin(2 * .pi * freq * t) * 0.4)
                }
            }
        case .heal:
            // 治疗 - 柔和上升
            frameCount = 10000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let freq = 400 + 300 * t / 0.23
                    let env = sin(.pi * t / 0.23)
                    buf[i] = Float(env * sin(2 * .pi * freq * t) * 0.25)
                }
            }
        case .button:
            // 按钮点击
            frameCount = 1500
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let env = exp(-t * 60)
                    buf[i] = Float(env * sin(2 * .pi * 800 * t) * 0.2)
                }
            }
        case .error:
            // 错误 - 低频蜂鸣
            frameCount = 8000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let env = exp(-t * 8)
                    buf[i] = Float(env * sin(2 * .pi * 150 * t) * 0.3)
                }
            }
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        fill(channelData)

        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
        // 播完后清理
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(frameCount) / 44100.0 + 0.1) { [weak self] in
            player.stop()
            self?.engine.detach(player)
        }
    }
}
