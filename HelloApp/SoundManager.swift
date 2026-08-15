import Foundation
import AVFoundation

/// 程序化音效系统(无需音频文件,实时合成)
/// 注意: AVAudioEngine 非线程安全,所有引擎图操作(attach/connect/play/detach)
/// 必须在主线程串行执行,否则并发修改会闪退。
final class SoundManager {
    static let shared = SoundManager()
    private let engine = AVAudioEngine()
    private var enabled = true
    private var started = false

    private init() {
        // 预热引擎(主线程)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            started = true
        } catch {
            print("[Sound] 引擎启动失败: \(error)")
            started = false
        }
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        if on {
            if !started { try? engine.start(); started = engine.isRunning }
        } else {
            engine.pause()
        }
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
        // 1) 后台合成 PCM buffer(纯 CPU 计算,不碰引擎)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let buffer = self.synthesize(sfx)
            // 2) 引擎图操作切回主线程串行执行
            DispatchQueue.main.async { [weak self] in
                self?.playBuffer(buffer)
            }
        }
    }

    // MARK: - 合成(可在任意线程,不接触 AVAudioEngine)
    private func synthesize(_ sfx: SFX) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return nil }
        let frameCount: AVAudioFrameCount
        let fill: (UnsafeMutablePointer<Float>) -> Void

        switch sfx {
        case .attack:
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
            frameCount = 22000
            fill = { buf in
                let notes: [Double] = [523, 659, 784, 1047]
                let noteLen = Int(frameCount) / notes.count
                for i in 0..<Int(frameCount) {
                    let noteIdx = min(i / noteLen, notes.count - 1)
                    let localT = Double(i % noteLen) / 44100.0
                    let env = exp(-localT * 4)
                    buf[i] = Float(env * sin(2 * .pi * notes[noteIdx] * localT) * 0.3)
                }
            }
        case .coin:
            frameCount = 6000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let env = exp(-t * 10)
                    buf[i] = Float(env * (sin(2 * .pi * 1318 * t) + sin(2 * .pi * 1976 * t)) * 0.15)
                }
            }
        case .death:
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
            frameCount = 1500
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let env = exp(-t * 60)
                    buf[i] = Float(env * sin(2 * .pi * 800 * t) * 0.2)
                }
            }
        case .error:
            frameCount = 8000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let env = exp(-t * 8)
                    buf[i] = Float(env * sin(2 * .pi * 150 * t) * 0.3)
                }
            }
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return nil }
        fill(channelData[0])
        return buffer
    }

    // MARK: - 播放(必须主线程)
    private func playBuffer(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer = buffer, started, engine.isRunning else { return }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
        let dur = Double(buffer.frameLength) / 44100.0 + 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) { [weak self] in
            player.stop()
            self?.engine.detach(player)
        }
    }
}
