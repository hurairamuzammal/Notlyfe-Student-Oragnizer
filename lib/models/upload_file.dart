class UserFiles {
  final int id;
  final String filePath;
  final String fileName;
  final String fileType;
  final dynamic userId;
  final String courseId;
  final int fileSize;
  bool isDownloaded;
  bool isDownloading;

  UserFiles({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.userId,
    required this.courseId,
    this.fileSize = 0,
    this.isDownloaded = false,
    this.isDownloading = false,
  });

  bool get isGoogleDrive => filePath.startsWith('gdrive://');
  bool get isWebDav => filePath.startsWith('webdav://');
  bool get isCustomHttp => filePath.startsWith('customhttp://');
  bool get isLocalDirectory => filePath.startsWith('localdir://');
  bool get isRemoteOrVirtual =>
      filePath.startsWith('http') ||
      isGoogleDrive ||
      isWebDav ||
      isCustomHttp ||
      isLocalDirectory;

  String get driveFileId =>
      isGoogleDrive ? filePath.substring('gdrive://'.length) : '';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType,
      'user_id': userId,
      'course_id': courseId,
      'file_size': fileSize,
    };
  }

  factory UserFiles.fromMap(Map<String, dynamic> map) {
    return UserFiles(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse(map['id'].toString()) ?? 0,
      filePath: (map['file_path'] ?? '').toString(),
      fileName: (map['file_name'] ?? 'Untitled').toString(),
      fileType: (map['file_type'] ?? 'application/octet-stream').toString(),
      userId: map['user_id'] ?? '',
      courseId: (map['course_id'] ?? '').toString(),
      fileSize: map['file_size'] is int
          ? map['file_size'] as int
          : int.tryParse(map['file_size']?.toString() ?? '0') ?? 0,
    );
  }
}
