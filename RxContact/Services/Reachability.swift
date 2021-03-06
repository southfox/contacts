// esto esta inspirado, y quizas afanado.

#if os(watchOS)
import WatchConnectivity
#else
import SystemConfiguration
#endif
import struct Foundation.Notification
import class Foundation.NotificationCenter


public enum ReachabilityError: Error {
    case failedToCreateWithAddress(sockaddr_in)
    case failedToCreateWithHostname(String)
    case unableToSetCallback
    case unableToSetDispatchQueue
}

public let ReachabilityChangedNotification = Notification.Name("ReachabilityChangedNotification")

func callback(reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {

    guard let info = info else { return }
    
    let reachability = Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue()

    DispatchQueue.main.async { 
        reachability.reachabilityChanged()
    }
}

public class Reachability {

    public typealias NetworkReachable = (Reachability) -> ()
    public typealias NetworkUnreachable = (Reachability) -> ()

    public enum NetworkStatus: CustomStringConvertible {

        case notReachable, reachableViaWiFi, reachableViaWWAN

        public var description: String {
            switch self {
            case .reachableViaWWAN: return "Cellular"
            case .reachableViaWiFi: return "WiFi"
            case .notReachable: return "No Connection"
            }
        }
    }

    public var whenReachable: NetworkReachable?
    public var whenUnreachable: NetworkUnreachable?
    public var reachableOnWWAN: Bool
    
    // The notification center on which "reachability changed" events are being posted
    public var notificationCenter: NotificationCenter = NotificationCenter.default

    public var currentReachabilityString: String {
        return "\(currentReachabilityStatus)"
    }

    public var currentReachabilityStatus: NetworkStatus {
        guard isReachable else { return .notReachable }
        
        if isReachableViaWiFi {
            return .reachableViaWiFi
        }
        if isRunningOnDevice {
            return .reachableViaWWAN
        }
        
        return .notReachable
    }
    
    fileprivate var previousFlags: SCNetworkReachabilityFlags?
    
    fileprivate var isRunningOnDevice: Bool = {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            return false
        #else
            return true
        #endif
    }()
    
    fileprivate var notifierRunning = false
    fileprivate var reachabilityRef: SCNetworkReachability?
    
    fileprivate let reachabilitySerialQueue = DispatchQueue(label: "uk.co.ashleymills.reachability")
    
    required public init(reachabilityRef: SCNetworkReachability) {
        reachableOnWWAN = true
        self.reachabilityRef = reachabilityRef
    }
    
    public convenience init?(hostname: String) {
        #if os(watchOS)
            self.init()
        #else
            guard let ref = SCNetworkReachabilityCreateWithName(nil, hostname) else { return nil }
            self.init(reachabilityRef: ref)
        #endif
    }
    
    public convenience init?() {
        #if os(watchOS)
            self.init()
        #endif
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        
        guard let ref: SCNetworkReachability = withUnsafePointer(to: &zeroAddress, {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }) else { return nil }
        
        #if !os(watchOS)
        self.init(reachabilityRef: ref)
        #endif
    }
    
    deinit {
        stopNotifier()

        reachabilityRef = nil
        whenReachable = nil
        whenUnreachable = nil
    }
}

public extension Reachability {
    
    // MARK: - *** Notifier methods ***
    func startNotifier() throws {
        
        guard let reachabilityRef = reachabilityRef, !notifierRunning else { return }
        
#if !os(watchOS)
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = UnsafeMutableRawPointer(Unmanaged<Reachability>.passUnretained(self).toOpaque())
        if !SCNetworkReachabilitySetCallback(reachabilityRef, callback, &context) {
            stopNotifier()
            throw ReachabilityError.unableToSetCallback
        }
        
        if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, reachabilitySerialQueue) {
            stopNotifier()
            throw ReachabilityError.unableToSetDispatchQueue
        }
#endif
        
        // Perform an initial check
        reachabilitySerialQueue.async {
            self.reachabilityChanged()
        }
        
        notifierRunning = true
    }
    
    func stopNotifier() {
        defer { notifierRunning = false }
        guard let reachabilityRef = reachabilityRef else { return }
        
#if !os(watchOS)
        SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
#endif
    }
    
    // MARK: - *** Connection test methods ***
    var isReachable: Bool {
        
        guard isReachableFlagSet else { return false }
        
        if isConnectionRequiredAndTransientFlagSet {
            return false
        }
        
        if isRunningOnDevice {
            if isOnWWANFlagSet && !reachableOnWWAN {
                // We don't want to connect when on 3G.
                return false
            }
        }
        
        return true
    }
    
    var isReachableViaWWAN: Bool {
        // Check we're not on the simulator, we're REACHABLE and check we're on WWAN
        return isRunningOnDevice && isReachableFlagSet && isOnWWANFlagSet
    }
    
    var isReachableViaWiFi: Bool {
        
        // Check we're reachable
        guard isReachableFlagSet else { return false }
        
        // If reachable we're reachable, but not on an iOS device (i.e. simulator), we must be on WiFi
        guard isRunningOnDevice else { return true }
        
        // Check we're NOT on WWAN
        return !isOnWWANFlagSet
    }
    
    var description: String {
        
        let W = isRunningOnDevice ? (isOnWWANFlagSet ? "W" : "-") : "X"
        let R = isReachableFlagSet ? "R" : "-"
        let c = isConnectionRequiredFlagSet ? "c" : "-"
        let t = isTransientConnectionFlagSet ? "t" : "-"
        let i = isInterventionRequiredFlagSet ? "i" : "-"
        let C = isConnectionOnTrafficFlagSet ? "C" : "-"
        let D = isConnectionOnDemandFlagSet ? "D" : "-"
        let l = isLocalAddressFlagSet ? "l" : "-"
        let d = isDirectFlagSet ? "d" : "-"
        
        return "\(W)\(R) \(c)\(t)\(i)\(C)\(D)\(l)\(d)"
    }
}

