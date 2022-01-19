//
//  ContentView.swift
//  SimpleRecorder
//
//  Created by Xiao Quan on 1/18/22.
//

import SwiftUI
import AVFAudio

struct RecorderView: View {
	@ObservedObject var audioManager = AudioManager()
	@State var requestPermission: Bool = false
	@State var permissionGranted: Bool = false
	
    var body: some View {
		TabView {
			// MARK: - Play Tab
			VStack {
				
				Spacer()
				
				if !audioManager.playFromSpeechSynthesizer {
					// Record
					Button {
						if audioManager.recordingStatus == .stopped {
							if permissionGranted {
								audioManager.record()
							} else {
								requestAudioPermission()
							}
						} else {
							audioManager.stop()
						}
					} label: {
						Image(systemName: audioManager.recordingStatus == .recording ?
							  "stop.circle.fill" : "record.circle.fill")
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 100, height: 100)
							.padding()
					}
				} else {
					if #available(iOS 15.0, *) {
						TextEditor(text: $audioManager.textToSpeak)
							.frame(maxHeight: 200)
							.cornerRadius(10)
							.shadow(radius: 10)
							.padding()
					} else {
						// Fallback on earlier versions
					}
				}
				
				// Play
				Button {
					if audioManager.recordingStatus == .stopped {
						print("current status: stopped. Will play recorded audio")
						audioManager.play()
					} else if audioManager.recordingStatus == .playing {
						print("current status: playing. Will stop playing")
						audioManager.stopPlayback()
					} else { 								// recording
						print("current status: recoding. Will stop recording and play")
						audioManager.stop()
						audioManager.play()
					}
				} label: {
					Image(systemName: audioManager.recordingStatus == .playing ?
						  "stop.circle":
							"play.circle")
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 100, height: 100)
						.padding()
				}
				
				Spacer()
				
				if audioManager.recordingStatus != .stopped {
					Text(audioManager.time)
						.font(.custom("courier", size: 18))
						.bold()
				}
				
				Toggle("Play from Speech Synthesizer", isOn: $audioManager.playFromSpeechSynthesizer)
				.padding()
				.padding(.bottom, 50)
			}
			.alert(isPresented: $requestPermission) {
				Alert(title: Text("Permission Denied"),
					  message: Text("Got to settings to enable microphone access"),
					  dismissButton: .default(Text("Ok")))
			}
			.tabItem {
				VStack {
					Image(systemName: "play")
					Text("Play")
				}
			}
			.tag(0)
			

			// MARK: - Settings Tab
			List {
				Text("Settings")
					.font(.headline)
					.bold()
				
				Section(header: Text("Recording Effects")) {
					VStack {
						Slider(value: $audioManager.pitchShift.pitch, in: -2400...2400, step: 100, onEditingChanged: {_ in }, minimumValueLabel: Text("-24"), maximumValueLabel: Text("24"), label: {})
						
						Text("Pitch shift: \(String(format: "%4.0f", audioManager.pitchShift.pitch))")
					}
					
					VStack {
						Slider(value: $audioManager.reverb.wetDryMix, in:0...100, step: 1.0, onEditingChanged: {_ in }, minimumValueLabel: Text("0"), maximumValueLabel: Text("100"), label: {})
						Text("Reverb: \(String(format: "%2.0f", audioManager.reverb.wetDryMix))")
					}
				}
				
				Section(header: Text("Synthesizer Params")) {
					VStack {
						Slider(value: $audioManager.speechRate,
							   in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate,
							   label: {})
						
						Text("Speech Speed: \(String(format: "%1.2f", audioManager.speechRate + 0.5))")
					}
					
					VStack {
						Slider(value: $audioManager.speechPitch,
							   in: 0.5...2.0,
							   label: {})
						
						Text("Speech Pitch: \(String(format: "%1.2f", audioManager.speechPitch))")
					}
				}

			}
			.tabItem {
				VStack {
					Image(systemName: "gear")
					Text("Settings")
				}
			}
			.tag(1)
		}
		.accentColor(.red)
		.foregroundColor(.red)
		.onAppear {
			audioManager.setupRecorder()
			audioManager.prepareEngine()
		}
    }
	
	private func requestAudioPermission() {
		let session = AVAudioSession.sharedInstance()
		session.requestRecordPermission { granted in
			self.permissionGranted = granted
			if granted {
				audioManager.record()
			} else {
				requestPermission = true
			}
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RecorderView()
    }
}
