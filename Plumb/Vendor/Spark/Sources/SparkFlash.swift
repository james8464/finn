@_exported @_spi(SparkPrivate) import SparkLib

/// Spark flavor information
public enum SparkFlavor {
    /// The current version of this spark flavor
    public static let version = "0.5.8"

    /// The name of this spark flavor
    public static let name = "Flash"
}

public extension Spark {
    @MainActor
    static func configure(_ config: Configuration) {
        self.configure(
            config,
            integrations: Integrations(),
            sdkVersion: SparkFlavor.version
        )
    }
}
