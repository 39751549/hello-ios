import Foundation
import AVFoundation

/// 程序化音效系统(无需音频文件,实时合成)
///
/// 安全设计:
/// 1) 放弃 AVAudioEngine(其 start() 在无连接节点时抛 NSException,Swift 无法 catch)
/// 2) 改用 AVAudioPlayer(data:) —— init 返回 Optional,绝不抛 NSException
/// 3) 启动时预生成所有音效的 WAV Data 缓存,播放时直接用
/// 4) AVAudioPlayer 在主线程创建/play,播放完成自动回收
final class SoundManager {
    static let shared = SoundManager()

    private var enabled = true
    /// 预生成的 WAV Data 缓存(每个音效一份)
    private var wavCache: [SFX: Data] = [:]
    /// 活跃的 player(防止被回收导致静音)
    private var activePlayers: [AVAudioPlayer] = []
    private let cacheLock = NSLock()

    private init() {
        // 后台预生成所有音效 WAV Data(不阻塞主线程)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.preGenerateAll()
        }
    }

    func setEnabled(_ on: Bool) {
        enabled = on
    }

    // MARK: - 音效类型
    enum SFX: String, CaseIterable {
        case attack, hit, skill, aoe, levelup, coin, death, heal, button, error
    }

    // MARK: - 预生成
    private func preGenerateAll() {
        for sfx in SFX.allCases {
            guard wavCache[sfx] == nil else { continue }
            if let wav = generateWavData(sfx) {
                cacheLock.lock()
                wavCache[sfx] = wav
                cacheLock.unlock()
            }
        }
    }

    // MARK: - 播放
    func play(_ sfx: SFX) {
        guard enabled else { return }
        // 取 WAV Data(缓存命中或现场生成)
        cacheLock.lock()
        let wav = wavCache[sfx]
        cacheLock.unlock()
        if let wav = wav {
            DispatchQueue.main.async { [weak self] in
                self?.playWavData(wav)
            }
        } else {
            // 缓存未命中,后台生成后主线程播放
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self, let wav = self.generateWavData(sfx) else { return }
                self.cacheLock.lock()
                self.wavCache[sfx] = wav
                self.cacheLock.unlock()
                DispatchQueue.main.async { [weak self] in
                    self?.playWavData(wav)
                }
            }
        }
    }

    private func playWavData(_ data: Data) {
        guard enabled else { return }
        // AVAudioPlayer(data:) 返回 Optional,不抛 NSException
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = 0.55
        player.prepareToPlay()
        activePlayers.append(player)
        player.play()
        // 播放完成后移除引用(延迟一点确保播完)
        let dur = player.duration + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) { [weak self] in
            guard let self = self else { return }
            if let idx = self.activePlayers.firstIndex(where: { $0 === player }) {
                self.activePlayers.remove(at: idx)
            }
        }
        // 清理过多的活跃 player(防止异常堆积)
        if activePlayers.count > 16 {
            let toRemove = activePlayers.prefix(activePlayers.count - 12)
            activePlayers.removeFirst(toRemove.count)
        }
    }

    // MARK: - 生成 WAV Data(从合成的 float32 PCM 样本)
    private func generateWavData(_ sfx: SFX) -> Data? {
        let sampleRate: UInt32 = 44100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 32  // IEEE float

        // 合成 PCM 样本
        let samples = synthesizeSamples(sfx)
        guard !samples.isEmpty else { return nil }

        let frameCount = UInt32(samples.count)
        let bytesPerFrame = UInt32(channels) * UInt32(bitsPerSample) / 8
        let dataSize = frameCount * bytesPerFrame
        let byteRate = sampleRate * bytesPerFrame
        let blockAlign = channels * (bitsPerSample / 8)

        var data = Data()
        data.reserveCapacity(Int(44 + dataSize))

        // RIFF header
        data.append("RIFF".data(using: .ascii)!)
        appendUInt32(&data, 36 + dataSize)
        data.append("WAVE".data(using: .ascii)!)
        // fmt chunk
        data.append("fmt ".data(using: .ascii)!)
        appendUInt32(&data, 16)           // chunk size
        appendUInt16(&data, 3)            // IEEE float (format code 3)
        appendUInt16(&data, channels)
        appendUInt32(&data, sampleRate)
        appendUInt32(&data, byteRate)
        appendUInt16(&data, blockAlign)
        appendUInt16(&data, bitsPerSample)
        // data chunk
        data.append("data".data(using: .ascii)!)
        appendUInt32(&data, dataSize)
        // PCM samples (float32 little-endian)
        for s in samples {
            var v = s
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func appendUInt32(_ data: inout Data, _ v: UInt32) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
    }
    private func appendUInt16(_ data: inout Data, _ v: UInt16) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
    }

    // MARK: - 合成 PCM 样本(纯计算,任意线程)
    private func synthesizeSamples(_ sfx: SFX) -> [Float] {
        switch sfx {
        case .attack:
            let n = 4400
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                let freq = 1200 - 900 * t / 0.1
                return Float(exp(-t * 30) * sin(2 * .pi * freq * t) * 0.3)
            }
        case .hit:
            let n = 3000
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                let env = exp(-t * 40)
                let noise = Double.random(in: -1...1) * 0.4
                let tone = sin(2 * .pi * 200 * t) * 0.3
                return Float(env * (noise + tone) * 0.5)
            }
        case .skill:
            let n = 8800
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                let freq = 300 + 800 * t / 0.2
                return Float(exp(-t * 12) * sin(2 * .pi * freq * t) * 0.35)
            }
        case .aoe:
            let n = 13200
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                let env = exp(-t * 8)
                let low = sin(2 * .pi * 80 * t) * 0.5
                let noise = Double.random(in: -1...1) * 0.3
                return Float(env * (low + noise) * 0.6)
            }
        case .levelup:
            let n = 22000
            let notes: [Double] = [523, 659, 784, 1047]
            let noteLen = n / notes.count
            return (0..<n).map { i in
                let noteIdx = min(i / noteLen, notes.count - 1)
                let localT = Double(i % noteLen) / 44100.0
                return Float(exp(-localT * 4) * sin(2 * .pi * notes[noteIdx] * localT) * 0.3)
            }
        case .coin:
            let n = 6000
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                return Float(exp(-t * 10) * (sin(2 * .pi * 1318 * t) + sin(2 * .pi * 1976 * t)) * 0.15)
            }
        case .death:
            let n = 11000
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                let freq = 200 - 150 * t / 0.25
                return Float(exp(-t * 6) * sin(2 * .pi * freq * t) * 0.4)
            }
        case .heal:
            let n = 10000
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                let freq = 400 + 300 * t / 0.23
                return Float(sin(.pi * t / 0.23) * sin(2 * .pi * freq * t) * 0.25)
            }
        case .button:
            let n = 1500
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                return Float(exp(-t * 60) * sin(2 * .pi * 800 * t) * 0.2)
            }
        case .error:
            let n = 8000
            return (0..<n).map { i in
                let t = Double(i) / 44100.0
                return Float(exp(-t * 8) * sin(2 * .pi * 150 * t) * 0.3)
            }
        }
    }
}
