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
            .onAppear {
                viewModel.loadHealthData()
            }
        }
    }
    
    // Helper to format date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Helper to convert sleep stage to a numeric value for charting purposes
    private func stageValue(_ stage: String) -> Int {
        switch stage {
        case "In Bed": return 1
        case "Asleep": return 2
        case "Core Sleep": return 3
        case "Deep Sleep": return 4
        case "REM Sleep": return 5
        default: return 0
        }
    }
}
