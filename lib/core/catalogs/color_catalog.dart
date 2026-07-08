import 'package:flutter/material.dart';

/// Catalog entry for a player seat color.
class CatalogColor {
  const CatalogColor({
    required this.id,
    required this.displayName,
    required this.color,
  });

  final String id;
  final String displayName;
  final Color color;
}

/// Eight vivid player colors (MVP palette).
class ColorCatalog {
  ColorCatalog._();

  static const List<CatalogColor> all = [
    CatalogColor(id: 'color_1', displayName: 'Rojo', color: Color(0xFFE53935)),
    CatalogColor(id: 'color_2', displayName: 'Azul', color: Color(0xFF1E88E5)),
    CatalogColor(id: 'color_3', displayName: 'Verde', color: Color(0xFF43A047)),
    CatalogColor(id: 'color_4', displayName: 'Amarillo', color: Color(0xFFFDD835)),
    CatalogColor(id: 'color_5', displayName: 'Naranja', color: Color(0xFFFB8C00)),
    CatalogColor(id: 'color_6', displayName: 'Morado', color: Color(0xFF8E24AA)),
    CatalogColor(id: 'color_7', displayName: 'Cian', color: Color(0xFF00ACC1)),
    CatalogColor(id: 'color_8', displayName: 'Rosa', color: Color(0xFFD81B60)),
  ];

  static const defaultPreferredIds = ['color_1', 'color_2', 'color_3'];

  static CatalogColor? byId(String id) {
    for (final entry in all) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  static List<String> allIds() => all.map((entry) => entry.id).toList();
}
