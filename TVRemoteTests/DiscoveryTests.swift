// Covers R2 (resolved endpoint host -> IP string).
import Testing
import Network
@testable import TVRemote

@Test("R2: hostString returns IPv4 literal")
func hostV4() { #expect(Discovery.hostString(.ipv4(IPv4Address("192.168.1.5")!)) == "192.168.1.5") }

@Test("R2: hostString strips interface suffix from IPv6")
func hostV6() { #expect(Discovery.hostString(.ipv6(IPv6Address("fe80::1%en0")!)) == "fe80::1") }

@Test("R2: hostString returns nil for names")
func hostName() { #expect(Discovery.hostString(.name("tv.local", nil)) == nil) }
