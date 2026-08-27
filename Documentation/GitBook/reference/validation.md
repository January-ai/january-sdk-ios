# Validation limits

The SDK rejects these invalid inputs before transport where validation is implemented locally. The Partner API may apply additional contract rules.

| Input | Accepted value |
| --- | --- |
| Autocomplete query | At most 64 characters |
| Autocomplete limit | Integer from 1 through 20 |
| Food search query | 1 through 256 characters |
| Food search limit | 1 through 40 |
| Barcode | 6 through 14 ASCII digits |
| Natural-language meal | 1 through 512 characters |
| Restaurant/menu query | 1 through 256 characters |
| Latitude | −90 through 90 |
| Longitude | −180 through 180 |
| Restaurant radius | 1 through 17,000 meters |
| Restaurant limit | Integer from 1 through 100 |
| Food-log `timestampUTC` | ISO-8601 date-time |
| CGM and historical-food timestamp | ISO-8601 date-time |
| Provider token | Nonempty with finite `expiresIn` greater than 60 seconds |
| Portion quantity | Finite, greater than 0, and no greater than 10,000 |
| Scanner maximum dimension | Clamped to at least 1 pixel |
| Scanner JPEG quality | Clamped to 0 through 1 |

## Typed units

Glucose profiles use explicit units:

```swift
let height = Height(value: 178, unit: .centimeters)
let weight = Weight(value: 80, unit: .kilograms)
```

Supported height units are inches and centimeters. Supported weight units are pounds and kilograms. The demo presents imperial height as feet plus inches, then converts that display to total inches for the request.

## Local portion errors

`FoodPortionError` distinguishes:

* `noServings`
* `servingNotFound`
* `invalidServing`
* `invalidQuantity`

Hydrate the food before calculating a portion to avoid attempting selection from an incomplete discovery record.
