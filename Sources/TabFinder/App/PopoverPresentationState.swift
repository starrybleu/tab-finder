struct PopoverPresentationState: Equatable {
    private(set) var isShown = false

    mutating func toggle() {
        isShown.toggle()
    }

    mutating func show() {
        isShown = true
    }

    mutating func hide() {
        isShown = false
    }

    mutating func escape() {
        hide()
    }
}
