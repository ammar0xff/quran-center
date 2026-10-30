import 'package:flutter_test/flutter_test.dart';
import 'package:quran_center/core/utils/circle_validation.dart';

CircleFormErrors _v({
  String name = 'حلقة النور',
  String capacity = '20',
  String duration = '60',
  Set<int> days = const {},
  String start = '08:00',
  String end = '09:00',
}) =>
    validateCircleForm(
      name: name,
      capacity: capacity,
      duration: duration,
      scheduleDays: days,
      start: start,
      end: end,
    );

void main() {
  test('a complete valid form has no errors', () {
    expect(_v(days: {1, 3}).hasErrors, isFalse);
  });

  test('name is required and trimmed', () {
    expect(_v(name: '   ').name, isNotNull);
    expect(_v(name: ' س ').name, isNull);
  });

  test('capacity must be a whole number from 1 to the maximum', () {
    expect(_v(capacity: '').capacity, isNotNull);
    expect(_v(capacity: 'abc').capacity, isNotNull);
    expect(_v(capacity: '2.5').capacity, isNotNull);
    expect(_v(capacity: '0').capacity, isNotNull);
    expect(_v(capacity: '-3').capacity, isNotNull);
    expect(_v(capacity: '${maxCircleCapacity + 1}').capacity, isNotNull);
    expect(_v(capacity: '1').capacity, isNull);
    expect(_v(capacity: ' $maxCircleCapacity ').capacity, isNull);
  });

  test('session duration is bounded', () {
    expect(_v(duration: '').duration, isNotNull);
    expect(_v(duration: '4').duration, isNotNull);
    expect(_v(duration: '481').duration, isNotNull);
    expect(_v(duration: '5').duration, isNull);
    expect(_v(duration: '480').duration, isNull);
  });

  test('a weekly schedule needs start before end; no days means no check', () {
    expect(_v(days: {2}, start: '10:00', end: '09:00').schedule, isNotNull);
    expect(_v(days: {2}, start: '09:00', end: '09:00').schedule, isNotNull);
    expect(_v(days: {2}, start: '08:00', end: '09:00').schedule, isNull);
    expect(_v(days: {}, start: '10:00', end: '09:00').schedule, isNull);
  });

  test('weekday numbers outside 1..7 are rejected', () {
    expect(_v(days: {0}).schedule, isNotNull);
    expect(_v(days: {8}).schedule, isNotNull);
  });

  test('every problem is reported at once', () {
    final e = _v(name: '', capacity: 'x', duration: '0', days: {1}, start: '9:00', end: '8:00');
    expect(e.name, isNotNull);
    expect(e.capacity, isNotNull);
    expect(e.duration, isNotNull);
    expect(e.schedule, isNotNull);
  });
}
