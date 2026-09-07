import SwiftUI
import Combine
import Speech
import AVFoundation

/// Voice speech recognition engine using Apple's SFSpeechRecognizer and AVAudioEngine.
@MainActor
public final class SpeechRecognizer: ObservableObject {
    public static let shared = SpeechRecognizer()

    @Published public var isRecording: Bool = false
    @Published public var transcript: String = ""
    @Published public var audioLevel: Float = 0.0
    @Published public var errorMessage: String?

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    public var onSpeechCompleted: (@Sendable (String) -> Void)?

    public init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// Starts streaming speech recognition from the default microphone.
    public func startRecording() {
        guard !isRecording else { return }

        errorMessage = nil
        transcript = ""

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // 1. Verify / request Microphone permission
            let micGranted = await PermissionManager.shared.requestMicrophonePermission()
            guard micGranted else {
                self.errorMessage = "Microphone access is required. Please allow it in System Settings > Privacy & Security > Microphone."
                return
            }

            // 2. Verify / request Speech Recognition permission
            let speechGranted = await PermissionManager.shared.requestSpeechRecognitionPermission()
            guard speechGranted else {
                self.errorMessage = "Speech Recognition access is required. Please allow it in System Settings > Privacy & Security > Speech Recognition."
                return
            }

            self.beginAudioEngineRecording()
        }
    }

    private func beginAudioEngineRecording() {
        // Reset audio engine to fresh state if needed
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            errorMessage = "No active audio input device detected. Please check your Mac sound input settings."
            return
        }

        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create speech recognition request."
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let result = result {
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.finishSpeechRecognition()
                    }
                }

                if error != nil {
                    self.stopRecording()
                }
            }
        }

        // Install audio tap
        inputNode.removeTap(onBus: 0)
        let activeRequest = recognitionRequest
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            activeRequest.append(buffer)

            // Calculate audio power level for waveform
            let channels = buffer.floatChannelData
            if let channel = channels?[0] {
                let frameCount = Int(buffer.frameLength)
                var sum: Float = 0.0
                for i in 0..<frameCount {
                    sum += abs(channel[i])
                }
                let avg = sum / Float(frameCount)
                let level = min(1.0, avg * 5.0)
                Task { @MainActor [weak self] in
                    self?.audioLevel = level
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Microphone could not start: \(error.localizedDescription)"
            stopRecording()
        }
    }

    /// Stops listening and tears down audio taps.
    public func stopRecording() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
        audioLevel = 0.0
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finishSpeechRecognition()
            }
        }
    }

    private func finishSpeechRecognition() {
        let final = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopRecording()

        if !final.isEmpty {
            onSpeechCompleted?(final)
        }
    }
}
