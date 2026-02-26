import SwiftUI

struct SidebarOverlay: View {
    @EnvironmentObject var appState: AppState
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .leading) {
            if appState.sidebarOpen {
                LitterTheme.overlayScrim
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            dragOffset = 0
                            appState.sidebarOpen = false
                        }
                    }

                SessionSidebarView()
                    .frame(width: 300)
                    .offset(x: dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width < 0 {
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if value.translation.width < -80 {
                                        appState.sidebarOpen = false
                                    }
                                    dragOffset = 0
                                }
                            }
                    )
                    .transition(.move(edge: .leading))
            }
        }
    }
}
