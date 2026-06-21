import 'package:audioplayers/audioplayers.dart';

import 'resource_service.dart';

/// Bridges an [AudioResource] (resolved by [ResourceService]) to an
/// `audioplayers` [Source], so the service stays free of audio-player types.
extension AudioResourceSource on AudioResource {
  Source toSource() =>
      filePath != null ? DeviceFileSource(filePath!) : UrlSource(url!);
}
