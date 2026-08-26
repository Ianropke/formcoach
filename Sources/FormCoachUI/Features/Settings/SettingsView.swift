import SwiftUI
import FormCoachCore

public struct SettingsView: View {
    @State private var videoRetentionDays: Int = 0 // 0 = Forever
    @State private var storageUsedBytes: Int64 = 0
    @State private var showingDeleteAlert = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("SETTINGS & PRIVACY")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                        .tracking(1.5)
                    
                    Text("Storage & Control")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Privacy Verification Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 18))
                        
                        Text("100% LOCAL PRIVACY GUARANTEE")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                    Text("Your workout videos and skeletal landmarks never leave this iPhone. No cloud servers, no paid AI APIs, no biometric facial recognition.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(3)
                    
                    HStack {
                        Text("Recurring Analysis Cost:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Text("0.00 DKK")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.12))
                .cornerRadius(16)
                .padding(.horizontal, 20)
                
                // Storage Management Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("LOCAL VIDEO STORAGE")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("Storage Used by Videos")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(formatBytes(storageUsedBytes))
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        Button(action: {
                            try? LocalVideoStorage.shared.deleteAllVideos()
                            refreshStorage()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.orange)
                                Text("Clear Recorded Video Files")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                }
                
                // Non-Medical Disclaimer
                VStack(alignment: .leading, spacing: 8) {
                    Text("SAFETY & NON-MEDICAL DISCLAIMER")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text("FormCoach analyzes visible kinematics from camera footage for athletic and educational feedback. It is not a medical device and cannot diagnose musculoskeletal pathology, joint injury, or individual safety.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                        .lineSpacing(3)
                }
                .padding(18)
                .background(Color(white: 0.08))
                .cornerRadius(14)
                .padding(.horizontal, 20)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            refreshStorage()
        }
    }
    
    private func refreshStorage() {
        storageUsedBytes = LocalVideoStorage.shared.calculateStorageUsed()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
