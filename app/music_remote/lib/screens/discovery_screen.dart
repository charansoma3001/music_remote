import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/music_provider.dart';
import '../services/device_fingerprint_service.dart';
import '../services/mdns_discovery_service.dart';
import 'control_screen.dart';

/// Discovery screen for finding and connecting to the server
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _serverUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool _isConnecting = false;
  bool _isCheckingDevice = true;
  String? _deviceFingerprint;
  bool _trustDevice = false; // User checkbox
  bool _hasStoredCredentials = false;
  bool _isScanning = false;
  List<DiscoveredServer> _discoveredServers = [];

  @override
  void initState() {
    super.initState();
    // Default to localhost for testing
    _serverUrlController.text = 'http://192.168.1.100:5000';
    _checkDeviceTrust();
  }

  Future<void> _checkDeviceTrust() async {
    setState(() {
      _isCheckingDevice = true;
    });

    try {
      // Get device fingerprint
      _deviceFingerprint = await DeviceFingerprintService.getFingerprint();

      // Check for stored credentials
      final storedUrl = await _secureStorage.read(key: 'server_url');
      final storedToken = await _secureStorage.read(key: 'auth_token');

      if (storedUrl != null && storedToken != null) {
        setState(() {
          _hasStoredCredentials = true;
          _serverUrlController.text = storedUrl;
        });

        // Auto-connect
        await _autoConnect(storedUrl, storedToken);
      }
    } catch (e) {
      print('Error checking device trust: $e');
    } finally {
      setState(() {
        _isCheckingDevice = false;
      });
    }
  }

  Future<void> _autoConnect(String serverUrl, String token) async {
    final provider = context.read<MusicProvider>();
    final success = await provider.connect(serverUrl, token);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final serverUrl = _serverUrlController.text.trim();
    final token = _tokenController.text.trim();

    if (serverUrl.isEmpty || token.isEmpty) {
      _showError('Please enter both server URL and token');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    final provider = context.read<MusicProvider>();
    final success = await provider.connect(serverUrl, token);

    if (success && mounted) {
      // Store credentials if trust device is checked
      if (_trustDevice) {
        await _secureStorage.write(key: 'server_url', value: serverUrl);
        await _secureStorage.write(key: 'auth_token', value: token);
      }

      // Register device as trusted after successful connection
      if (_deviceFingerprint != null) {
        await _registerDevice(serverUrl, token);
      }

      setState(() {
        _isConnecting = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } else if (mounted) {
      setState(() {
        _isConnecting = false;
      });
      _showError(provider.errorMessage ?? 'Connection failed');
    }
  }

  Future<void> _registerDevice(String serverUrl, String token) async {
    if (_deviceFingerprint == null) return;

    try {
      final deviceName = await DeviceFingerprintService.getDeviceName();
      final provider = context.read<MusicProvider>();
      await provider.registerDevice(_deviceFingerprint!, deviceName);
    } catch (e) {
      print('Failed to register device: $e');
    }
  }

  /// Clear stored credentials (for logout)
  Future<void> clearStoredCredentials() async {
    await _secureStorage.delete(key: 'server_url');
    await _secureStorage.delete(key: 'auth_token');
  }

  /// Scan for servers using mDNS
  Future<void> _scanForServers() async {
    setState(() {
      _isScanning = true;
      _discoveredServers = [];
    });

    try {
      final servers = await MDNSDiscoveryService.discoverServers(
        timeout: const Duration(seconds: 5),
      );

      setState(() {
        _discoveredServers = servers;
        _isScanning = false;
      });

      if (servers.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No servers found. Make sure the server is running.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Connect to a discovered server
  Future<void> _connectToServer(DiscoveredServer server) async {
    _serverUrlController.text = server.url;
    // Token still needs to be entered manually
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Selected: ${server.displayName}. Enter token to connect.',
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Server'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.music_note_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Apple Music Remote',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to your Mac server',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server Connection',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Server URL',
                          hintText: 'http://192.168.1.100:5000',
                          prefixIcon: Icon(Icons.dns_rounded),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.url,
                        enabled: !_isConnecting,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tokenController,
                        decoration: const InputDecoration(
                          labelText: 'Authentication Token',
                          hintText: 'Paste token from server',
                          prefixIcon: Icon(Icons.lock_rounded),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        enabled: !_isConnecting,
                      ),
                      const SizedBox(height: 16),
                      // Trust this device checkbox
                      CheckboxListTile(
                        title: const Text('Trust this device'),
                        subtitle: const Text(
                          'Automatically connect without entering token',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _trustDevice,
                        onChanged: _isConnecting
                            ? null
                            : (value) {
                                setState(() {
                                  _trustDevice = value ?? false;
                                });
                              },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _isConnecting ? null : _connect,
                          child: _isConnecting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Connect'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Scan for servers button
              OutlinedButton.icon(
                onPressed: _isScanning ? null : _scanForServers,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar_rounded),
                label: Text(_isScanning ? 'Scanning...' : 'Scan for Servers'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              // Discovered servers list
              if (_discoveredServers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Discovered Servers',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _discoveredServers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final server = _discoveredServers[index];
                          return ListTile(
                            leading: const Icon(Icons.dns_rounded),
                            title: Text(server.displayName),
                            subtitle: Text(server.url),
                            trailing: const Icon(Icons.arrow_forward_rounded),
                            onTap: () => _connectToServer(server),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Setup Instructions',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. Start the server on your Mac\n'
                        '2. Note the IP address shown in the terminal\n'
                        '3. Copy the authentication token\n'
                        '4. Ensure both devices are on the same WiFi',
                        style: TextStyle(color: Colors.blue[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
