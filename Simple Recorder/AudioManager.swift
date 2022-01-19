//
//  AudioRecorder.swift
//  LearningAVFoundation
//
//  Created by Xiao Quan on 1/18/22.
//

import Foundation
import AVFoundation

class AudioManager: NSObject, ObservableObject {
	
	var audioRecorder: AVAudioRecorder?
	var audioPlayer: AVAudioPlayer?
	var updateTimer: CADisplayLink?
	var audioEngine = AVAudioEngine()
	var audioEnginePlayer = AVAudioPlayerNode()
	@Published var pitchShift = AVAudioUnitTimePitch()
	@Published var reverb = AVAudioUnitReverb()
	var recordTime: TimeInterval = 0.0
	var playbackTime: TimeInterval = 0.0
	var fileToPlay: AVAudioFile?
	
	@Published var playFromSpeechSynthesizer = false
	var speechSynthesizer = AVSpeechSynthesizer()
	@Published var textToSpeak: String = "Hello there"
	@Published var speechPitch: Float = 1.0
	@Published var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
	
	@Published var recordingStatus: RecordingState = .stopped
	@Published var time = "00:00:00"
	
	var tempUrl: URL {
		let url = FileManager.default.temporaryDirectory
		let filename = "Temp.caf"
		return url.appendingPathComponent(filename)
	}
	
