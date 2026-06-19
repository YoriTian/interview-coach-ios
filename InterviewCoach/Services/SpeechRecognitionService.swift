import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var authorizationStatus = SFSpeechRecognizerAuthorizationStatus.notDetermined
    @Published var seconds = 0
    @Published var expressionMetrics = ExpressionMetrics()

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timer: Timer?
    private var hasAudioTap = false

    init() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    }

    func requestAuthorization() {
        Task { [weak self] in
            let status = await SpeechAuthorizationRequester.requestSpeechAuthorization()
            await MainActor.run {
                self?.authorizationStatus = status
            }
        }
    }

    func toggle() async throws {
        if isRecording {
            stopRecording()
        } else {
            try await startRecording()
        }
    }

    func startRecording() async throws {
        switch authorizationStatus {
        case .authorized:
            break
        case .notDetermined:
            let status = await SpeechAuthorizationRequester.requestSpeechAuthorization()
            authorizationStatus = status
            guard status == .authorized else {
                throw SpeechRecognitionError.authorizationDenied
            }
        case .denied, .restricted:
            throw SpeechRecognitionError.authorizationDenied
        @unknown default:
            throw SpeechRecognitionError.recognizerUnavailable
        }

        guard await SpeechAuthorizationRequester.requestMicrophonePermission() else {
            throw SpeechRecognitionError.microphonePermissionDenied
        }

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        task?.cancel()
        task = nil
        seconds = 0
        expressionMetrics = ExpressionMetrics()

        try startLiveRecognition(with: recognizer)
    }

#if targetEnvironment(simulator)
    private func startLiveRecognition(with _: SFSpeechRecognizer) throws {
        throw SpeechRecognitionError.simulatorMicrophoneUnavailable
    }
#else
    private func startLiveRecognition(with recognizer: SFSpeechRecognizer) throws {
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        guard audioSession.isInputAvailable else {
            throw SpeechRecognitionError.microphoneUnavailable
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        request = recognitionRequest

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format,
            block: SpeechAuthorizationRequester.makeAudioBufferHandler(for: recognitionRequest)
        )
        hasAudioTap = true

        do {
            engine.prepare()
            try engine.start()
        } catch {
            stopRecording()
            throw error
        }
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.seconds += 1
                self.expressionMetrics = ExpressionMetrics.detect(
                    in: self.transcript,
                    durationSeconds: self.seconds
                )
            }
        }

        task = recognizer.recognitionTask(
            with: recognitionRequest,
            resultHandler: SpeechAuthorizationRequester.makeRecognitionHandler(for: self)
        )
    }
#endif

    func stopRecording() {
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            if hasAudioTap {
                engine.inputNode.removeTap(onBus: 0)
                hasAudioTap = false
            }
        }
        request?.endAudio()
        request = nil
        task = nil
        audioEngine = nil
        isRecording = false
        timer?.invalidate()
        timer = nil
        expressionMetrics = ExpressionMetrics.detect(in: transcript, durationSeconds: seconds)
    }
}

private enum SpeechAuthorizationRequester {
    static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    static func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { isGranted in
                    continuation.resume(returning: isGranted)
                }
            }
        @unknown default:
            return false
        }
    }

    static func makeAudioBufferHandler(
        for request: SFSpeechAudioBufferRecognitionRequest
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
        }
    }

    static func makeRecognitionHandler(
        for service: SpeechRecognitionService
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak service] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true

            Task { @MainActor in
                if let transcript {
                    service?.transcript = transcript
                    if let service {
                        service.expressionMetrics = ExpressionMetrics.detect(
                            in: transcript,
                            durationSeconds: service.seconds
                        )
                    }
                }
                if error != nil || isFinal {
                    service?.stopRecording()
                }
            }
        }
    }
}

enum SpeechRecognitionError: LocalizedError {
    case authorizationDenied
    case microphonePermissionDenied
    case microphoneUnavailable
    case simulatorMicrophoneUnavailable
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "语音识别权限未开启，请到系统设置里允许语音识别。"
        case .microphonePermissionDenied:
            return "麦克风权限未开启，请到系统设置里允许麦克风。"
        case .microphoneUnavailable:
            return "当前没有可用麦克风，请检查系统输入设备后再试。"
        case .simulatorMicrophoneUnavailable:
            return "模拟器暂不启动真实录音，避免系统音频输入崩溃；请在真机上使用语音练习。"
        case .recognizerUnavailable:
            return "当前设备暂时无法使用中文语音识别，请稍后重试或直接输入文字。"
        }
    }
}
