class UserRole {
  final int id;
  final String roleName;
  final String roleDescription;

  const UserRole({
    required this.id,
    required this.roleName,
    required this.roleDescription,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) => UserRole(
        id: json['id'] as int,
        roleName: json['roleName'] as String? ?? '',
        roleDescription: json['roleDescription'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roleName': roleName,
        'roleDescription': roleDescription,
      };
}

class User {
  final int id;
  final String username;
  final String email;
  final UserRole userRole;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.userRole,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        userRole: UserRole.fromJson(
            json['userRole'] as Map<String, dynamic>? ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'userRole': userRole.toJson(),
      };

  String get initials {
    final parts = username.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : 'U';
  }
}
