import HealthKit
import SwiftUI

/// after the plan offer: sex, height and weight (typed or imported from Apple Health), where and
/// with what the person trains, and past injuries. Access Finn waits for the training setup and
/// the injury history, then the app opens
struct AboutYouView: View {
    @Binding var profile: OnboardingProfile
    let back: () -> Void
    let finish: () -> Void

    @State private var editing: BodyValue?
    /// true once Apple Health gave at least one value
    @State private var importedFromHealth = false
    @FocusState private var injuriesFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum BodyValue: Identifiable {
        case height
        case weight
        var id: Self {
            self
        }
    }

    private static let usesUSUnits = Locale.current.measurementSystem == .us

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OnboardingBackButton(action: back)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    if HealthProfileImport.isAvailable {
                        health
                    }
                    section("Your details")
                    sexField
                    Button { editing = .height } label: {
                        fieldRow("Height", value: height.map(format), placeholder: "Add height")
                    }
                    .accessibilityIdentifier("aboutYou.height")
                    Button { editing = .weight } label: {
                        fieldRow("Weight", value: weight.map(format), placeholder: "Add weight")
                    }
                    .accessibilityIdentifier("aboutYou.weight")
                    section("Training setup")
                    locationField
                    equipmentField
                    section("Past injuries")
                    FinnReaction(
                        line: String(
                            localized: "Training is a marathon, not a sprint. Tell me what I should keep in mind."
                        ),
                        speaks: true
                    )
                    .padding(.bottom, 8)
                    injuriesField
                    noInjuriesToggle
                    access
                }
                .buttonStyle(PressableStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(item: $editing) { value in
            switch value {
            case .height:
                BodyValueSheet(
                    title: "Height",
                    options: Self.heightOptions,
                    usage: .personHeight,
                    initial: height ?? Self.heightOptions[Self.heightOptions.count / 2]
                ) {
                    profile.heightCentimeters = Int($0.converted(to: .centimeters).value.rounded())
                }
            case .weight:
                BodyValueSheet(
                    title: "Weight",
                    options: Self.weightOptions,
                    usage: .personWeight,
                    initial: weight ?? Self.weightOptions[Self.weightOptions.count / 4]
                ) {
                    profile.weightKilograms = ($0.converted(to: .kilograms).value * 10).rounded() / 10
                }
            }
        }
    }

    // MARK: Sections

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A little more about you.")
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("A few details help me build training that fits you.")
                .font(.body)
                .foregroundStyle(HomeStyle.supportingText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    /// Connect Apple Health, or once values came back, the connected state
    private var health: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { Task { await importFromHealth() } } label: {
                Text(importedFromHealth ? "Apple Health connected" : "Connect Apple Health")
                    .font(.headline)
                    .foregroundStyle(importedFromHealth ? Color.primary : HomeStyle.onAccent)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(importedFromHealth ? HomeStyle.card : HomeStyle.filledAccent, in: Capsule())
                    .contentShape(Capsule())
            }
            .accessibilityHint(importedFromHealth ? "Imports sex, height and weight again" : "")
            .accessibilityIdentifier("aboutYou.health")
            VStack(alignment: .leading, spacing: 4) {
                Text(importedFromHealth ? "Sex, height and weight imported. You can edit them."
                    : "Import sex, height and weight, or enter them below.")
                if importedFromHealth && !profile.aboutYouIsComplete {
                    Text("Your training details still need your input.")
                }
            }
            .font(.subheadline)
            .foregroundStyle(HomeStyle.supportingText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 28)
    }

    private func section(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.title2.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    private var sexField: some View {
        Menu {
            Picker("Sex", selection: $profile.sex) {
                ForEach(BodySex.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
            }
        } label: {
            fieldRow("Sex", value: profile.sex?.title, placeholder: "Select")
        }
        .accessibilityIdentifier("aboutYou.sex")
    }

    private var locationField: some View {
        Menu {
            Picker("Training location", selection: $profile.location) {
                ForEach(TrainingLocation.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
            }
        } label: {
            fieldRow(
                "Training location",
                value: profile.location?.title,
                placeholder: "Choose where you train"
            )
        }
        .accessibilityIdentifier("aboutYou.location")
    }

    /// several at once: the menu stays open while the person ticks
    private var equipmentField: some View {
        Menu {
            ForEach(TrainingEquipment.allCases, id: \.self) { item in
                Toggle(item.title, isOn: equipmentBinding(item))
            }
        } label: {
            fieldRow(
                "Available equipment",
                value: profile.equipment.isEmpty ? nil : profile.equipment.map(\.title)
                    .formatted(.list(type: .and)),
                placeholder: "Choose your equipment"
            )
        }
        .menuActionDismissBehavior(.disabled)
        .accessibilityIdentifier("aboutYou.equipment")
    }

    private var injuriesField: some View {
        TextField("Past injuries or areas to be careful with", text: $profile.injuries, axis: .vertical)
            .lineLimit(3 ... 8)
            .focused($injuriesFocused)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onChange(of: profile.injuries) { _, text in
                // writing an injury and "No past injuries" can't both be true
                if
                    !text.trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty {
                    profile.noPastInjuries = false
                }
            }
            .accessibilityIdentifier("aboutYou.injuries")
    }

    private var noInjuriesToggle: some View {
        Button {
            profile.noPastInjuries.toggle()
            if profile.noPastInjuries {
                profile.injuries = ""
                injuriesFocused = false
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: profile.noPastInjuries ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(profile.noPastInjuries ? DashboardStyle.accent : HomeStyle
                        .supportingText)
                    .accessibilityHidden(true)
                Text("No past injuries")
                    .font(.body)
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .accessibilityAddTraits(profile.noPastInjuries ? .isSelected : [])
        .finnFeedback(.selection, trigger: profile.noPastInjuries)
        .accessibilityIdentifier("aboutYou.noInjuries")
    }

    /// the end of the page: what is still missing, then Access Finn
    private var access: some View {
        let complete = profile.aboutYouIsComplete
        return VStack(alignment: .leading, spacing: 16) {
            if !complete {
                Text("Choose your training setup and injury history to continue.")
                    .font(.footnote)
                    .foregroundStyle(HomeStyle.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: finish) {
                PrimaryActionLabel(title: "Access Finn")
            }
            .disabled(!complete)
            .opacity(complete ? 1 : 0.4)
            .accessibilityIdentifier("aboutYou.access")
        }
        .padding(.top, 20)
    }

    /// a label, the value or a grey prompt, and a chevron, on a rounded card
    private func fieldRow(
        _ label: LocalizedStringKey,
        value: String?,
        placeholder: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(HomeStyle.supportingText)
                Group {
                    if let value {
                        Text(value).foregroundStyle(Color.primary)
                    } else {
                        Text(placeholder).foregroundStyle(HomeStyle.supportingText)
                    }
                }
                .font(.headline)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeStyle.supportingText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // MARK: Values

    private func equipmentBinding(_ item: TrainingEquipment) -> Binding<Bool> {
        Binding {
            profile.equipment.contains(item)
        } set: { isOn in
            if isOn {
                // "None, bodyweight only" and the rest exclude each other
                profile.equipment.removeAll { item == .none || $0 == .none }
                profile.equipment.append(item)
            } else {
                profile.equipment.removeAll { $0 == item }
            }
        }
    }

    private var height: Measurement<UnitLength>? {
        profile.heightCentimeters.map {
            let value = Measurement(value: Double($0), unit: UnitLength.centimeters)
            return Self.usesUSUnits ? Measurement(
                value: value.converted(to: .inches).value.rounded(),
                unit: .inches
            ) : value
        }
    }

    private var weight: Measurement<UnitMass>? {
        profile.weightKilograms.map {
            let value = Measurement(value: $0, unit: UnitMass.kilograms)
            return Self.usesUSUnits ? Measurement(
                value: value.converted(to: .pounds).value.rounded(),
                unit: .pounds
            ) : value
        }
    }

    private func format(_ value: Measurement<UnitLength>) -> String {
        value.formatted(.measurement(width: .abbreviated, usage: .personHeight))
    }

    private func format(_ value: Measurement<UnitMass>) -> String {
        value.formatted(.measurement(
            width: .abbreviated,
            usage: .personWeight,
            numberFormatStyle: .number.precision(.fractionLength(0 ... 1))
        ))
    }

    private static let heightOptions: [Measurement<UnitLength>] = usesUSUnits
        ? (48 ... 90).map { Measurement(value: Double($0), unit: .inches) }
        : (120 ... 220).map { Measurement(value: Double($0), unit: .centimeters) }

    private static let weightOptions: [Measurement<UnitMass>] = usesUSUnits
        ? (66 ... 440).map { Measurement(value: Double($0), unit: .pounds) }
        : (30 ... 200).map { Measurement(value: Double($0), unit: .kilograms) }

    private func importFromHealth() async {
        let values = await HealthProfileImport.read()
        withAnimation(reduceMotion ? nil : HomeStyle.spring) {
            if let sex = values.sex {
                profile.sex = sex
            }
            if let height = values.heightCentimeters {
                profile.heightCentimeters = height
            }
            if let weight = values.weightKilograms {
                profile.weightKilograms = weight
            }
            importedFromHealth = importedFromHealth || values.sex != nil
                || values.heightCentimeters != nil || values.weightKilograms != nil
        }
    }
}

/// a wheel of heights or weights in the person's units, kept when Done is tapped
private struct BodyValueSheet<UnitType: Dimension>: View {
    let title: LocalizedStringKey
    let options: [Measurement<UnitType>]
    let usage: MeasurementFormatUnitUsage<UnitType>
    let done: (Measurement<UnitType>) -> Void
    @State private var selection: Measurement<UnitType>
    @Environment(\.dismiss) private var dismiss

    init(
        title: LocalizedStringKey,
        options: [Measurement<UnitType>],
        usage: MeasurementFormatUnitUsage<UnitType>,
        initial: Measurement<UnitType>,
        done: @escaping (Measurement<UnitType>) -> Void
    ) {
        self.title = title
        self.options = options
        self.usage = usage
        self.done = done
        // the wheel starts on the saved value, or the closest option to it
        let closest = options.min { abs($0.value - initial.value) < abs($1.value - initial.value) } ?? initial
        _selection = State(initialValue: closest)
    }

    var body: some View {
        NavigationStack {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option.formatted(.measurement(width: .abbreviated, usage: usage))).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        done(selection)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// sex, height and weight, read once from Apple Health when the person asks. Only the values
/// copied into the answers are kept
enum HealthProfileImport {
    struct Values {
        var sex: BodySex?
        var heightCentimeters: Int?
        var weightKilograms: Double?
    }

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    static func read() async -> Values {
        let store = HKHealthStore()
        let height = HKQuantityType(.height)
        let bodyMass = HKQuantityType(.bodyMass)
        try? await store.requestAuthorization(
            toShare: [],
            read: [HKCharacteristicType(.biologicalSex), height, bodyMass]
        )
        var values = Values()
        switch (try? store.biologicalSex())?.biologicalSex {
        case .female?:
            values.sex = .female
        case .male?:
            values.sex = .male
        default:
            break
        }
        if let quantity = await latest(height, in: store) {
            values.heightCentimeters = Int(quantity.doubleValue(for: .meterUnit(with: .centi)).rounded())
        }
        if let quantity = await latest(bodyMass, in: store) {
            values.weightKilograms = (quantity.doubleValue(for: .gramUnit(with: .kilo)) * 10).rounded() / 10
        }
        return values
    }

    private static func latest(_ type: HKQuantityType, in store: HKHealthStore) async -> HKQuantity? {
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try? await query.result(for: store).first?.quantity
    }
}

#Preview("Dark") {
    @Previewable @State var profile = OnboardingProfile()
    AboutYouView(profile: $profile, back: {}, finish: {})
        .preferredColorScheme(.dark)
}
