import 'package:flutter/foundation.dart';

extension MapUtils<K, V> on Map<K, V> {
  void addIfNotNull(K key, V value) {
    if (key != null && value != null) {
      this[key] = value;
    }
  }
}

typedef NotificationAction = void Function();

class AndroidResDrawable {
  final String name;

  AndroidResDrawable({required this.name});
}

@immutable
class NotificationSettings {
  //region configs
  /// both android & ios
  final bool nextEnabled;

  /// both android & ios
  final bool playPauseEnabled;

  /// both android & ios
  final bool prevEnabled;

  /// both android & ios
  final bool seekBarEnabled;

  /// android only
  final bool stopEnabled;
  //endregion

  //region customizers
  /// null for default behavior
  final NotificationAction? customNextAction;

  /// null for default behavior
  final NotificationAction? customPlayPauseAction;

  /// null for default behavior
  final NotificationAction? customPrevAction;

  /// null for default behavior
  final NotificationAction? customStopAction;

  //no custom action for stop

  //custom icon
  final AndroidResDrawable? customNextIcon;
  final AndroidResDrawable? customPreviousIcon;
  final AndroidResDrawable? customPlayIcon;
  final AndroidResDrawable? customPauseIcon;
  final AndroidResDrawable? customStopIcon;
  final AndroidResDrawable? customPrevIcon;

  //endregion

  const NotificationSettings({
    this.playPauseEnabled = true,
    this.nextEnabled = true,
    this.prevEnabled = true,
    this.stopEnabled = true,
    this.seekBarEnabled = true,
    this.customNextAction,
    this.customPlayPauseAction,
    this.customPrevAction,
    this.customStopAction,
    this.customNextIcon,
    this.customPauseIcon,
    this.customPlayIcon,
    this.customPreviousIcon,
    this.customStopIcon,
    this.customPrevIcon,
  });
}

void writeNotificationSettingsInto(
    Map<String, dynamic> params, NotificationSettings notificationSettings) {
  params['notif.settings.nextEnabled'] = notificationSettings.nextEnabled;
  params['notif.settings.stopEnabled'] = notificationSettings.stopEnabled;
  params['notif.settings.playPauseEnabled'] =
      notificationSettings.playPauseEnabled;
  params['notif.settings.prevEnabled'] = notificationSettings.prevEnabled;
  params['notif.settings.seekBarEnabled'] = notificationSettings.seekBarEnabled;

  params.addIfNotNull(
      'notif.settings.playIcon', notificationSettings.customPlayIcon?.name);
  params.addIfNotNull(
      'notif.settings.pauseIcon', notificationSettings.customPauseIcon?.name);
  params.addIfNotNull(
      'notif.settings.nextIcon', notificationSettings.customNextIcon?.name);
  params.addIfNotNull('notif.settings.previousIcon',
      notificationSettings.customPreviousIcon?.name);
  params.addIfNotNull(
      'notif.settings.stopIcon', notificationSettings.customStopIcon?.name);
}
