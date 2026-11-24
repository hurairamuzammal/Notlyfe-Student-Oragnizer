// ignore_for_file: non_constant_identifier_names

class UserProfile {
  final String user_id;
  final String name;

  const UserProfile({required this.user_id, required this.name});

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      user_id: map['user_id']?.toString() ?? '',
      name: map['full_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': user_id,
      'full_name': name,
    };
  }
}
