import Charts
import SwiftUI

struct PredictionChart: View {
    let points: [ChartPoint]
    let lowerBound: Double?
    let upperBound: Double?
    let lineColor: Color
    var summaryValue: Double?
    var summaryDetail: String?
    var summaryDelta: String?
    var showsPeakAnnotation = true

    init(
        points: [ChartPoint],
        lowerBound: Double?,
        upperBound: Double?,
        lineColor: Color,
        summaryValue: Double? = nil,
        summaryDetail: String? = nil,
        summaryDelta: String? = nil,
        showsPeakAnnotation: Bool = true
    ) {
        self.points = points
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.lineColor = lineColor
        self.summaryValue = summaryValue
        self.summaryDetail = summaryDetail
        self.summaryDelta = summaryDelta
        self.showsPeakAnnotation = showsPeakAnnotation
    }

    var body: some View {
        VStack(spacing: 0) {
            summary
            chart
            timeline
            legend
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.border.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: AppPalette.ink.opacity(0.055), radius: 14, y: 7)
        .accessibilityLabel("Predicted glucose response chart")
        .accessibilityValue(chartAccessibilityValue)
    }

    @ViewBuilder
    private var summary: some View {
        if let summaryValue {
            VStack(alignment: .leading, spacing: 2) {
                    Text("Likely peak")
                        .font(AppTypography.eyebrow)
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.muted)
                    HStack(alignment: .lastTextBaseline, spacing: 9) {
                        Text(summaryValue.formatted(.number.precision(.fractionLength(0))))
                            .font(.system(size: 58, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(lineColor)
                        if let summaryDetail {
                            Text(summaryDetail)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppPalette.body)
                        }
                    }
                    if let summaryDelta {
                        Text(summaryDelta)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(lineColor)
                    }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 2)
        } else {
            HStack(alignment: .firstTextBaseline) {
                    Text("Predicted response")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.muted)
                    Spacer(minLength: 12)
                    Text("mg/dL")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.muted)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 8)
        }
    }

    private var chart: some View {
        Chart {
            if let lowerBound, let upperBound {
                RectangleMark(
                    yStart: .value("Target minimum", lowerBound),
                    yEnd: .value("Target maximum", upperBound)
                )
                .foregroundStyle(AppPalette.targetBand)
            }

            ForEach(displayPoints) { point in
                AreaMark(
                    x: .value("Minutes", point.minutes),
                    yStart: .value("Chart baseline", fillBaseline),
                    yEnd: .value("Predicted glucose", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.24), lineColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Minutes", point.minutes),
                    y: .value("Predicted glucose", point.value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }

            if let mealPoint {
                PointMark(
                    x: .value("Meal", mealPoint.minutes),
                    y: .value("Meal glucose", mealPoint.value)
                )
                .symbol {
                    Circle()
                        .fill(AppPalette.yellow)
                        .stroke(AppPalette.ink, lineWidth: 2.5)
                        .frame(width: 18, height: 18)
                }
                .accessibilityLabel("Meal")
            }

            if let peakPoint {
                PointMark(
                    x: .value("Peak time", peakMarkerMinutes),
                    y: .value("Peak glucose", peakPoint.value)
                )
                .symbol {
                    Circle()
                        .fill(Color.white)
                        .stroke(AppPalette.ink, lineWidth: 2.5)
                        .frame(width: 16, height: 16)
                }
                .annotation(position: .topLeading, spacing: 10) {
                    if displaysPeakAnnotation {
                        VStack(spacing: 1) {
                            Text("Likely peak")
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .tracking(0.7)
                                .foregroundStyle(AppPalette.muted)
                            Text("\(peakPoint.value.formatted(.number.precision(.fractionLength(0)))) · +\(peakPoint.minutes.formatted(.number.precision(.fractionLength(0)))) min")
                                .font(.system(.headline, design: .monospaced, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(AppPalette.ink)
                        }
                        .fixedSize()
                    }
                }
                .accessibilityLabel("Likely peak")
                .accessibilityValue("\(peakPoint.value.formatted()) milligrams per deciliter, \(peakPoint.minutes.formatted()) minutes after the meal")
            }
        }
        .chartXScale(domain: xDomain, range: .plotDimension(startPadding: 18, endPadding: 0))
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plotArea in plotArea.background(Color.white) }
        .frame(height: 205)
    }

    private var timeline: some View {
        HStack {
            ForEach([0, 40, 80, 120], id: \.self) { minutes in
                Text(minutes.formatted())
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppPalette.muted)
                if minutes != 120 { Spacer(minLength: 0) }
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.top, 6)
    }

    private var legend: some View {
        HStack(spacing: 12) {
                legendItem("Prediction") {
                    Capsule().fill(lineColor).frame(width: 24, height: 3.5)
                }
                legendItem("Meal") {
                    Circle().fill(AppPalette.yellow).stroke(AppPalette.ink, lineWidth: 2).frame(width: 12, height: 12)
                }
                if lowerBound != nil, upperBound != nil {
                    legendItem("Target") {
                        RoundedRectangle(cornerRadius: 2).fill(AppPalette.targetBand).frame(width: 22, height: 12)
                    }
                }
                legendItem("Peak") {
                    Circle().fill(Color.white).stroke(AppPalette.ink, lineWidth: 2).frame(width: 12, height: 12)
                }
                Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    private var mealPoint: ChartPoint? {
        displayPoints.min { $0.minutes < $1.minutes }
    }

    private var peakPoint: ChartPoint? {
        displayPoints.max { $0.value < $1.value }
    }

    private var peakMarkerMinutes: Double {
        min(peakPoint?.minutes ?? 0, 116)
    }

    private var displaysPeakAnnotation: Bool {
        showsPeakAnnotation && summaryValue == nil
    }

    private var xDomain: ClosedRange<Double> { 0...120 }

    private var yDomain: ClosedRange<Double> {
        var values = displayPoints.map(\.value)
        if let lowerBound { values.append(lowerBound) }
        if let upperBound { values.append(upperBound) }
        guard let minimum = values.min(), let maximum = values.max() else { return 50...180 }

        let span = max(maximum - minimum, 20)
        let lower = floor((minimum - max(12, span * 0.16)) / 10) * 10
        let upper = ceil((maximum + max(18, span * 0.24)) / 10) * 10
        return lower...upper
    }

    private var fillBaseline: Double { lowerBound ?? yDomain.lowerBound }

    private var displayPoints: [ChartPoint] {
        points.filter { (0...120).contains($0.minutes) }.sorted { $0.minutes < $1.minutes }
    }

    private var chartAccessibilityValue: String {
        guard let peakPoint else { return "No prediction points" }
        return "Likely peak \(peakPoint.value.formatted()) milligrams per deciliter at \(peakPoint.minutes.formatted()) minutes after the meal"
    }

    private func legendItem<Symbol: View>(_ title: String, @ViewBuilder symbol: () -> Symbol) -> some View {
        HStack(spacing: 6) {
            symbol()
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(AppPalette.body)
        }
    }
}

#Preview {
    PredictionChart(
        points: [
            ChartPoint(minutes: 0, value: 82),
            ChartPoint(minutes: 30, value: 96),
            ChartPoint(minutes: 60, value: 132),
            ChartPoint(minutes: 90, value: 156),
            ChartPoint(minutes: 120, value: 124)
        ],
        lowerBound: 70,
        upperBound: 140,
        lineColor: AppPalette.rust,
        summaryValue: 156,
        summaryDetail: "elevated · 60–90 min",
        summaryDelta: "+64 above your usual"
    )
    .padding()
    .background(AppPalette.paper)
}
