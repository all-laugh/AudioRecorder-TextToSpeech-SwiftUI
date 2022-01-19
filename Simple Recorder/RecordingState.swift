//
//  RecordingState.swift
//  SimpleRecorder
//
//  Created by Xiao Quan on 1/18/22.
//

import Foundation

enum RecordingState: Int, CustomStringConvertible {
	case recording,
		 paused,
		 stopped,
		 playing
	
	var stateName: String {
		let states = ["Audio: Recording", "Audio: Paused", "Audio: Stopped", "Audio: Playing"]
		
		return states[self.rawValue]
	}
	
	var description: String {
		return stateName
	}
	
}
