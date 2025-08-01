abstract class BaseLesson {
  String get id;
  String get title;
  String? get description;
  List<String> get tags;
  DateTime get createdAt;
  bool get isLocal;
}
