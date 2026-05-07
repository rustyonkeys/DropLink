import 'package:uuid/uuid.dart';

class DeviceIdentity {
  DeviceIdentity()
      : id = const Uuid().v4(),
        name = 'Android Phone';

  final String id;
  final String name;
  final String platform = 'android';
}
