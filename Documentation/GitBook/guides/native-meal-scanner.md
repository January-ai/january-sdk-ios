# Native food scanner

The food scanner is a ready-made full-screen camera. In photo mode it runs [food analysis](photo-scanning.md) on the meal; in barcode mode it looks up the barcode and fetches the full food (`foods.get`) for the first match.

## Add camera permission

Add a camera purpose string to your app's `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan meals and food barcodes.</string>
```

Call `try JanuaryFoodScanner.validateHostConfiguration()` before presenting the scanner; it throws `JanuaryFoodScannerConfigurationError.missingCameraUsageDescription` when the string is missing. If you skip the check, the scanner shows an alert instead of the camera.

## SwiftUI

```swift
import January
import SwiftUI

struct ScannerHost: View {
    let client: JanuaryClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        JanuaryFoodScannerView(
            client: client,
            configuration: .init(
                enabledModes: [.photo, .barcode],
                initialMode: .photo
            ),
            onResult: { result in
                switch result {
                case .photo(let image, let analysis):
                    print(image.pixelWidth, analysis.mealName ?? "")
                case .barcode(let value, let food):
                    print(value, food.name ?? "", food.servings.count)
                }
            },
            onCancel: { dismiss() }
        )
    }
}
```

A photo result includes the oriented, resized JPEG that was sent to January and the `FoodScan`. A barcode result includes the barcode and the full food.

## UIKit

```swift
import January
import UIKit

extension UIViewController {
    func presentJanuaryScanner(client: JanuaryClient) {
        let scanner = JanuaryFoodScanner.makeViewController(
            client: client,
            onResult: { result in
                print(result)
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        present(scanner, animated: true)
    }
}
```

The view controller presents full screen. The configuration can enable either mode alone and set the maximum image dimension and JPEG compression quality. Camera capture needs a physical device.

Next: [Food logs](food-logs.md).
