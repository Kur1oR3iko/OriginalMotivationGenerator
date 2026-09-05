import SwiftUI

struct ClockSettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 56
    @ScaledMetric(relativeTo: .body) private var zoneRowHeight: CGFloat = 44
    @Binding var showsDate: Bool
    @Binding var timeZoneIdentifier: String
    var onEditingChanged: (Bool) -> Void = { _ in }
    @FocusState private var isSearching: Bool
    @State private var search = ""
    @State private var showsAllTimeZones = false
    @State private var showsOtherTimeZones = false
    @State private var zoneListTop: CGFloat = 0

    private static let commonZones = ["Etc/UTC", "Asia/Shanghai", "Asia/Tokyo", "Asia/Kolkata",
                                      "Australia/Melbourne", "Europe/London", "Europe/Paris",
                                      "America/New_York", "America/Los_Angeles"]
    private static let cityNames = ["Etc/UTC": "协调世界时", "Asia/Shanghai": "北京 / 上海",
                                    "Asia/Tokyo": "东京", "Asia/Kolkata": "印度",
                                    "Australia/Melbourne": "墨尔本", "Europe/London": "伦敦",
                                    "Europe/Paris": "巴黎", "America/New_York": "纽约",
                                    "America/Los_Angeles": "洛杉矶"]
    private static let allZones = Array(Set(TimeZone.knownTimeZoneIdentifiers + commonZones)).sorted()

    var body: some View {
        GeometryReader { proxy in
            let wideLayout = proxy.size.width >= 900
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: wideLayout ? 48 : 32) {
                    Text("25小时时钟")
                        .font(.system(size: wideLayout ? titleSize : titleSize * 0.75,
                                      weight: .black, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    if wideLayout {
                        HStack(alignment: .top, spacing: 64) {
                            displayControls.frame(maxWidth: .infinity, alignment: .leading)
                            zoneControls(viewportHeight: proxy.size.height).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        displayControls
                        zoneControls(viewportHeight: proxy.size.height)
                    }
                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(.horizontal, wideLayout ? 48 : 28)
                .padding(.top, 36)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: "clockSettingsViewport")
        }
        .foregroundStyle(.black)
        .tint(.black)
        .background(Color.white.ignoresSafeArea())
        .onChange(of: isSearching) { onEditingChanged($0) }
        .onDisappear { onEditingChanged(false) }
    }

    private var displayControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("显示年月日", isOn: $showsDate)
                .font(.title2.bold())
                .toggleStyle(.switch)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let reading = Clock25.reading(at: context.date, timeZone: Clock25.timeZone(for: timeZoneIdentifier))
                ClockMonthCalendar(reading: reading)
            }
            Text("每天多一个小时。")
                .font(.title3.weight(.medium))
            Text("从2000年1月1日00:00 UTC开始计时。一分钟仍是60秒，一小时仍是60分钟，一天是25小时。每周7天，每年12个月，月长与闰年遵循公历。")
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(Color(white: 0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func zoneControls(viewportHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("时区")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            zoneButton("system")

            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                    if showsOtherTimeZones {
                        collapseTimeZones()
                    } else {
                        showsOtherTimeZones = true
                    }
                }
            } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("其他时区")
                            .font(.body.weight(timeZoneIdentifier == "system" ? .regular : .bold))
                        if timeZoneIdentifier != "system" {
                            Text(zoneTitle(timeZoneIdentifier))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if timeZoneIdentifier != "system" {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                    }
                    Image(systemName: showsOtherTimeZones ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("其他时区")
            .accessibilityValue(showsOtherTimeZones ? "已展开" : "已收起")
            .accessibilityAddTraits(timeZoneIdentifier == "system" ? [] : .isSelected)

            if showsOtherTimeZones {
                TextField("搜索城市或时区", text: $search)
                    .focused($isSearching)
                    .submitLabel(.done)
                    .onSubmit { isSearching = false }
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.vertical, 12)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .accessibilityLabel("搜索时区")
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleZones, id: \.self) { identifier in
                            zoneButton(identifier)
                                .frame(minHeight: zoneRowHeight)
                        }
                        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(showsAllTimeZones ? "显示常用时区" : "查看全部时区") {
                                showsAllTimeZones.toggle()
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: zoneRowHeight, alignment: .leading)
                            .buttonStyle(.plain)
                        } else if visibleZones.isEmpty {
                            Text("没有匹配的时区")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: zoneRowHeight, alignment: .leading)
                        }
                    }
                }
                .id("\(showsAllTimeZones)-\(search)")
                // Five standard rows end at Melbourne. On shorter windows use the remaining space.
                .frame(height: min(zoneRowHeight * 5 + 8 * 4,
                                   max(zoneRowHeight, viewportHeight - zoneListTop - 24)))
                .clipped()
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: ZoneListTopKey.self,
                                           value: geometry.frame(in: .named("clockSettingsViewport")).minY)
                })
                .onPreferenceChange(ZoneListTopKey.self) { zoneListTop = $0 }
                .accessibilityIdentifier("otherTimeZoneList")
            }
        }
    }

    private func collapseTimeZones() {
        isSearching = false
        showsOtherTimeZones = false
        showsAllTimeZones = false
        search = ""
    }

    private var visibleZones: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            return Self.allZones.filter {
                $0.localizedCaseInsensitiveContains(query) || zoneTitle($0).localizedCaseInsensitiveContains(query)
            }
        }
        if showsAllTimeZones { return Self.allZones }
        var zones = Self.commonZones
        if timeZoneIdentifier != "system", !zones.contains(timeZoneIdentifier),
           TimeZone(identifier: timeZoneIdentifier) != nil {
            zones.append(timeZoneIdentifier)
        }
        return zones
    }

    private func zoneTitle(_ identifier: String) -> String {
        if identifier == "system" { return "跟随系统" }
        if let city = Self.cityNames[identifier] { return city }
        let localizedName = TimeZone(identifier: identifier)?.localizedName(for: .generic, locale: Locale(identifier: "zh_CN"))
        return localizedName.map { "\($0) · \(identifier)" } ?? identifier
    }

    private func zoneButton(_ identifier: String) -> some View {
        let selected = timeZoneIdentifier == identifier
        return Button {
            timeZoneIdentifier = identifier
            collapseTimeZones()
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(zoneTitle(identifier))
                        .font(.body.weight(selected ? .bold : .regular))
                    if identifier != "system" {
                        Text(identifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ZoneListTopKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ClockMonthCalendar: View {
    private enum Scale: CaseIterable {
        case days, months, years

        var next: Scale {
            switch self {
            case .days: return .months
            case .months: return .years
            case .years: return .days
            }
        }

        var title: String {
            switch self {
            case .days: return "日"
            case .months: return "月"
            case .years: return "年"
            }
        }
    }

    let reading: Clock25.Reading
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: Scale = .days
    @State private var browsedYear: Int?
    @State private var browsedMonth: Int?
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let overviewColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var year: Int { browsedYear ?? reading.year }
    private var month: Int { browsedMonth ?? reading.month }
    private var firstYear: Int { (year / 10) * 10 }
    private var header: String {
        switch scale {
        case .days: return "\(year)年\(month)月"
        case .months: return "\(year)年"
        case .years: return "\(firstYear)–\(firstYear + 11)年"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { scale = scale.next }
                } label: {
                    HStack(spacing: 8) {
                        Text(header).font(.title2.bold())
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("日历范围，\(header)")
                .accessibilityValue("\(scale.title)视图")
                .accessibilityHint("点击切换到\(scale.next.title)视图")
                .accessibilityIdentifier("calendarScaleButton")
                Spacer()
                if year != reading.year || month != reading.month {
                    Button("当前日期") {
                        browsedYear = nil
                        browsedMonth = nil
                        scale = .days
                    }
                    .font(.subheadline)
                    .buttonStyle(.plain)
                } else {
                    Text("\(reading.day)日 · 星期\(weekdays[(reading.weekday + 5) % 7])")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Group {
                switch scale {
                case .days:
                    dayGrid
                case .months:
                    LazyVGrid(columns: overviewColumns, spacing: 12) {
                        ForEach(1...12, id: \.self) { month in
                            overviewCell("\(month)月", selected: year == reading.year && month == reading.month) {
                                browsedMonth = month
                                scale = .days
                            }
                        }
                    }
                case .years:
                    LazyVGrid(columns: overviewColumns, spacing: 12) {
                        ForEach(firstYear..<(firstYear + 12), id: \.self) { year in
                            overviewCell(String(year), selected: year == reading.year) {
                                browsedYear = year
                                scale = .months
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 240, alignment: .top)
        }
        .onChange(of: reading.dateText) { _ in
            browsedYear = nil
            browsedMonth = nil
        }
    }

    private var dayGrid: some View {
        let layout = Clock25.month(year: year, month: month)
        return LazyVGrid(columns: dayColumns, spacing: 8) {
            ForEach(0..<7) { index in
                Text(weekdays[index])
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("星期\(weekdays[index])")
            }
            ForEach(0..<(layout.leadingEmptyDays + layout.numberOfDays), id: \.self) { index in
                if index < layout.leadingEmptyDays {
                    Color.clear.frame(height: 36).accessibilityHidden(true)
                } else {
                    let day = index - layout.leadingEmptyDays + 1
                    let selected = year == reading.year && month == reading.month && day == reading.day
                    Text(String(day))
                        .font(.system(.body, design: .default).weight(selected ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(selected ? Color.white : Color.black)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if selected { Circle().fill(Color.black).frame(width: 36, height: 36) }
                        }
                        .accessibilityLabel(selected ? "\(reading.dateText)，当前日期" : "\(day)日")
                }
            }
        }
    }

    private func overviewCell(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(selected ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(selected ? Color.white : Color.black)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if selected { Capsule().fill(Color.black) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
