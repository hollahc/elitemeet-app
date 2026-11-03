import 'package:elitemeet_app/services/back_press_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 4, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('one press goes back', () {
    expect(BackPressPolicy().onPress(at(0)), BackAction.goBack);
  });

  test('normal-paced presses each go back a page', () {
    final p = BackPressPolicy();
    expect(p.onPress(at(0)), BackAction.goBack);
    expect(p.onPress(at(800)), BackAction.goBack);
    expect(p.onPress(at(1600)), BackAction.goBack);
    expect(p.onPress(at(5000)), BackAction.goBack);
  });

  test('a fast double-tap asks to press again, a third press exits', () {
    final p = BackPressPolicy();
    expect(p.onPress(at(0)), BackAction.goBack);
    expect(p.onPress(at(300)), BackAction.showExitHint);
    expect(p.onPress(at(1500)), BackAction.exit);
  });

  test('waiting out the message returns to normal back', () {
    final p = BackPressPolicy();
    p.onPress(at(0));
    p.onPress(at(300));
    expect(p.onPress(at(2301 + 1000)), BackAction.goBack);
  });

  test('no page to go back to: the next press exits', () {
    final p = BackPressPolicy();
    expect(p.onPress(at(0)), BackAction.goBack);
    p.noPageToGoBack(at(0));
    expect(p.onPress(at(1000)), BackAction.exit);
  });

  test('no page to go back to: waiting returns to normal back', () {
    final p = BackPressPolicy();
    p.onPress(at(0));
    p.noPageToGoBack(at(0));
    expect(p.onPress(at(2500)), BackAction.goBack);
  });
}
