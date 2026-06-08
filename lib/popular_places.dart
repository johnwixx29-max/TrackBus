import 'package:flutter/material.dart';

class PopularPlace {
  final String name;
  final String searchKey;
  final String imageUrl;
  final String subtitle;

  const PopularPlace({
    required this.name,
    required this.searchKey,
    required this.imageUrl,
    required this.subtitle,
  });
}

/// Famous destinations around Belagavi — used on home & place detail screens.
const popularPlaces = <PopularPlace>[
  PopularPlace(
    name: 'Amboli',
    searchKey: 'Amboli',
    imageUrl:
        'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&q=80',
    subtitle: 'Hill station via Khanapur',
  ),
  PopularPlace(
    name: 'Gokak Falls',
    searchKey: 'Gokak Falls',
    imageUrl:
        'https://images.unsplash.com/photo-1439066615861-d1af74d74000?w=400&q=80',
    subtitle: 'Famous waterfall',
  ),
  PopularPlace(
    name: 'Dandeli',
    searchKey: 'Dandeli',
    imageUrl:
        'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&q=80',
    subtitle: 'Wildlife & adventure',
  ),
  PopularPlace(
    name: 'Badami',
    searchKey: 'Badami',
    imageUrl:
        'https://images.unsplash.com/photo-1524492412937-280c90fd039e?w=400&q=80',
    subtitle: 'Historic caves',
  ),
  PopularPlace(
    name: 'Saundatti',
    searchKey: 'Saundatti',
    imageUrl:
        'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=400&q=80',
    subtitle: 'Yellamma temple town',
  ),
];

List<String> suggestedStops = [
  'CBT',
  'Chikkodi',
  'Gokak Falls',
  'Dandeli',
  'Athani',
  'Hubli',
  'Khanapur',
  'Badami',
];
