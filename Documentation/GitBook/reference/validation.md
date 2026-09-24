# Validation limits

The SDK checks these inputs before it sends a request. Most failures throw a `JanuaryError` with the `.validation` category; portion inputs throw `FoodPortionError`, and the scanner settings are clamped instead. The January API can apply more rules of its own.

| Input | Accepted value |
| --- | --- |
| Autocomplete query | At most 64 characters |
| Autocomplete limit | Integer from 1 through 20 |
| Food search query | 1 through 256 characters |
| Food search limit | 1 through 50 |
| Food search offset | 0 or more |
| Barcode | 6 through 14 ASCII digits |
| Natural-language meal | 1 through 512 characters |
| Restaurant/menu query | 1 through 256 characters |
| Latitude | −90 through 90 |
| Longitude | −180 through 180 |
| Restaurant radius | 1 through 50,000 meters |
| Restaurant limit | Integer from 1 through 100 |
| Food-log `timestampUTC` | ISO 8601 date-time |
| Food-log update | At least one of `foods`, `timestampUTC`, `name` |
| Water amount | 1 through 811.5 fl oz, 0.1 through 101.4 cup, or 30 through 24,000 ml |
| Weight-log weight | 10 through 1,000 lb, or 4.5 through 453.6 kg |
| Water and weight `consumedAtUTC` / `measuredAtUTC` | ISO 8601 date-time |
| Glucose profile `age` | Whole number of years |
| Food analysis correction | Every detection carries its food ID, serving ID, serving quantity, and quantity |
| CGM and historical-food timestamp | ISO 8601 date-time |
| Provider token | Not empty, with a finite `expiresIn` greater than 60 seconds (an `.authentication` error) |
| Portion quantity, in the serving's unit | Finite, greater than 0, and no greater than 10,000 |
| Scanner maximum dimension | Clamped to at least 1 pixel |
| Scanner JPEG quality | Clamped to 0 through 1 |

## Typed units

Glucose profiles use explicit units:

```swift
let height = Height(value: 178, unit: .centimeters)
let weight = Weight(value: 80, unit: .kilograms)
```

Height takes inches or centimeters, and weight takes pounds or kilograms.

## Local portion errors

`FoodPortionError` distinguishes:

* `noServings`
* `servingNotFound`
* `invalidServing`
* `invalidQuantity`

Fetch the full food (`foods.get`) before computing a portion, so every serving is available.
