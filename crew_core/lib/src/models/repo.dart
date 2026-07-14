// crew_core/lib/src/models/repo.dart
class Repo {
  final String path;
  const Repo(this.path);

  Map<String, dynamic> toJson() => {'path': path};

  factory Repo.fromJson(Map<dynamic, dynamic> json) =>
      Repo(json['path'] as String);

  @override
  bool operator ==(Object other) => other is Repo && other.path == path;
  @override
  int get hashCode => path.hashCode;
}
