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

        // Check permissions
        if !PermissionManager.shared.microphoneStatus.isGranted {
            PermissionManager.shared.requestMicrophonePermission()
        }
        if !PermissionManager.shared.speechRecognitionStatus.isGranted {
            PermissionManager.shared.requestSpeechRecognitionPermission()
        }

        errorMessage = nil
        transcript = ""

        // Prepare audio engine & recognizer
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

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

                    // Reset silence timer on new transcription segment
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
            errorMessage = "Audio engine could not start: \(error.localizedDescription)"
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
            Task { @MainActor in
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
