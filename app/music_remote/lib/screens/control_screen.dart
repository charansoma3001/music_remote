import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/music_provider.dart';
import 'discovery_screen.dart';
import 'playlists_screen.dart';
import 'search_screen.dart';

/// Main control screen for controlling music playback
class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  @override
  void initState() {
    super.initState();
    // Initial refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Remote'),
        elevation: 0,
        actions: [
          // Connection status badge
          Consumer<MusicProvider>(
            builder: (context, provider, _) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: provider.isConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  provider.isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
          // Disconnect button
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await context.read<MusicProvider>().clearSettings();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const DiscoveryScreen(),
                  ),
                );
              }
            },
            tooltip: 'Disconnect',
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PlaylistsScreen(),
                ),
              );
            },
            tooltip: 'Playlists',
          ),
        ],
      ),
      body: Consumer<MusicProvider>(
        builder: (context, provider, _) {
          if (provider.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.errorMessage!),
                  backgroundColor: Colors.orange,
                ),
              );
            });
          }

          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Album artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: provider.artworkUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: provider.artworkUrl!,
                                  // Use track info as cache key so it updates when track changes
                                  cacheKey:
                                      '${provider.currentTrack.name}_${provider.currentTrack.artist}',
                                  httpHeaders: {
                                    'Authorization':
                                        'Bearer ${provider.authToken}',
                                  },
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.music_note_rounded,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Track info
                    Text(
                      provider.currentTrack.name ?? 'No Track Playing',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.currentTrack.artist ?? '—',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.currentTrack.album ?? '—',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Progress bar (placeholder)
                    if (provider.currentTrack.hasTrack) ...[
                      Row(
                        children: [
                          Text(
                            provider.currentTrack.displayPosition,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: provider.currentTrack.position,
                              max: provider.currentTrack.duration > 0
                                  ? provider.currentTrack.duration
                                  : 1,
                              onChanged: (value) {
                                // Seek to new position
                                provider.seekTo(value);
                              },
                            ),
                          ),
                          Text(
                            provider.currentTrack.displayDuration,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Playback controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Shuffle button
                        IconButton(
                          iconSize: 28,
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: provider.isShuffleEnabled
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          onPressed: () => provider.toggleShuffle(),
                          tooltip: 'Shuffle',
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: () => provider.previous(),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: IconButton(
                            iconSize: 36,
                            icon: Icon(
                              provider.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (provider.isPlaying) {
                                provider.pause();
                              } else {
                                provider.play();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: () => provider.next(),
                        ),
                        const SizedBox(width: 8),
                        // Repeat button
                        IconButton(
                          iconSize: 28,
                          icon: Icon(
                            provider.repeatMode == 'one'
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: provider.repeatMode != 'off'
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          onPressed: () => provider.cycleRepeat(),
                          tooltip: 'Repeat: ${provider.repeatMode}',
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Volume control
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.volume_down_rounded,
                              color: Colors.grey[600],
                            ),
                            Expanded(
                              child: Slider(
                                value: provider.volume.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 20,
                                label: provider.volume.toString(),
                                onChanged: (value) {
                                  provider.setVolume(value.toInt());
                                },
                              ),
                            ),
                            Icon(
                              Icons.volume_up_rounded,
                              color: Colors.grey[600],
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
        },
      ),
    );
  }
}
