import SwiftUI
import MapKit

struct GroupSymbol: View {
    private let viewModel: GroupSymbolViewModel

    private var symbol: String { viewModel.symbol }
    private var color: String { viewModel.color }
    private var size: CGFloat { viewModel.size }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .semibold))
            .foregroundStyle(viewModel.tint)
            .frame(width: size, height: size)
            .background(viewModel.tint.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }

    init(symbol: String, color: String, size: CGFloat = 44) {
        viewModel = GroupSymbolViewModel(symbol: symbol, color: color, size: size)
    }
}

