class UserPrefs {
  final String? selectedMode;
  final String? boxIp;
  final int boxPort;
  final String? vncPassword;
  final bool onboarded;

  const UserPrefs({
    this.selectedMode,
    this.boxIp,
    this.boxPort = 5900,
    this.vncPassword,
    this.onboarded = false,
  });

  UserPrefs copyWith({
    String? selectedMode,
    String? boxIp,
    int? boxPort,
    String? vncPassword,
    bool? onboarded,
  }) {
    return UserPrefs(
      selectedMode: selectedMode ?? this.selectedMode,
      boxIp: boxIp ?? this.boxIp,
      boxPort: boxPort ?? this.boxPort,
      vncPassword: vncPassword ?? this.vncPassword,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, dynamic> toJson() => {
    'selectedMode': selectedMode,
    'boxIp': boxIp,
    'boxPort': boxPort,
    'vncPassword': vncPassword,
    'onboarded': onboarded,
  };

  factory UserPrefs.fromJson(Map<String, dynamic> json) => UserPrefs(
    selectedMode: json['selectedMode'],
    boxIp: json['boxIp'],
    boxPort: json['boxPort'] ?? 5900,
    vncPassword: json['vncPassword'],
    onboarded: json['onboarded'] ?? false,
  );
}
