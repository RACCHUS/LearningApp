import 'package:json_annotation/json_annotation.dart';

part 'test_model.g.dart';

@JsonSerializable()
class TestModel {
  final String name;
  final int value;

  TestModel({required this.name, required this.value});
  
  factory TestModel.fromJson(Map<String, dynamic> json) => _$TestModelFromJson(json);
  Map<String, dynamic> toJson() => _$TestModelToJson(this);
}