	override init() {
		super.init()
		let notificationCenter = NotificationCenter.default
		notificationCenter.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
		notificationCenter.addObserver(self, selector: #selector(handleInteruption), name: AVAudioSession.interruptionNotification, object: nil)
		notificationCenter.addObserver(self, selector: #selector(handleAEChange), name: .AVAudioEngineConfigurationChange, object: nil)
		speechSynthesizer.delegate = self
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	@objc func handleAEChange(notification: Notification) {
		if let info = notification.userInfo {
			print(info)
		}
	}
	
	@objc func handleRouteChange(notification: Notification) {
		if let info = notification.userInfo,
		   let rawValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt {
			let reason = AVAudioSession.RouteChangeReason(rawValue: rawValue)
			if reason == .oldDeviceUnavailable {
				guard let previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
					  let previousOutput = previousRoute.outputs.first else {
						  return
					  }
				if previousOutput.portType == .headphones {
					if recordingStatus == .playing {
						stopPlayback()
					} else if recordingStatus == .recording {
						stop()
					}
				}
			}
		}
	}
	
	@objc func handleInteruption(notification: Notification) {
		if let info = notification.userInfo,
		   let rawValue = info[AVAudioSessionInterruptionTypeKey] as? UInt {
			let type = AVAudioSession.InterruptionType(rawValue: rawValue)
			if type == .began {
				if recordingStatus == .playing {
					stopPlayback()
				} else if recordingStatus == .recording {
					stop()
				}
			} else {
				if let rawValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
					let options = AVAudioSession.InterruptionOptions(rawValue: rawValue)
					if options == .shouldResume {
						// restart audio or restart recording
					}
				}
			}
		}
	}
	
	func prepareEngine() {
		let format = audioEngine.outputNode.inputFormat(forBus: 0)
		print(format.sampleRate)
		print(AVAudioSession.sharedInstance().sampleRate)
		audioEngine.attach(audioEnginePlayer)
		audioEngine.attach(pitchShift)
		audioEngine.attach(reverb)
		audioEngine.connect(audioEnginePlayer, to: pitchShift, format: format)
		audioEngine.connect(pitchShift, to: reverb, format: format)
		audioEngine.connect(reverb, to: audioEngine.outputNode, format: format)

		reverb.loadFactoryPreset(.cathedral)
		pitchShift.pitch = 0.0
		reverb.wetDryMix = 50

			audioEngine.prepare()
		print("AudioEngine is prepare to start")
	}
	
	func startEngine() {
		do {
			try audioEngine.start()
			print("Audio Engine prepared and running: ", audioEngine.isRunning)
		} catch {
			print("AudioEngine start failed: ", error.localizedDescription)
		}
	}
	
	func setupRecorder() {
		let settings: [String: Any] = [
			AVFormatIDKey : Int(kAudioFormatLinearPCM),
			AVSampleRateKey : 44100.0,
			AVNumberOfChannelsKey : 2,
			AVEncoderAudioQualityKey : AVAudioQuality.high.rawValue
		]
		do {
			try audioRecorder = AVAudioRecorder(url: tempUrl, settings: settings)
			audioRecorder?.delegate = self
		} catch {
			print("Error creating audio recorder with format: \(error.localizedDescription)")
		}
		
	}
	
	func record() {
		if let recorder = audioRecorder {
			recorder.record()
		}
		recordingStatus = .recording
		startUpdateLoop()
		print("record(): ", audioEngine.isRunning)
	}
	
	func stop() {
		if let recorder = audioRecorder {
			recorder.stop()
			
		}
		recordingStatus = .stopped
		stopLoop()
		print("stop(): ", audioEngine.isRunning)
	}
	
	func play() {
		if playFromSpeechSynthesizer {
			let utterance = AVSpeechUtterance(string: textToSpeak)
			utterance.voice = AVSpeechSynthesisVoice(language: "en-AU")
			utterance.pitchMultiplier = speechPitch
			utterance.rate = speechRate
			
			speechSynthesizer.speak(utterance)
			
		} else {
			print("play() 1. Engine running? ", audioEngine.isRunning)
			do {
				fileToPlay = try AVAudioFile(forReading: tempUrl)
			} catch {
				print("Error Loading Audio File as AVAudioFile")
			}
			
			guard fileToPlay != nil else { return }
			audioEnginePlayer.scheduleFile(fileToPlay!, at: nil, completionHandler: nil)
			
			do {
				try audioPlayer = AVAudioPlayer(contentsOf: tempUrl)
				audioPlayer?.delegate = self
			} catch {
				print("Error loading audio file from temp directory")
			}
			
			guard audioPlayer != nil else { return }
			if audioPlayer!.duration > 0 {
				audioPlayer!.volume = 0
				audioPlayer!.prepareToPlay()
			}
			
			startEngine()
			print("play() 2. Engine running? ", audioEngine.isRunning)
			
			guard audioEngine.isRunning else { return }
			
			audioPlayer!.play()
			audioEnginePlayer.play()
			recordingStatus = .playing
			startUpdateLoop()
		}
	}
	
	func stopPlayback() {
		audioPlayer?.stop()
		audioEnginePlayer.stop()
		speechSynthesizer.stopSpeaking(at: .immediate)
		recordingStatus = .stopped
		stopLoop()
	}
	
	func startUpdateLoop() {
		if let updateTimer = updateTimer {
			updateTimer.invalidate()
		}
		updateTimer = CADisplayLink(target: self, selector: #selector(updateLoop))
		updateTimer?.add(to: .current, forMode: .common)
	}
	
	func stopLoop() {
		updateTimer?.invalidate()
		updateTimer = nil
		time = "00:00:00"
	}
	
	@objc func updateLoop() {
		if recordingStatus == .recording {
			if CFAbsoluteTimeGetCurrent() - recordTime > 0.5 {
//				print(audioRecorder?.currentTime)
				time = formatTime(UInt(audioRecorder?.currentTime ?? 0))
				recordTime = CFAbsoluteTimeGetCurrent()
			}
		} else if recordingStatus == .playing {
			if CFAbsoluteTimeGetCurrent() - playbackTime > 0.5 {
//				print(audioEnginePlayer.lastRenderTime?.audioTimeStamp.mHostTime)
				time = formatTime(UInt(audioPlayer?.currentTime ?? 0))
				playbackTime = CFAbsoluteTimeGetCurrent()
			}
		}
	}
	
	private func formatTime(_ time: UInt) -> String {
		let hour = time / 3600
		let minute = (time / 60) % 60
		let seconds = time % 60
		
		return String(format: "%02i:%02i:%02i", hour, minute, seconds)
	}
	
}

extension AudioManager: AVAudioRecorderDelegate {
	func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		recordingStatus = .stopped
	}
}

extension AudioManager: AVAudioPlayerDelegate {
	func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
		print("Audio Player finished playing")
		recordingStatus = .stopped
	}

}

extension AudioManager: AVSpeechSynthesizerDelegate {
	func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
	}
	
	func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
		recordingStatus = .playing
	}
	
	func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
		recordingStatus = .stopped
	}
}
