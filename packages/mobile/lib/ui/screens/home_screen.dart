import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ptt_state.dart';
import '../../services/ptt_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Consumer<PTTService>(
              builder: (context, pttService, child) {
                return Column(
                  children: [
                    // Main PTT Icon
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pttService.state.isActive
                            ? Colors.green
                            : Colors.red,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: const Icon(
                        Icons.mic,
                        size: 100,
                        color: Colors.white,
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
    if (pttService.state.isActive) {
      return pttService.mode.isToggle
          ? 'Press button again to stop recording'
          : 'Release button to stop recording';
    } else {
      return pttService.mode.isToggle
          ? 'Press play/pause button to start recording'
          : 'Hold play/pause button to record';
    }
  }
}
