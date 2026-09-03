import Foundation

struct SafariTabDescriptorDecoder {
    static func decode(_ descriptor: NSAppleEventDescriptor) throws -> [SafariTab] {
        guard descriptor.descriptorType == typeAEList else {
            throw SafariAutomationError.malformedResponse
        }

        guard descriptor.numberOfItems > 0 else { return [] }

        var tabs: [SafariTab] = []
        for rowIndex in 1...descriptor.numberOfItems {
            guard let row = descriptor.atIndex(rowIndex),
                  row.descriptorType == typeAEList,
                  row.numberOfItems == 6
            else {
                continue
            }
            guard let windowID = integer(at: 1, in: row),
                  let tabIndex = integer(at: 2, in: row),
                  let windowOrder = integer(at: 3, in: row),
                  let currentTabIndex = integer(at: 6, in: row)
            else {
                continue
            }

            guard let urlString = row.atIndex(5)?.stringValue, !urlString.isEmpty else { continue }
            let title = row.atIndex(4)?.stringValue ?? ""
            tabs.append(
                SafariTab(
                    windowID: windowID,
                    tabIndex: tabIndex,
                    windowOrder: windowOrder,
                    title: title.isEmpty ? urlString : title,
                    urlString: urlString,
                    isCurrentWindow: windowOrder == 1,
                    isCurrentTab: tabIndex == currentTabIndex
                )
            )
        }
        return tabs
    }

    private static func integer(at index: Int, in descriptor: NSAppleEventDescriptor) -> Int? {
        guard let value = descriptor.atIndex(index),
              let coerced = value.coerce(toDescriptorType: typeSInt32)
        else {
            return nil
        }
        return Int(coerced.int32Value)
    }
}
