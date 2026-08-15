import Foundation
import AVFoundation

/// 程序化音效系统(无需音频文件,实时合成)
/// 安全要点:
/// 1) AVAudioEngine 非线程安全 → 所有引擎图操作在主线程串行执行
/// 2) 引擎启动延迟到首次播放,且全部 do-catch,绝不抛出(避免任何设备上闪退)
/// 3) 引擎不可用时 play() 静默返回
/// 4) 主线程串行队列 + player 生命周期标记,杜绝重入/detach 已分离节点导致的崩溃
final class SoundManager {
    static let shared = SoundManager()
    private let engine = AVAudioEngine()
    private var enabled = true
    private var started = false
    private var startAttempted = false
    /// 主线程串行队列: 所有引擎图操作排队执行,避免并发 attach/detach
    private let graphQueue = DispatchQueue.main
    /// 当前活跃的 player 节点(用于安全 detach)
    private var activePlayers: [ObjectIdentifier: AVAudioPlayerNode] = [:]

    private init() {
        // 不在 init 里碰 AVAudioSession/引擎启动, 避免任何启动期异常
        // 监听音频中断,做最起码的恢复
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            guard let info = note.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
            if type == .began {
                self.engine.pause()
            } else if type == .ended {
                if self.started, !self.engine.isRunning {
                    try? self.engine.start()
                }
            }
        }
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        if !on { graphQueue.async { [weak self] in self?.engine.pause() } }
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
            // 引擎操作切主线程串行队列
            self.graphQueue.async { [weak self] in
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

    // MARK: - 播放(主线程串行)
    private func playBuffer(_ buffer: AVAudioPCMBuffer?) {
        guard enabled else { return }
        ensureStarted()
        guard let buffer = buffer, started, engine.isRunning else { return }
        let player = AVAudioPlayerNode()
        let key = ObjectIdentifier(player)
        // attach/connect/play 全部在同一主线程串行队列里完成
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        activePlayers[key] = player
        player.scheduleBuffer(buffer) { [weak self] in
            // 播放完成回调(可能在引擎内部线程) → 切回主线程清理
            self?.graphQueue.async { [weak self] in
                self?.teardownPlayer(key: key)
            }
        }
        player.play()
        // 兜底定时器: 即使 completionHandler 未触发也能清理
        let dur = Double(buffer.frameLength) / 44100.0 + 0.3
        graphQueue.asyncAfter(deadline: .now() + dur) { [weak self] in
            self?.teardownPlayer(key: key)
        }
    }

    /// 安全移除 player: 只在 player 仍 attached 时操作
    private func teardownPlayer(key: ObjectIdentifier) {
        guard let player = activePlayers.removeValue(forKey: key) else { return }
        // 已被移除则跳过(engine.attachedNodes 是 NSSet 风格, 用 contains 判引用)
        guard engine.attachedNodes.contains(where: { $0 === player }) else { return }
        if started, engine.isRunning {
            player.stop()
            engine.detach(player)
        }
    }
}
