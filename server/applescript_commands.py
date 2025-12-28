"""
AppleScript wrapper functions for controlling Apple Music on macOS.
"""

import subprocess
import json


def execute_applescript(script):
    """
    Execute an AppleScript command and return the output.
    
    Args:
        script (str): The AppleScript command to execute
        
    Returns:
        str: The output from the AppleScript command
    """
    try:
        result = subprocess.run(
            ['osascript', '-e', script],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return "Error: Command timed out"
    except Exception as e:
        return f"Error: {str(e)}"


def play():
    """Start or resume playback."""
    script = 'tell application "Music" to play'
    return execute_applescript(script)


def pause():
    """Pause playback."""
    script = 'tell application "Music" to pause'
    return execute_applescript(script)


def next_track():
    """Skip to the next track."""
    script = 'tell application "Music" to next track'
    return execute_applescript(script)


def previous_track():
    """Go to the previous track."""
    script = 'tell application "Music" to previous track'
    return execute_applescript(script)


def get_playback_state():
    """
    Get current playback state.
    
    Returns:
        str: 'playing', 'paused', or 'stopped'
    """
    script = 'tell application "Music" to get player state as string'
    state = execute_applescript(script)
    return state.lower()


def get_current_track():
    """
    Get information about the currently playing track.
    
    Returns:
        dict: Track information including name, artist, album, duration, and artwork
    """
    # Get basic track info
    script = '''
    tell application "Music"
        if player state is not stopped then
            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackDuration to duration of current track
            set playerPos to player position
            return trackName & "|" & trackArtist & "|" & trackAlbum & "|" & trackDuration & "|" & playerPos
        else
            return "No track playing"
        end if
    end tell
    '''
    
    result = execute_applescript(script)
    
    if result == "No track playing" or result.startswith("Error"):
        return {
            "name": None,
            "artist": None,
            "album": None,
            "duration": 0,
            "position": 0,
            "state": "stopped"
        }
    
    try:
        parts = result.split("|")
        return {
            "name": parts[0] if len(parts) > 0 else None,
            "artist": parts[1] if len(parts) > 1 else None,
            "album": parts[2] if len(parts) > 2 else None,
            "duration": float(parts[3]) if len(parts) > 3 else 0,
            "position": float(parts[4]) if len(parts) > 4 else 0,
            "state": get_playback_state()
        }
    except Exception as e:
        return {
            "name": None,
            "artist": None,
            "album": None,
            "duration": 0,
            "position": 0,
            "state": "error",
            "error": str(e)
        }


def set_volume(level):
    """
    Set the volume level.
    
    Args:
        level (int): Volume level from 0 to 100
        
    Returns:
        str: Result of the operation
    """
    # Clamp volume between 0 and 100
    level = max(0, min(100, int(level)))
    script = f'tell application "Music" to set sound volume to {level}'
    return execute_applescript(script)


def get_volume():
    """
    Get the current volume level.
    
    Returns:
        int: Current volume level (0-100)
    """
    script = 'tell application "Music" to get sound volume'
    result = execute_applescript(script)
    try:
        return int(result)
    except:
        return 50  # Default fallback


def get_playlists():
    """
    Get list of available playlists.
    
    Returns:
        list: List of playlist names
    """
    script = '''
    tell application "Music"
        set playlistNames to name of playlists
        return playlistNames
    end tell
    '''
    result = execute_applescript(script)
    
    # AppleScript returns comma-separated list
    if result and not result.startswith("Error"):
        return [name.strip() for name in result.split(",")]
    return []


def play_playlist(playlist_name):
    """
    Play a specific playlist by name.
    
    Args:
        playlist_name (str): Name of the playlist to play
        
    Returns:
        str: Result of the operation
    """
    script = f'''
    tell application "Music"
        play playlist "{playlist_name}"
    end tell
    '''
    return execute_applescript(script)


def get_artwork():
    """
    Get the artwork for the current track and save it to a temporary file.
    
    Returns:
        str: Path to the saved artwork file, or None if no artwork available
    """
    import tempfile
    import os
    
    # Create temp directory if it doesn't exist
    temp_dir = os.path.join(tempfile.gettempdir(), 'music_remote_artwork')
    os.makedirs(temp_dir, exist_ok=True)
    
    # Get track ID to use as filename
    script = '''
    tell application "Music"
        if player state is not stopped then
            set trackID to database ID of current track
            return trackID as string
        else
            return "0"
        end if
    end tell
    '''
    
    track_id = execute_applescript(script)
    
    if track_id == "0" or track_id.startswith("Error"):
        return None
    
    artwork_path = os.path.join(temp_dir, f'artwork_{track_id}.jpg')
    
    # Check if we already have this artwork cached
    if os.path.exists(artwork_path):
        return artwork_path
    
    # Save artwork to file
    script = f'''
    tell application "Music"
        if player state is not stopped then
            try
                set artworkData to data of artwork 1 of current track
                set artworkFile to POSIX file "{artwork_path}"
                set fileRef to open for access artworkFile with write permission
                write artworkData to fileRef
                close access fileRef
                return "success"
            on error errMsg
                return "Error: " & errMsg
            end try
        else
            return "Error: No track playing"
        end if
    end tell
    '''
    
    result = execute_applescript(script)
    
    if result == "success" and os.path.exists(artwork_path):
        return artwork_path
    
    return None


def seek_to_position(position):
    """
    Seek to a specific position in the current track.
    
    Args:
        position (float): Position in seconds
        
    Returns:
        str: Result of the operation
    """
    script = f'tell application "Music" to set player position to {position}'
    return execute_applescript(script)


def search_library(query, search_type='track'):
    """
    Search the Apple Music library.
    
    Args:
        query (str): Search query
        search_type (str): Type of search - 'track', 'album', or 'artist'
        
    Returns:
        list: List of search results as dictionaries
    """
    if not query or len(query) < 2:
        return []
    
    # Escape quotes in query
    query = query.replace('"', '\\"')
    
    if search_type == 'track':
        script = f'''
        tell application "Music"
            set searchResults to (search library playlist 1 for "{query}")
            set resultList to {{}}
            repeat with aTrack in searchResults
                try
                    if class of aTrack is file track then
                        set trackName to name of aTrack
                        set trackArtist to artist of aTrack
                        set trackAlbum to album of aTrack
                        set trackID to database ID of aTrack
                        set end of resultList to trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackID
                    end if
                end try
            end repeat
            
            -- Convert list to string
            set AppleScript's text item delimiters to ":::"
            set resultString to resultList as string
            set AppleScript's text item delimiters to ""
            return resultString
        end tell
        '''
    elif search_type == 'album':
        script = f'''
        tell application "Music"
            set searchResults to (search library playlist 1 for "{query}")
            set albumDict to {{}}
            set resultList to {{}}
            repeat with aTrack in searchResults
                try
                    if class of aTrack is file track then
                        set albumName to album of aTrack
                        set artistName to artist of aTrack
                        set albumKey to albumName & "|" & artistName
                        -- Check if we've already added this album
                        if albumDict does not contain albumKey then
                            set end of albumDict to albumKey
                            set end of resultList to albumName & "|||" & artistName
                        end if
                    end if
                end try
            end repeat
            
            set AppleScript's text item delimiters to ":::"
            set resultString to resultList as string
            set AppleScript's text item delimiters to ""
            return resultString
        end tell
        '''
    else:  # artist
        script = f'''
        tell application "Music"
            set searchResults to (search library playlist 1 for "{query}")
            set artistDict to {{}}
            set resultList to {{}}
            repeat with aTrack in searchResults
                try
                    if class of aTrack is file track then
                        set artistName to artist of aTrack
                        if artistDict does not contain artistName and artistName is not "" then
                            set end of artistDict to artistName
                            set end of resultList to artistName
                        end if
                    end if
                end try
            end repeat
            
            set AppleScript's text item delimiters to ":::"
            set resultString to resultList as string
            set AppleScript's text item delimiters to ""
            return resultString
        end tell
        '''
    
    result = execute_applescript(script)
    
    if result.startswith("Error") or not result or result == "":
        return []
    
    # Parse results
    results = []
    if search_type == 'track':
        items = result.split(":::")
        for item in items:
            if item.strip():
                parts = item.split("|||")
                if len(parts) >= 4:
                    results.append({
                        "type": "track",
                        "name": parts[0],
                        "artist": parts[1],
                        "album": parts[2],
                        "id": parts[3]
                    })
    elif search_type == 'album':
        items = result.split(":::")
        for item in items:
            if item.strip():
                parts = item.split("|||")
                if len(parts) >= 2:
                    results.append({
                        "type": "album",
                        "name": parts[0],
                        "artist": parts[1]
                    })
    else:  # artist
        items = result.split(":::")
        for item in items:
            if item.strip():
                results.append({
                    "type": "artist",
                    "name": item.strip()
                })
    
    return results[:50]  # Limit to 50 results


def play_track_by_id(track_id):
    """
    Play a specific track by its database ID.
    
    Args:
        track_id (str): Database ID of the track
        
    Returns:
        str: Result message
    """
    script = f'''
    tell application "Music"
        set theTrack to (first track of library playlist 1 whose database ID is {track_id})
        play theTrack
        return "Playing: " & name of theTrack
    end tell
    '''
    
    return execute_applescript(script)


def get_repeat_mode():
    """Get the current repeat mode (off, one, all)."""
    script = '''
    tell application "Music"
        return song repeat of current playlist as string
    end tell
    '''
    result = execute_applescript(script)
    return result.strip().lower()


def set_repeat_mode(mode):
    """
    Set the repeat mode.
    
    Args:
        mode (str): 'off', 'one', or 'all'
    """
    script = f'''
    tell application "Music"
        set song repeat of current playlist to {mode}
        return "Repeat set to: {mode}"
    end tell
    '''
    return execute_applescript(script)


def get_shuffle_mode():
    """Get the current shuffle mode (true/false)."""
    script = '''
    tell application "Music"
        return shuffle enabled of current playlist
    end tell
    '''
    result = execute_applescript(script)
    return result.strip().lower() == 'true'


def set_shuffle_mode(enabled):
    """
    Set the shuffle mode.
    
    Args:
        enabled (bool): True to enable shuffle, False to disable
    """
    mode = 'true' if enabled else 'false'
    script = f'''
    tell application "Music"
        set shuffle enabled of current playlist to {mode}
        return "Shuffle: {mode}"
    end tell
    '''
    return execute_applescript(script)
