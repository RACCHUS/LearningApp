// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'test_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TestModel _$TestModelFromJson(Map<String, dynamic> json) => TestModel(
      name: json['name'] as String,
      value: (json['value'] as num).toInt(),
    );

Map<String, dynamic> _$TestModelToJson(TestModel instance) => <String, dynamic>{
      'name': instance.name,
      'value': instance.value,
    };
