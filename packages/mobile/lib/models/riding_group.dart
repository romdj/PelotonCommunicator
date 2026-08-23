/// A riding group within a club — the unit that maps 1:1 to a WebRTC room.
class RidingGroup {
  final String id;
  final String name;
  const RidingGroup({required this.id, required this.name});
}

/// A club that owns a fixed set of riding groups.
class Club {
  final String id;
  final String name;
  final List<RidingGroup> groups;
  const Club({required this.id, required this.name, required this.groups});

  /// Room id for [group], e.g. 'BBB:A1'. Distinct groups => isolated rooms.
  String roomIdFor(RidingGroup group) => '$id:${group.id}';
}

/// The single MVP club: BBB with 7 fixed groups.
const Club bbbClub = Club(
  id: 'BBB',
  name: 'BBB',
  groups: [
    RidingGroup(id: 'A1', name: 'A1'),
    RidingGroup(id: 'A2', name: 'A2'),
    RidingGroup(id: 'A3', name: 'A3'),
    RidingGroup(id: 'A4', name: 'A4'),
    RidingGroup(id: 'B1', name: 'B1'),
    RidingGroup(id: 'B2', name: 'B2'),
    RidingGroup(id: 'B3', name: 'B3'),
  ],
);
