import SwiftUI
import Charts

struct TheraVoiceView: View {
    @ObservedObject var viewModel = TheraVoiceViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("TheraVoice")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 20)
                
                // Heart Rate Data Display with Chart
                if !viewModel.heartRateData.isEmpty {
                    Text("Heart Rate Data")
                        .font(.headline)
                        .padding(.vertical)
                    
                    Chart(viewModel.heartRateData, id: \.startDate) { sample in
                        LineMark(
                            x: .value("Time", sample.startDate),
                            y: .value("Heart Rate", sample.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.red)
                        .symbol(Circle())
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.bottom)
                }

                // Sleep Data Display with Chart
                if !viewModel.sleepData.isEmpty {
                    Text("Sleep Data")
                        .font(.headline)
                        .padding(.vertical)
                    
                    Chart(viewModel.sleepData, id: \.startDate) { sample in
                        BarMark(
                            x: .value("Time", sample.startDate),
                            y: .value("Sleep Stage", stageValue(sample.stage))
                        )
                        .foregroundStyle(by: .value("Stage", sample.stage))
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.bottom)
                }
            }
            .padding()
            // Remove onAppear since we're using hardcoded data that loads in init
        }
    }
    
    // Helper to format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Updated helper to match our hardcoded sleep stages
    private func stageValue(_ stage: String) -> Int {
        switch stage.lowercased() {
        case "inbed": return 1
        case "asleep": return 2
        case "awake": return 3
        default: return 0
        }
    }
}
