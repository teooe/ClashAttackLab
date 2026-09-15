import SwiftUI

struct SpellImpactSummaryView: View {
    let analysis: SpellImpactAnalysis

    var body: some View {
        GroupBox("Anteprima incantesimi offensivi") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    metric("Danno utile", String(format: "%.0f", analysis.totalUsefulDamage))
                    metric("Danno sprecato", String(format: "%.0f", analysis.totalWastedDamage))
                    metric("Efficienza", String(format: "%.0f%%", analysis.averageEfficiency * 100))
                    metric("Lanci vuoti", "\(analysis.missedCastCount)")
                }

                ForEach(analysis.entries) { entry in
                    HStack(spacing: 10) {
                        Text(symbol(for: entry.kind))
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 24)
                            .background(color(for: entry.kind))
                            .clipShape(Capsule())
                        Text(name(for: entry.kind))
                            .font(.callout.bold())
                        Text("\(entry.targetCount) bersagli · \(entry.defenseCount) difese · \(entry.wallCount) muri")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(entry.qualityLabel)
                            .font(.caption.bold())
                        Text(String(format: "%.0f%%", entry.efficiency * 100))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func name(for kind: BattleSpellKind) -> String {
        switch kind {
        case .heal: return "Cura"
        case .rage: return "Furia"
        case .freeze: return "Gelo"
        case .lightning: return "Fulmine"
        case .earthquake: return "Terremoto"
        }
    }

    private func symbol(for kind: BattleSpellKind) -> String {
        switch kind {
        case .heal: return "H"
        case .rage: return "R"
        case .freeze: return "F"
        case .lightning: return "L"
        case .earthquake: return "E"
        }
    }

    private func color(for kind: BattleSpellKind) -> Color {
        switch kind {
        case .heal: return .green
        case .rage: return .purple
        case .freeze: return .cyan
        case .lightning: return .yellow
        case .earthquake: return .orange
        }
    }
}
