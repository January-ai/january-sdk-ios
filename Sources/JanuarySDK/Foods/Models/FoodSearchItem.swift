/// A food returned by a food-name search.
public struct FoodSearchItem: Codable, Hashable, Sendable {
    public var id: FoodID
    public var type: FoodCategory
    public var name: String?
    public var brandName: String?
    /// The complete per-primary-serving nutrition returned by January.
    public var nutrients: NutritionFacts?
    public var calories: Double?
    public var protein: Double?
    public var carbohydrates: Double?
    public var netCarbohydrates: Double?
    public var totalFat: Double?
    public var saturatedFat: Double?
    public var fiber: Double?
    public var totalSugars: Double?
    public var addedSugars: Double?
    public var sodium: Double?
    public var potassium: Double?
    public var cholesterol: Double?
    public var glycemicIndex: Double?
    public var glycemicLoad: Double?
    public var photoURL: String?
    public var barcode: String?
    public var servings: [ServingOption]

    public init(
        id: FoodID,
        name: String?,
        type: FoodCategory = .generic,
        brandName: String? = nil,
        nutrients: NutritionFacts? = nil,
        calories: Double? = nil,
        protein: Double? = nil,
        carbohydrates: Double? = nil,
        netCarbohydrates: Double? = nil,
        totalFat: Double? = nil,
        saturatedFat: Double? = nil,
        fiber: Double? = nil,
        totalSugars: Double? = nil,
        addedSugars: Double? = nil,
        sodium: Double? = nil,
        potassium: Double? = nil,
        cholesterol: Double? = nil,
        glycemicIndex: Double? = nil,
        glycemicLoad: Double? = nil,
        photoURL: String? = nil,
        barcode: String? = nil,
        servings: [ServingOption]
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.brandName = brandName
        self.nutrients = nutrients
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.netCarbohydrates = netCarbohydrates
        self.totalFat = totalFat
        self.saturatedFat = saturatedFat
        self.fiber = fiber
        self.totalSugars = totalSugars
        self.addedSugars = addedSugars
        self.sodium = sodium
        self.potassium = potassium
        self.cholesterol = cholesterol
        self.glycemicIndex = glycemicIndex
        self.glycemicLoad = glycemicLoad
        self.photoURL = photoURL
        self.barcode = barcode
        self.servings = servings
    }
}
