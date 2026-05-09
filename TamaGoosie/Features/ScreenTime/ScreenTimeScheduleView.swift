import SwiftUI

struct ScreenTimeScheduleView: View {
    @State private var manager = ScreenTimeManager.shared

    @State private var limitMinutes: Int
    @State private var isAllDay: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var activeDays: Set<Int>

    let onSave: () -> Void

    init(onSave: @escaping () -> Void) {
        let m = ScreenTimeManager.shared
        _limitMinutes = State(initialValue: m.userLimitMinutes)
        _isAllDay = State(initialValue: m.isAllDay)
        _activeDays = State(initialValue: m.activeDays)

        var startComps = DateComponents()
        startComps.hour = m.scheduleStartHour
        startComps.minute = m.scheduleStartMinute
        _startTime = State(initialValue: Calendar.current.date(from: startComps) ?? Date())

        var endComps = DateComponents()
        endComps.hour = m.scheduleEndHour
        endComps.minute = m.scheduleEndMinute
        _endTime = State(initialValue: Calendar.current.date(from: endComps) ?? Date())

        self.onSave = onSave
    }

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 16) {
            GoosieCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Limit")
                        .font(GoosieTheme.bodyFont(15))
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                    Stepper(
                        "\(limitMinutes) minutes",
                        value: $limitMinutes,
                        in: 15...120,
                        step: 15
                    )
                    .font(GoosieTheme.captionFont(13))
                    Text("Apps will be blocked after this limit")
                        .font(GoosieTheme.captionFont(12))
                        .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.5))
                }
            }

            GoosieCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Schedule")
                            .font(GoosieTheme.bodyFont(15))
                            .foregroundStyle(GoosieTheme.charcoalOutline)
                        Spacer()
                        HStack(spacing: 6) {
                            Text("All the time")
                                .font(GoosieTheme.captionFont(13))
                                .foregroundStyle(GoosieTheme.charcoalOutline.opacity(0.6))
                            Toggle("", isOn: $isAllDay)
                                .labelsHidden()
                                .tint(GoosieTheme.skyBlue)
                        }
                    }

                    if !isAllDay {
                        VStack(spacing: 0) {
                            HStack {
                                Text("From")
                                    .font(GoosieTheme.captionFont(14))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Spacer()
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 10)

                            Divider()

                            HStack {
                                Text("To")
                                    .font(GoosieTheme.captionFont(14))
                                    .foregroundStyle(GoosieTheme.charcoalOutline)
                                Spacer()
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 10)
                        }

                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                let isActive = activeDays.contains(day)
                                Button {
                                    if isActive {
                                        activeDays.remove(day)
                                    } else {
                                        activeDays.insert(day)
                                    }
                                } label: {
                                    Text(dayLabels[day - 1])
                                        .font(GoosieTheme.bodyFont(14))
                                        .foregroundStyle(isActive ? .white : GoosieTheme.charcoalOutline)
                                        .frame(width: 38, height: 38)
                                        .background(
                                            Circle()
                                                .fill(isActive ? GoosieTheme.skyBlue : GoosieTheme.charcoalOutline.opacity(0.1))
                                        )
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }

            Button(action: save) {
                Text("Save")
                    .font(GoosieTheme.bodyFont(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(GoosieTheme.skyBlue, in: RoundedRectangle(cornerRadius: GoosieTheme.cornerRadius))
            }
            .padding(.top, 8)
        }
    }

    private func save() {
        manager.userLimitMinutes = limitMinutes
        manager.isAllDay = isAllDay

        if !isAllDay {
            let startComps = Calendar.current.dateComponents([.hour, .minute], from: startTime)
            manager.scheduleStartHour = startComps.hour ?? 8
            manager.scheduleStartMinute = startComps.minute ?? 0
            let endComps = Calendar.current.dateComponents([.hour, .minute], from: endTime)
            manager.scheduleEndHour = endComps.hour ?? 22
            manager.scheduleEndMinute = endComps.minute ?? 0
        }

        manager.activeDays = activeDays
        manager.startDailyMonitoring()
        onSave()
    }
}
