import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

/// Service for discovering Music Remote servers via mDNS
class MDNSDiscoveryService {
  static const String serviceType = '_applemusic._tcp';

  /// Discover available servers on the local network
  static Future<List<DiscoveredServer>> discoverServers({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final MDnsClient client = MDnsClient();
    final List<DiscoveredServer> servers = [];
    final Set<String> seenUrls = {}; // Deduplicate by URL

    try {
      await client.start();

      // Look for our service
      await for (final PtrResourceRecord ptr
          in client
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(serviceType),
              )
              .timeout(timeout)) {
        // Get the SRV record for this service
        await for (final SrvResourceRecord srv
            in client
                .lookup<SrvResourceRecord>(
                  ResourceRecordQuery.service(ptr.domainName),
                )
                .timeout(const Duration(seconds: 2))) {
          // Get the A record (IP address)
          await for (final IPAddressResourceRecord ip
              in client
                  .lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srv.target),
                  )
                  .timeout(const Duration(seconds: 2))) {
            final server = DiscoveredServer(
              name: ptr.domainName,
              host: ip.address.address,
              port: srv.port,
            );

            // Only add if we haven't seen this URL before
            if (!seenUrls.contains(server.url)) {
              seenUrls.add(server.url);
              servers.add(server);
            }
            break; // Take first IP
          }
          break; // Take first SRV
        }
      }
    } catch (e) {
      print('mDNS discovery error: $e');
    } finally {
      client.stop();
    }

    return servers;
  }
}

/// Represents a discovered server
class DiscoveredServer {
  final String name;
  final String host;
  final int port;

  DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
  });

  String get url => 'http://$host:$port';

  String get displayName {
    // Extract friendly name from service name
    // e.g., "MacMusicRemote._applemusic._tcp.local." -> "MacMusicRemote"
    return name.split('.').first;
  }
}
