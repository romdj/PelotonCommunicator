import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ptt_state.dart';
import '../../services/ptt_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Consumer<PTTService>(
              builder: (context, pttService, child) {
                return Column(
                  children: [
                    // Main PTT Button (On-Screen PTT)
                    GestureDetector(
                      onTapDown: pttService.button == PTTButton.onScreen &&
                              pttService.mode.isToggle
                          ? (_) => pttService.manualPress()
                          : null,
                      onLongPressStart: pttService.button == PTTButton.onScreen &&
                              pttService.mode.isHold
                          ? (_) => pttService.manualPress()
                          : null,
                      onLongPressEnd: pttService.button == PTTButton.onScreen &&
                              pttService.mode.isHold
                          ? (_) => pttService.manualRelease()
                          : null,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pttService.state.isActive
                              ? Colors.green
                              : Colors.red,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: pttService.button == PTTButton.onScreen
                              ? [
                                  BoxShadow(
                                    color: pttService.state.isActive
                                        ? Colors.green.withOpacity(0.5)
                                        : Colors.red.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.mic,
                              size: 100,
                              color: Colors.white,
                            ),
                            if (pttService.button == PTTButton.onScreen)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  pttService.mode.isToggle ? 'TAP' : 'HOLD',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Status Text
                    Text(
                      pttService.state.isActive ? 'RECORDING' : 'READY',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Current button configuration
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pttService.button.icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pttService.button.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _getInstructionText(pttService),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // PTT Mode Switch
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'PTT Mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pttService.mode.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      pttService.mode.description,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: pttService.mode.isHold,
                                onChanged: (value) {
                                  pttService.setMode(
                                    value ? PTTMode.hold : PTTMode.toggle,
                                  );
                                },
                                activeColor: Colors.orange,
                                inactiveThumbColor: Colors.green,
                                inactiveTrackColor: Colors.green.withOpacity(
                                  0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Manual test buttons (for debugging)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => pttService.manualPress(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Test Press'),
                        ),
                        ElevatedButton(
                          onPressed: () => pttService.manualRelease(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Test Release'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getInstructionText(PTTService pttService) {
    final buttonName = pttService.button == PTTButton.onScreen
        ? 'on-screen button'
        : pttService.button.displayName.toLowerCase();

    if (pttService.state.isActive) {
      return pttService.mode.isToggle
          ? 'Press $buttonName again to stop recording'
          : 'Release $buttonName to stop recording';
    } else {
      if (pttService.button == PTTButton.onScreen) {
        return pttService.mode.isToggle
            ? 'Tap the button to start recording'
            : 'Press and hold the button to record';
      } else {
        return pttService.mode.isToggle
            ? 'Press $buttonName to start recording'
            : 'Hold $buttonName to record';
      }
    }
  }
}
