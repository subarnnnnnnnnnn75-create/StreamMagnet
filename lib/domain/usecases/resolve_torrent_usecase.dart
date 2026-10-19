import '../../core/constants/app_constants.dart';
import '../entities/torrent_info.dart';
import '../repositories/torrent_engine_repository.dart';

class ResolveTorrentUseCase {
  final TorrentEngineRepository _repository;

  const ResolveTorrentUseCase(this._repository);

  Future<TorrentInfo> call(
    String uriOrPath, {
    Duration timeout = AppConstants.metadataTimeout,
  }) {
    return _repository.resolveMetadata(uriOrPath, timeout: timeout);
  }
}
