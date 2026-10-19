import '../entities/torrent_info.dart';
import '../repositories/torrent_engine_repository.dart';

class StartStreamingUseCase {
  final TorrentEngineRepository _repository;

  const StartStreamingUseCase(this._repository);

  Future<String> call({
    required TorrentInfo torrent,
    required int fileIndex,
  }) {
    return _repository.startStreaming(
      torrent: torrent,
      fileIndex: fileIndex,
    );
  }
}
