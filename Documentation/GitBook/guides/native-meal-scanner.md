# Native food scanner

{% hint style="info" %}
The January SDK is iOS-only and supports iOS 15 or later. The ready-made scanner uses native SwiftUI, UIKit, AVFoundation, and Vision APIs.
{% endhint %}

## Add camera permission

Add a user-facing camera purpose string to the host app's `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan meals and food barcodes.</string>
```

The scanner validates this entry before presenting. Missing configuration throws `JanuaryFoodScannerConfigurationError.missingCameraUsageDescription`.

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
                    print(image.pixelWidth, analysis.mealName as Any)
                case .barcode(let value, let food):
                    print(value, food.name, food.servings.count)
                }
            },
            onCancel: { dismiss() }
        )
    }
}
```

The meal result includes the orientation-normalized, aspect-preserving JPEG sent to January and the `FoodScan`. Barcode mode performs the barcode lookup and then hydrates the first match with `get` before returning it.

With client-token authentication, January derives identity from the token. You do not need to pass `endUserID` to the scanner; if supplied, the SDK removes that header before sending the request.

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

The view controller uses full-screen presentation. The configuration can enable either mode alone and can customize maximum image dimension and JPEG compression quality.

## Simulator behavior

Camera capture requires a physical device. The repository demo supplies a sample-meal path for simulator testing; that sample behavior belongs to the demo, not the SDK scanner API.
