import SwiftUI
import AVFoundation
import AVKit
import FormCoachCore

#if os(iOS)
import UIKit
#endif

public struct VideoPosePlayerView: View {
    public let videoURL: URL?
    public let timeSeries: PoseTimeSeries?
    @Binding public var currentPlaybackTime: TimeInterval
    
    @State private var isPlaying = false
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    
    public init(
        videoURL: URL?,
        timeSeries: PoseTimeSeries?,
        currentPlaybackTime: Binding<TimeInterval>
    ) {
        self.videoURL = videoURL
        self.timeSeries = timeSeries
        self._currentPlaybackTime = currentPlaybackTime
    }
    
    public var body: some View {
        ZStack {
            // 1. Native Video Player
            if let p = player {
                VideoPlayer(player: p)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color(white: 0.08)
                    .edgesIgnoringSafeArea(.all)
            }
            
            // 2. Synchronized Skeleton Overlay
            if let ts = timeSeries, let frame = ts.frame(at: currentPlaybackTime) {
                SkeletonCanvasView(
                    poseFrame: frame,
                    highlightJoints: [.leftKnee, .rightKnee, .leftHip, .rightHip],
                    jointColor: .green
                )
                .edgesIgnoringSafeArea(.all)
                
                // Real-time Angle Overlay Badge at Knee
                if let kneePoint = frame.point(for: .leftKnee) ?? frame.point(for: .rightKnee) {
                    GeometryReader { geo in
                        let screenPt = CoordinateNormalizer.denormalize(point: kneePoint, viewSize: geo.size)
                        
                        if let angle = extractKneeAngle(from: frame) {
                            Text("\(Int(angle))°")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green)
                                .cornerRadius(6)
                                .position(x: screenPt.x + 28, y: screenPt.y - 12)
                        }
                    }
                }
            }
            
            // 3. Play / Pause Control Button
            VStack {
                Spacer()
                
                HStack {
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Text(String(format: "%.1fs / %.1fs", currentPlaybackTime, timeSeries?.duration ?? 0.0))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 380)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
        .onChange(of: currentPlaybackTime) { _, newTime in
            seek(to: newTime)
        }
    }
    
    private func setupPlayer() {
        guard let url = videoURL else { return }
        let p = AVPlayer(url: url)
        self.player = p
        
        let interval = CMTime(seconds: 0.033, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if isPlaying {
                currentPlaybackTime = time.seconds
            }
        }
    }
    
    private func teardownPlayer() {
        if let observer = timeObserver, let p = player {
            p.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
    }
    
    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }
    
    private func seek(to time: TimeInterval) {
        guard !isPlaying, let p = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        p.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func extractKneeAngle(from frame: PoseFrame) -> Double? {
        let leftHip = frame.joints[.leftHip]?.point2D
        let leftKnee = frame.joints[.leftKnee]?.point2D
        let leftAnkle = frame.joints[.leftAnkle]?.point2D
        
        guard let h = leftHip, let k = leftKnee, let a = leftAnkle else { return nil }
        return AngleCalculator.angle2D(pointA: h, vertexB: k, pointC: a)
    }
}