fileprivate extension Reachability {
    
    func reachabilityChanged() {
        
        let flags = reachabilityFlags
        
        guard previousFlags != flags else { return }
        
        let block = isReachable ? whenReachable : whenUnreachable
        block?(self)
        
        self.notificationCenter.post(name: ReachabilityChangedNotification, object:self)
        
        previousFlags = flags
    }
    
    var isOnWWANFlagSet: Bool {
        #if os(iOS)
            return reachabilityFlags.contains(.isWWAN)
        #else
            return false
        #endif
    }
    var isReachableFlagSet: Bool {
        return reachabilityFlags.contains(.reachable)
    }
    var isConnectionRequiredFlagSet: Bool {
        return reachabilityFlags.contains(.connectionRequired)
    }
    var isInterventionRequiredFlagSet: Bool {
        return reachabilityFlags.contains(.interventionRequired)
    }
    var isConnectionOnTrafficFlagSet: Bool {
        return reachabilityFlags.contains(.connectionOnTraffic)
    }
    var isConnectionOnDemandFlagSet: Bool {
        return reachabilityFlags.contains(.connectionOnDemand)
    }
    var isConnectionOnTrafficOrDemandFlagSet: Bool {
        return !reachabilityFlags.intersection([.connectionOnTraffic, .connectionOnDemand]).isEmpty
    }
    var isTransientConnectionFlagSet: Bool {
        return reachabilityFlags.contains(.transientConnection)
    }
    var isLocalAddressFlagSet: Bool {
        return reachabilityFlags.contains(.isLocalAddress)
    }
    var isDirectFlagSet: Bool {
        return reachabilityFlags.contains(.isDirect)
    }
    var isConnectionRequiredAndTransientFlagSet: Bool {
        return reachabilityFlags.intersection([.connectionRequired, .transientConnection]) == [.connectionRequired, .transientConnection]
    }
    
    var reachabilityFlags: SCNetworkReachabilityFlags {
        
        guard let reachabilityRef = reachabilityRef else { return SCNetworkReachabilityFlags() }
        
        var flags = SCNetworkReachabilityFlags()
        let gotFlags = withUnsafeMutablePointer(to: &flags) {
            SCNetworkReachabilityGetFlags(reachabilityRef, UnsafeMutablePointer($0))
        }
        
        if gotFlags {
            return flags
        } else {
            return SCNetworkReachabilityFlags()
        }
    }
}

#if os(watchOS)
    struct SCNetworkReachabilityFlags : OptionSet {
        let rawValue: Int
        static let kSCNetworkReachabilityFlagsTransientConnection  = SCNetworkReachabilityFlags(rawValue: 1 << 0)
        static let kSCNetworkReachabilityFlagsReachable  = SCNetworkReachabilityFlags(rawValue: 1 << 1)
        static let kSCNetworkReachabilityFlagsConnectionRequired  = SCNetworkReachabilityFlags(rawValue: 1 << 2)
        static let kSCNetworkReachabilityFlagsConnectionOnTraffic  = SCNetworkReachabilityFlags(rawValue: 1 << 3)
        static let kSCNetworkReachabilityFlagsInterventionRequired  = SCNetworkReachabilityFlags(rawValue: 1 << 4)
        static let kSCNetworkReachabilityFlagsConnectionOnDemand  = SCNetworkReachabilityFlags(rawValue: 1 << 5)
        static let kSCNetworkReachabilityFlagsIsLocalAddress  = SCNetworkReachabilityFlags(rawValue: 1 << 16)
        static let kSCNetworkReachabilityFlagsIsDirect  = SCNetworkReachabilityFlags(rawValue: 1 << 17)
        static let kSCNetworkReachabilityFlagsIsWWAN  = SCNetworkReachabilityFlags(rawValue: 1 << 18)
        static let kSCNetworkReachabilityFlagsConnectionAutomatic = kSCNetworkReachabilityFlagsConnectionOnTraffic
        static let transientConnection = kSCNetworkReachabilityFlagsTransientConnection
        static let reachable = kSCNetworkReachabilityFlagsReachable
        static let connectionRequired = kSCNetworkReachabilityFlagsConnectionRequired
        static let connectionOnTraffic = kSCNetworkReachabilityFlagsConnectionOnTraffic
        static let interventionRequired = kSCNetworkReachabilityFlagsInterventionRequired
        static let connectionOnDemand = kSCNetworkReachabilityFlagsConnectionOnDemand
        static let isLocalAddress = kSCNetworkReachabilityFlagsIsLocalAddress
        static let isDirect = kSCNetworkReachabilityFlagsIsDirect
        static let isWWAN = kSCNetworkReachabilityFlagsIsWWAN
        static let connectionAutomatic = kSCNetworkReachabilityFlagsConnectionAutomatic
    }

    public typealias SCNetworkReachability = Reachability

    extension Reachability {
        func SCNetworkReachabilityCreateWithName(_ allocator: Any?, _ node: String) -> Reachability? {
            return nil
        }
        
        /*
 SCNetworkReachabilityRef __nullable
 SCNetworkReachabilityCreateWithAddress		(
 CFAllocatorRef			__nullable	allocator,
 const struct sockaddr				*address
 )				__OSX_AVAILABLE_STARTING(__MAC_10_3,__IPHONE_2_0);
*/

        func SCNetworkReachabilityCreateWithAddress(_ allocator: Any?, _ address: Any?) -> Reachability? {
            return nil
        }
        
        func SCNetworkReachabilityGetFlags(_ target: Reachability?, _ flags: Any?) -> Bool {
            return false
        }

    }

#endif
