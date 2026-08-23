import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/riding_group.dart';

void main() {
  group('bbbClub', () {
    test('has club id BBB and exactly 7 groups A1..A4, B1..B3', () {
      expect(bbbClub.id, 'BBB');
      expect(bbbClub.groups.map((g) => g.id).toList(),
          ['A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3']);
    });

    test('roomIdFor builds "<clubId>:<groupId>"', () {
      final a1 = bbbClub.groups.first;
      expect(bbbClub.roomIdFor(a1), 'BBB:A1');
    });
  });
}
