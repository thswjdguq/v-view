import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../domain/session_setup/profile_catalog.dart';

class ProfileCatalogDatasource {
  Future<List<ProfileCatalogEntry>> load(ProfileCatalogType type) async {
    final file = type == ProfileCatalogType.school
        ? 'schools'
        : 'certifications';
    final raw =
        jsonDecode(await rootBundle.loadString('assets/catalogs/$file.json'))
            as Map<String, dynamic>;
    return List.unmodifiable(
      (raw['entries'] as List).map(
        (e) => ProfileCatalogEntry.fromMap(e as Map<String, dynamic>),
      ),
    );
  }
}
