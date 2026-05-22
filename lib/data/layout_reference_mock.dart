import 'vibe_catalog.dart';

class DiscoverPlace {
  const DiscoverPlace({
    required this.id,
    required this.name,
    required this.vibe,
    required this.rating,
    required this.reviews,
    required this.address,
    required this.distance,
    required this.open,
  });

  final String id;
  final String name;
  final SquadVibe vibe;
  final double rating;
  final int reviews;
  final String address;
  final String distance;
  final bool open;
}

const kDiscoverPlaces = <DiscoverPlace>[
  DiscoverPlace(
    id: 'p1',
    name: 'Riverside Basketball Courts',
    vibe: SquadVibe.hoops,
    rating: 4.6,
    reviews: 124,
    address: '12 Riverside Dr',
    distance: '0.3 mi',
    open: true,
  ),
  DiscoverPlace(
    id: 'p2',
    name: 'Half-Court Park',
    vibe: SquadVibe.hoops,
    rating: 4.5,
    reviews: 44,
    address: '67 Park Ave',
    distance: '1.5 mi',
    open: true,
  ),
  DiscoverPlace(
    id: 'p3',
    name: 'The Beanery Coffee',
    vibe: SquadVibe.cafe,
    rating: 4.7,
    reviews: 320,
    address: '88 Main St',
    distance: '0.5 mi',
    open: true,
  ),
  DiscoverPlace(
    id: 'p4',
    name: 'Grind Spot Cafe',
    vibe: SquadVibe.cafe,
    rating: 4.5,
    reviews: 155,
    address: '22 Oak Lane',
    distance: '0.9 mi',
    open: true,
  ),
  DiscoverPlace(
    id: 'p5',
    name: 'City View Pool',
    vibe: SquadVibe.swim,
    rating: 4.8,
    reviews: 89,
    address: '5 Skyline Rd',
    distance: '1.2 mi',
    open: true,
  ),
  DiscoverPlace(
    id: 'p6',
    name: 'Quiet Library',
    vibe: SquadVibe.study,
    rating: 4.9,
    reviews: 210,
    address: '100 Scholar Way',
    distance: '0.7 mi',
    open: true,
  ),
];

class RecapItem {
  const RecapItem({
    required this.id,
    required this.title,
    required this.vibe,
    required this.location,
    required this.date,
    required this.people,
    required this.highlight,
    required this.shared,
  });

  final String id;
  final String title;
  final SquadVibe vibe;
  final String location;
  final String date;
  final List<String> people;
  final String highlight;
  final bool shared;
}

const kRecapItems = <RecapItem>[
  RecapItem(
    id: 'r1',
    title: 'Sunset Hoops Session',
    vibe: SquadVibe.hoops,
    location: 'Riverside Courts',
    date: 'April 15, 2026',
    people: ['You', 'Mia', 'Tyler', 'Zara'],
    highlight: 'Epic 3v3, someone hit a half-court shot',
    shared: true,
  ),
  RecapItem(
    id: 'r2',
    title: 'Late Night Study Grind',
    vibe: SquadVibe.study,
    location: 'Quiet Library',
    date: 'April 12, 2026',
    people: ['You', 'Ravi', 'Jamie'],
    highlight: 'Finished the project, rewarded ourselves with bubble tea',
    shared: false,
  ),
];
