import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// 13 Primary Legal Categories for Uzbekistan legislation
class LegalCategory extends Equatable {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int caseCount;

  const LegalCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.caseCount = 0,
  });

  @override
  List<Object?> get props => [id, title, description, icon, color, caseCount];
}
