// Game-layer test for BalanceLoader (M1-032): the bundled asset loads and
// parses to the shipped defaults via rootBundle.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/balance/balance.dart';
import 'package:smash_bros/game/balance_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load() reads the bundled asset and parses to defaults', () async {
    final config = await BalanceLoader.load();
    expect(
      config,
      equals(const BalanceConfig.defaults()),
      reason: 'the shipped balance.json must load as BalanceConfig.defaults()',
    );
  });
}
