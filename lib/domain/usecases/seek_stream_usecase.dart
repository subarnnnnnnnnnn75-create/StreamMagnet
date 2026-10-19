import '../repositories/torrent_engine_repository.dart';

class SeekStreamUseCase {
  final TorrentEngineRepository _repository;

  const SeekStreamUseCase(this._repository);

  Future<void> call(int byteOffset) {
    return _repository.seek(byteOffset);
  }
}
