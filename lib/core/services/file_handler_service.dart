import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';

class FileHandlerService {
  static final FileHandlerService _instance = FileHandlerService._internal();
  factory FileHandlerService() => _instance;
  FileHandlerService._internal();

  void initializeFileHandling(Function(List<SharedFile>) onFilesReceived) {
    // Handle initial sharing
    FlutterSharingIntent.instance.getInitialSharing().then((List<SharedFile> value) {
      if (value.isNotEmpty) {
        onFilesReceived(value);
      }
    });

    // Listen for incoming files while app is running
    FlutterSharingIntent.instance.getMediaStream().listen((List<SharedFile> value) {
      if (value.isNotEmpty) {
        onFilesReceived(value);
      }
    });
  }
}
