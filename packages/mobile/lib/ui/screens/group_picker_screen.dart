import 'package:flutter/material.dart';
import '../../models/riding_group.dart';
import 'call_screen.dart';

/// Lets a rider pick one of club BBB's 7 groups and a signaling server URL,
/// then hands the resulting room id to [onSelect]. When [onSelect] is null it
/// opens the CallScreen for that room. Selection is not persisted.
class GroupPickerScreen extends StatefulWidget {
  final void Function(BuildContext context, String serverUrl, String roomId)?
      onSelect;

  const GroupPickerScreen({super.key, this.onSelect});

  @override
  State<GroupPickerScreen> createState() => _GroupPickerScreenState();
}

class _GroupPickerScreenState extends State<GroupPickerScreen> {
  final _serverController = TextEditingController(text: 'ws://localhost:8080');

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  void _select(RidingGroup group) {
    final roomId = bbbClub.roomIdFor(group);
    final serverUrl = _serverController.text;
    (widget.onSelect ?? _openCallScreen)(context, serverUrl, roomId);
  }

  void _openCallScreen(BuildContext context, String serverUrl, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(serverUrl: serverUrl, roomId: roomId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text('Club ${bbbClub.name} — pick a group')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _serverController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Server URL',
                labelStyle: TextStyle(color: Colors.grey[400]),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final group in bbbClub.groups)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton(
                            key: Key('group_${group.id}'),
                            onPressed: () => _select(group),
                            child: Text(
                              group.name,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
