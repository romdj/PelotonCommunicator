import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ptt_state.dart';
import '../../services/ptt_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('PTT Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<PTTService>(
        builder: (context, pttService, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // PTT Mode Section
              _buildSectionTitle('PTT Mode'),
              _buildModeSelector(pttService),

              const SizedBox(height: 32),

              // PTT Button Section
              _buildSectionTitle('PTT Button'),
              _buildButtonSelector(pttService),

              const SizedBox(height: 32),

              // Screen Lock Section
              _buildSectionTitle('Screen Lock'),
              _buildScreenLockSwitch(pttService),

              const SizedBox(height: 32),

              // Info Section
              _buildInfoCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildModeSelector(PTTService pttService) {
    // Disable hold mode when play/pause button is selected
    final isPlayPauseButton = pttService.button == PTTButton.playPause;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: PTTMode.values.map((mode) {
          final isSelected = pttService.mode == mode;
          final isDisabled = isPlayPauseButton && mode == PTTMode.hold;

          return InkWell(
            onTap: isDisabled ? null : () => pttService.setMode(mode),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepOrange.withOpacity(0.2) : Colors.transparent,
                border: Border(
                  bottom: mode != PTTMode.values.last
                      ? BorderSide(color: Colors.white10)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isDisabled
                        ? Colors.white24
                        : (isSelected ? Colors.deepOrange : Colors.white54),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mode.displayName,
                          style: TextStyle(
                            color: isDisabled
                                ? Colors.white30
                                : (isSelected ? Colors.white : Colors.white70),
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDisabled
                              ? 'Not available for play/pause button (use toggle mode)'
                              : mode.description,
                          style: TextStyle(
                            color: isDisabled ? Colors.white30 : Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButtonSelector(PTTService pttService) {
    // Get platform-specific available buttons
    final availableButtons = PTTButton.values.where((button) {
      if (Platform.isAndroid) {
        return button.isAvailableOnAndroid;
      }
      // iOS: All buttons available except systemPTT handled above
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: availableButtons.map((button) {
          final isSelected = pttService.button == button;
          final isLast = button == availableButtons.last;

          return InkWell(
            onTap: () => pttService.setButton(button),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepOrange.withOpacity(0.2) : Colors.transparent,
                border: Border(
                  bottom: !isLast
                      ? BorderSide(color: Colors.white10)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.deepOrange : Colors.white54,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    button.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          button.displayName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          button.description,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScreenLockSwitch(PTTService pttService) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.screen_lock_portrait,
            color: Colors.white70,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prevent Screen Lock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep screen on during rides',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: pttService.config.preventScreenLock,
            onChanged: (value) => pttService.setPreventScreenLock(value),
            activeColor: Colors.deepOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[300],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Platform Tips',
                style: TextStyle(
                  color: Colors.blue[100],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            Platform.isAndroid ? '🤖 Android' : '🍎 iOS',
            Platform.isAndroid
                ? 'Volume and play/pause buttons work with device and headsets. Long-press is prevented to avoid Google Assistant. Note: BT headset volume buttons are unsupported (system limitation).'
                : 'Volume and play/pause buttons recommended. Note: Long-press may trigger Siri - use toggle mode with quick taps.',
          ),
          if (Platform.isIOS) ...[
            const SizedBox(height: 8),
            _buildInfoItem(
              '⚠️ iOS Limitation',
              'Headset long-press cannot prevent Siri. Use toggle mode for best experience.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.blue[200],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.blue[100],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
