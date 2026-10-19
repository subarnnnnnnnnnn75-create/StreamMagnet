import '../repositories/torrent_engine_repository.dart';

class StopStreamingUseCase {
  final TorrentEngineRepository _repository;

  const StopStreamingUseCase(this._repository);

  Future<void> call() {
    return _repository.stop();
  }
}
