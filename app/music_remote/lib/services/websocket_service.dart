import 'package:socket_io_client/socket_io_client.dart' as IO;

/// WebSocket service for real-time updates from the server
class WebSocketService {
  IO.Socket? _socket;
  final String serverUrl;
  final String authToken;

  // Event callbacks
  Function(Map<String, dynamic>)? onMusicUpdate;
  Function()? onConnected;
  Function()? onDisconnected;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  WebSocketService({required this.serverUrl, required this.authToken});

  /// Connect to the WebSocket server
  void connect() {
    if (_socket != null && _socket!.connected) {
      print('✅ WebSocket already connected');
      return;
    }

    try {
      // Parse server URL to get base URL without /socket.io
      final uri = Uri.parse(serverUrl);
      final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

      print('🔌 Connecting to WebSocket: $baseUrl');

      _socket = IO.io(baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'query': {'token': authToken},
      });

      _socket!.onConnect((_) {
        print('✅ WebSocket connected!');
        _isConnected = true;
        onConnected?.call();
      });

      _socket!.onDisconnect((_) {
        print('❌ WebSocket disconnected');
        _isConnected = false;
        onDisconnected?.call();
      });

      _socket!.on('initial_state', (data) {
        print('📦 Received initial state');
        if (data is Map<String, dynamic>) {
          _handleMusicUpdate({'type': 'initial_state', ...data});
        }
      });

      _socket!.on('music_update', (data) {
        print('🎵 Received music update: ${data['type']}');
        if (data is Map<String, dynamic>) {
          onMusicUpdate?.call(data);
        }
      });

      _socket!.on('pong', (data) {
        print('🏓 Pong received');
      });

      _socket!.onError((error) {
        print('❌ WebSocket error: $error');
      });

      _socket!.connect();
    } catch (e) {
      print('❌ WebSocket connection error: $e');
      _isConnected = false;
    }
  }

  void _handleMusicUpdate(Map<String, dynamic> data) {
    onMusicUpdate?.call(data);
  }

  /// Disconnect from the WebSocket server
  void disconnect() {
    if (_socket != null) {
      print('🔌 Disconnecting WebSocket');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }

  /// Send a ping to the server
  void ping() {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('ping');
    }
  }

  /// Dispose of the service
  void dispose() {
    disconnect();
  }
}
