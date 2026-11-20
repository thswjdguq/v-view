import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/session/profile_catalog_datasource.dart';
import '../../domain/session_setup/profile_catalog.dart';

final profileCatalogProvider =
    FutureProvider.family<List<ProfileCatalogEntry>, ProfileCatalogType>(
      (ref, type) => ProfileCatalogDatasource().load(type),
    );
