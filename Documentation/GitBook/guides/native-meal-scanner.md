# Native meal scanner

{% hint style="info" %}
The ready-made camera and barcode UI is available on iOS only. The lower-level photo-scanning resource and image preparation helpers are available to both supported platforms.
{% endhint %}

## Add camera permission

Add a user-facing camera purpose string to the host app's `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan meals and food barcodes.</string>
```

The scanner validates this entry before presenting. Missing configuration throws `JanuaryMealScannerConfigurationError.missingCameraUsageDescription`.

## SwiftUI

```swift
import JanuarySDK
import SwiftUI

struct ScannerHost: View {
    let client: JanuaryClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        JanuaryMealScannerView(
            client: client,
            configuration: .init(
                enabledModes: [.photo, .barcode],
                initialMode: .photo
            ),
            onResult: { result in
                switch result {
                case .meal(let image, let analysis):
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

The meal result includes the orientation-normalized, aspect-preserving JPEG sent to January and the `FoodScan`. Barcode mode performs the barcode lookup and then hydrates the first match with `getFood` before returning it.

## UIKit

```swift
import JanuarySDK
import UIKit

extension UIViewController {
    func presentJanuaryScanner(client: JanuaryClient) {
        let scanner = JanuaryMealScanner.makeViewController(
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
