import AVFoundation

func test() {
    let player = AVAudioPlayerNode()
    let file = AVAudioFile()
    player.scheduleSegment(file, startingFrame: 0, frameCount: 100, at: nil, completionCallbackType: .dataPlayedBack) { _ in }
}
