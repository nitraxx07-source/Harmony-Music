import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '/models/playlist.dart';

class YouTubeAuthService extends GetxService {
  static const _scope = 'https://www.googleapis.com/auth/youtube.readonly';
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [_scope]);
  final Dio _dio = Dio();
  final isSignedIn = false.obs;
  GoogleSignInAccount? _account;

  @override
  void onInit() {
    _restoreSession();
    super.onInit();
  }

  Future<void> _restoreSession() async {
    try {
      _account = await _googleSignIn.signInSilently();
      isSignedIn.value = _account != null;
    } catch (_) {
      isSignedIn.value = false;
    }
  }

  Future<bool> signIn() async {
    _account = await _googleSignIn.signIn();
    isSignedIn.value = _account != null;
    return _account != null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    isSignedIn.value = false;
  }

  Future<Options> _authorizedOptions() async {
    final account = _account ?? await _googleSignIn.signInSilently();
    if (account == null) throw StateError('Google session is not available');
    _account = account;
    final token = (await account.authentication).accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Google did not return an access token');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<Playlist>> getPlaylists() async {
    final response = await _dio.get(
      'https://www.googleapis.com/youtube/v3/playlists',
      queryParameters: {
        'part': 'snippet,contentDetails,status',
        'mine': 'true',
        'maxResults': 50,
      },
      options: await _authorizedOptions(),
    );
    return (response.data['items'] as List).map((item) {
      final snippet = item['snippet'];
      final thumbnails = snippet['thumbnails'];
      final thumbnail = thumbnails['high']?['url'] ??
          thumbnails['medium']?['url'] ??
          thumbnails['default']?['url'] ??
          Playlist.thumbPlaceholderUrl;
      return Playlist(
        title: snippet['title'],
        playlistId: item['id'],
        thumbnailUrl: thumbnail,
        description: snippet['description'],
        songCount: '${item['contentDetails']['itemCount']}',
        isYouTubeMusicPlaylist: true,
      );
    }).toList();
  }

  Future<String?> getLikedPlaylistId() async {
    final response = await _dio.get(
      'https://www.googleapis.com/youtube/v3/channels',
      queryParameters: {
        'part': 'contentDetails',
        'mine': 'true',
      },
      options: await _authorizedOptions(),
    );
    final items = response.data['items'] as List;
    if (items.isEmpty) return null;
    return items.first['contentDetails']['relatedPlaylists']['likes'];
  }

  Future<List<MediaItem>> getPlaylistSongs(String playlistId) async {
    final response = await _dio.get(
      'https://www.googleapis.com/youtube/v3/playlistItems',
      queryParameters: {
        'part': 'snippet,contentDetails',
        'playlistId': playlistId,
        'maxResults': 50,
      },
      options: await _authorizedOptions(),
    );
    return (response.data['items'] as List).map<MediaItem?>((item) {
      final snippet = item['snippet'];
      final videoId = item['contentDetails']['videoId'];
      if (videoId == null) return null;
      final thumbnails = snippet['thumbnails'];
      final thumbnail = thumbnails['high']?['url'] ??
          thumbnails['medium']?['url'] ??
          thumbnails['default']?['url'];
      return MediaItem(
        id: videoId,
        title: snippet['title'] ?? 'Unknown video',
        artist: snippet['videoOwnerChannelTitle'],
        artUri: thumbnail == null ? null : Uri.tryParse(thumbnail),
        extras: {
          'artists': [
            {'name': snippet['videoOwnerChannelTitle'] ?? ''}
          ],
        },
      );
    }).whereType<MediaItem>().toList();
  }
}