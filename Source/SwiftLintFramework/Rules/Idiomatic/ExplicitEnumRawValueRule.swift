import SourceKittenFramework

public struct ExplicitEnumRawValueRule: ASTRule, OptInRule, ConfigurationProviderRule, AutomaticTestableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "explicit_enum_raw_value",
        name: "Explicit Enum Raw Value",
        description: "Enums should be explicitly assigned their raw values.",
        kind: .idiomatic,
        nonTriggeringExamples: [
            "enum Numbers {\n case int(Int)\n case short(Int16)\n}\n",
            "enum Numbers: Int {\n case one = 1\n case two = 2\n}\n",
            "enum Numbers: Double {\n case one = 1.1\n case two = 2.2\n}\n",
            "enum Numbers: String {\n case one = \"one\"\n case two = \"two\"\n}\n",
            "protocol Algebra {}\nenum Numbers: Algebra {\n case one\n}\n"
        ],
        triggeringExamples: [
            "enum Numbers: Int {\n case one = 10, ↓two, three = 30\n}\n",
            "enum Numbers: NSInteger {\n case ↓one\n}\n",
            "enum Numbers: String {\n case ↓one\n case ↓two\n}\n",
            "enum Numbers: String {\n case ↓one, two = \"two\"\n}\n",
            "enum Numbers: Decimal {\n case ↓one, ↓two\n}\n"
        ]
    )

    public func validate(file: File, kind: SwiftDeclarationKind,
                         dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        guard kind == .enum else {
            return []
        }

        // Check if it's an enum which supports raw values
        let implicitRawValueSet: Set<String> = [
            "Int", "Int8", "Int16", "Int32", "Int64",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Double", "Float", "Float80", "Decimal", "NSNumber",
            "NSDecimalNumber", "NSInteger", "String"
        ]

        let enumInheritedTypesSet = Set(dictionary.inheritedTypes)

        guard !implicitRawValueSet.isDisjoint(with: enumInheritedTypesSet) else {
            return []
        }

        let violations = violatingOffsetsForEnum(dictionary: dictionary)
        return violations.map {
            StyleViolation(ruleDescription: type(of: self).description,
                           severity: configuration.severity,
                           location: Location(file: file, byteOffset: $0))
        }
    }

    private func violatingOffsetsForEnum(dictionary: [String: SourceKitRepresentable]) -> [Int] {
        let locs = substructureElements(of: dictionary, matching: .enumcase)
            .compactMap { substructureElements(of: $0, matching: .enumelement) }
            .flatMap(enumElementsMissingInitExpr)
            .compactMap { $0.offset }

        return locs
    }

    private func substructureElements(of dict: [String: SourceKitRepresentable],
                                      matching kind: SwiftDeclarationKind) -> [[String: SourceKitRepresentable]] {
        return dict.substructure
            .filter { $0.kind.flatMap(SwiftDeclarationKind.init) == kind }
    }

    private func enumElementsMissingInitExpr(
        _ enumElements: [[String: SourceKitRepresentable]]) -> [[String: SourceKitRepresentable]] {
        return enumElements
            .filter { !$0.elements.contains { $0.kind == "source.lang.swift.structure.elem.init_expr" } }
    }
}
