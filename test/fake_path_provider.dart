// @dart=2.9
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:test/fake.dart';

class FakePathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String> getTemporaryPath() async {
    return null;
  }

  @override
  Future<String> getApplicationSupportPath() async {
    return 'google_fonts';
  }

  @override
  Future<String> getLibraryPath() async {
    return null;
  }

  @override
  Future<String> getApplicationDocumentsPath() async {
    return null;
  }

  @override
  Future<String> getExternalStoragePath() async {
    return null;
  }

  @override
  Future<List<String>> getExternalCachePaths() async {
    return <String>[];
  }

  @override
  Future<List<String>> getExternalStoragePaths({
    StorageDirectory type,
  }) async {
    return <String>[];
  }

  @override
  Future<String> getDownloadsPath() async {
    return null;
  }
}
