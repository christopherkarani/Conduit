//
//  SendableNSCache.swift
//  SwiftAI
//
//  Created on 2025-12-25.
//

import Foundation

// MARK: - SendableNSCache

/// A thread-safe wrapper around NSCache that provides Sendable conformance.
///
/// NSCache is thread-safe but not marked as Sendable. This wrapper uses
/// `@unchecked Sendable` to allow NSCache to be used within actors and
/// other Sendable contexts while maintaining type safety.
///
/// ## Usage
///
/// ```swift
/// actor MyCache {
///     private nonisolated(unsafe) let cacheWrapper = SendableNSCache<NSString, MyObject>()
///     private var cache: NSCache<NSString, MyObject> { cacheWrapper.cache }
///
///     func get(_ key: String) -> MyObject? {
///         cache.object(forKey: key as NSString)
///     }
///
///     func set(_ object: MyObject, forKey key: String) {
///         cache.setObject(object, forKey: key as NSString)
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// NSCache is documented as thread-safe and can be accessed from multiple
/// threads concurrently. The `@unchecked Sendable` conformance is safe because:
/// - NSCache handles synchronization internally
/// - The cache reference is immutable after initialization
/// - All NSCache methods are documented as thread-safe
///
/// ## Type Parameters
///
/// - `KeyType`: The key type, must be an NSObject subclass conforming to Hashable
/// - `ObjectType`: The cached object type, must be an NSObject subclass
public final class SendableNSCache<KeyType: AnyObject & Hashable, ObjectType: AnyObject>: @unchecked Sendable {

    /// The underlying NSCache instance.
    ///
    /// This is the actual cache that stores key-value pairs. Access it
    /// through a computed property in your actor for proper isolation.
    ///
    /// ## Configuration
    ///
    /// Configure the cache limits in your initializer:
    /// ```swift
    /// init() {
    ///     cacheWrapper.cache.countLimit = 100
    ///     cacheWrapper.cache.totalCostLimit = 1024 * 1024 * 100 // 100MB
    ///     cacheWrapper.cache.delegate = myDelegate
    /// }
    /// ```
    public let cache = NSCache<KeyType, ObjectType>()
}
