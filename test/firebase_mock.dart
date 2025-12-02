import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

typedef Callback = void Function(MethodCall call);

void setupFirebaseAuthMocks([Callback? customHandlers]) {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupFirebaseCoreMocks();
}

void setupFirebaseCoreMocks() {
  TestFirebaseCoreHostApi.setup(MockFirebaseApp());
}

class MockFirebaseApp implements TestFirebaseCoreHostApi {
  @override
  Future<PigeonInitializeResponse> initializeApp(
    String appName,
    PigeonFirebaseOptions options,
  ) async {
    return PigeonInitializeResponse(
      name: appName,
      options: PigeonFirebaseOptions(
        apiKey: 'fake-api-key',
        projectId: 'fake-project-id',
        messagingSenderId: 'fake-sender-id',
        appId: 'fake-app-id',
      ),
    );
  }

  @override
  Future<List<PigeonInitializeResponse?>> initializeCore() async {
    return [
      PigeonInitializeResponse(
        name: defaultFirebaseAppName,
        options: PigeonFirebaseOptions(
          apiKey: 'fake-api-key',
          projectId: 'fake-project-id',
          messagingSenderId: 'fake-sender-id',
          appId: 'fake-app-id',
        ),
      ),
    ];
  }

  @override
  Future<PigeonFirebaseOptions> optionsFromResource() async {
    return PigeonFirebaseOptions(
      apiKey: 'fake-api-key',
      projectId: 'fake-project-id',
      messagingSenderId: 'fake-sender-id',
      appId: 'fake-app-id',
    );
  }
}