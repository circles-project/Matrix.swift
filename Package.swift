// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Matrix.swift",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
        .macCatalyst(.v16),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Matrix",
            targets: ["Matrix"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.3"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "5.24.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.0"),
        .package(url: "https://gitlab.futo.org/cvwright/BlindSaltSpeke.git", from: "0.4.2"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://gitlab.futo.org/circles/MatrixSDKCrypto.git", revision: "794481de32ec389fb6dc434a9c313d44a1f2f061"),
        .package(url: "https://github.com/iosdevzone/IDZSwiftCommonCrypto.git", from: "0.13.0"),
        .package(url: "https://github.com/apple/swift-collections.git", branch: "release/1.1"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        .package(url: "https://github.com/keefertaylor/Base58Swift.git", exact: "2.1.7"),
        .package(url: "https://github.com/attaswift/SipHash.git", exact: "1.2.2"),
        .package(url: "https://github.com/cvwright/jdenticon-swift.git", branch: "master"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Matrix",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "AnyCodable", package: "anycodable"),
                .product(name: "BlindSaltSpeke", package: "blindsaltspeke"),
                .product(name: "MatrixSDKCrypto", package: "MatrixSDKCrypto"),
                .product(name: "IDZSwiftCommonCrypto", package: "IDZSwiftCommonCrypto"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Base58Swift", package: "Base58Swift"),
                .product(name: "SipHash", package: "SipHash"),
                .product(name: "JdenticonSwift", package: "jdenticon-swift"),
            ]),
        .testTarget(
            name: "MatrixTests",
            dependencies: [
                "Matrix",
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "AnyCodable", package: "anycodable"),
                .product(name: "BlindSaltSpeke", package: "blindsaltspeke"),
                .product(name: "Yams", package: "yams"),
                .product(name: "Base58Swift", package: "Base58Swift"),
            ],
            resources: [
                .copy("TestConfig.yaml")
            ]),
    ]
)
