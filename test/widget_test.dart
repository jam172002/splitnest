import 'package:flutter_test/flutter_test.dart';
import 'package:splitnest/app_router.dart';

void main() {
  test('app router starts at the splash route', () {
    expect(appRouter.routeInformationProvider.value.uri.path, '/splash');
  });
}
