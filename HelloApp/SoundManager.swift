import Foundation
import AVFoundation

/// 程序化音效系统(无需音频文件,实时合成)
/// 安全要点:
/// 1) AVAudioEngine 非线程安全 → 所有引擎图操作在主线程串行执行
/// 2) 引擎启动延迟到首次播放,且全部 do-catch,绝不抛出(避免任何设备上闪退)
/// 3) 引擎不可用时 play() 静默返回
final class SoundManager {
    static let shared = SoundManager()
    private let engine = AVAudioEngine()
    private var enabled = true
    private var started = false
    private var startAttempted = false

    private init() {
        // 不在 init 里碰 AVAudioSession/引擎启动, 避免任何启动期异常
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        if !on { engine.pause() }
    }

    // MARK: - 音效类型
    enum SFX: String {
        case attack, hit, skill, aoe, levelup, coin, death, heal, button, error
    }

    func play(_ sfx: SFX) {
        guard enabled else { return }
        // 后台合成 buffer(纯计算)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let buffer = self.synthesize(sfx)
            // 引擎操作切主线程
            DispatchQueue.main.async { [weak self] in
                self?.playBuffer(buffer)
            }
        }
    }

    /// 首次播放时尝试启动引擎(只试一次, 失败永久静音)
    private func ensureStarted() {
        guard !startAttempted else { return }
        startAttempted = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            started = true
        } catch {
            print("[Sound] 引擎启动失败(将静音): \(error)")
            started = false
        }
    }

    // MARK: - 合成(任意线程, 不接触引擎)
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
                    buf[i] = Float(exp(-t * 30) * sin(2 * .pi * freq * t) * 0.3)
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
                    buf[i] = Float(exp(-t * 12) * sin(2 * .pi * freq * t) * 0.35)
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
                    buf[i] = Float(exp(-localT * 4) * sin(2 * .pi * notes[noteIdx] * localT) * 0.3)
                }
            }
        case .coin:
            frameCount = 6000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    buf[i] = Float(exp(-t * 10) * (sin(2 * .pi * 1318 * t) + sin(2 * .pi * 1976 * t)) * 0.15)
                }
            }
        case .death:
            frameCount = 11000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let freq = 200 - 150 * t / 0.25
                    buf[i] = Float(exp(-t * 6) * sin(2 * .pi * freq * t) * 0.4)
                }
            }
        case .heal:
            frameCount = 10000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    let freq = 400 + 300 * t / 0.23
                    buf[i] = Float(sin(.pi * t / 0.23) * sin(2 * .pi * freq * t) * 0.25)
                }
            }
        case .button:
            frameCount = 1500
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    buf[i] = Float(exp(-t * 60) * sin(2 * .pi * 800 * t) * 0.2)
                }
            }
        case .error:
            frameCount = 8000
            fill = { buf in
                for i in 0..<Int(frameCount) {
                    let t = Double(i) / 44100.0
                    buf[i] = Float(exp(-t * 8) * sin(2 * .pi * 150 * t) * 0.3)
                }
            }
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { return nil }
        fill(channelData[0])
        return buffer
    }

    // MARK: - 播放(主线程)
    private func playBuffer(_ buffer: AVAudioPCMBuffer?) {
        guard enabled else { return }
        ensureStarted()
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
