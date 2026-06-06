import 'dart:math';
import 'package:flutter/material.dart';

class BusStop {
  final String name;
  final String time;
  final String status;
  BusStop({required this.name, required this.time, required this.status});
}

class BusData {
  final String busNo;
  final String route;
  final String busType;
  final String departureTime;
  final String driverName;
  final String driverPhone;
  final String conductorName;
  final String conductorPhone;
  final int eta;
  final String distance;
  final String crowd;
  final double crowdLevel;
  final Color color;
  final List<BusStop> stops;

  BusData({
    required this.busNo,
    required this.route,
    required this.busType,
    required this.departureTime,
    required this.driverName,
    required this.driverPhone,
    required this.conductorName,
    required this.conductorPhone,
    required this.eta,
    required this.distance,
    required this.crowd,
    required this.crowdLevel,
    required this.color,
    required this.stops,
  });

  Map<String, dynamic> toMap() => {
        'busNo': busNo,
        'route': route,
        'busType': busType,
        'departureTime': departureTime,
        'driverName': driverName,
        'conductorName': conductorName,
        'eta': eta,
        'distance': distance,
        'crowd': crowd,
        'crowdLevel': crowdLevel,
        'color': color,
        'stops': stops,
      };
}

/// Rural stops around Belagavi (CBT is the central bus terminal).
final List<String> ruralStops = [
  'CBT',
  'Tilakwadi',
  'Vadgaon',
  'Angol',
  'Hindalga',
  'Gokak Falls',
  'Gokak Town',
  'Soudatti',
  'Athani',
  'Bailhongal',
  'Saundatti',
  'Munavalli',
  'Ramdurg',
  'Lokapur',
  'Badami',
  'Hukkeri',
  'Nippani',
  'Chikkodi',
  'Khanapur',
  'Castle Rock',
  'Dandeli',
  'Sankeshwar',
  'Yaragatti',
  'Kittur',
  'Nesargi',
  'Konnur',
  'Kudchi',
  'Raibag',
  'Jamkhandi',
  'Mudhol',
  'Bagalkot',
  'Hungund',
  'Bijapur Road',
  'Kakati',
  'Uchagaon',
  'Shahapur',
  'Haliyal',
  'Yellapur',
  'Ankola',
  'Karwar Road',
];

final List<String> allStops = [
  ...ruralStops,
  'Bengaluru',
  'Mysuru',
  'Mangaluru',
  'Hubballi',
  'Dharwad',
  'Vijayapura',
  'Kalaburagi',
  'Raichur',
  'Bidar',
  'Gadag',
  'Hassan',
  'Shivamogga',
  'Davangere',
];

String normalizeStopName(String input) {
  final q = input.trim().toLowerCase();
  if (q.isEmpty) return '';
  if (q == 'cbt' || q.contains('belagavi cbt') || q.contains('belagavi cbs') || q == 'cbs') {
    return 'cbt';
  }
  return q;
}

bool stopMatches(String stopName, String query) {
  final n = normalizeStopName(stopName);
  final q = normalizeStopName(query);
  if (q.isEmpty) return false;
  if (n == q) return true;
  return n.contains(q) || q.contains(n);
}

int _stopIndex(BusData bus, String query) {
  for (var i = 0; i < bus.stops.length; i++) {
    if (stopMatches(bus.stops[i].name, query)) return i;
  }
  return -1;
}

/// Buses that serve [from] then [to] in route order (e.g. Tilakwadi → CBT).
List<BusData> searchBuses(String from, String to) {
  if (from.trim().isEmpty || to.trim().isEmpty) return [];
  return allBuses.where((bus) {
    final fi = _stopIndex(bus, from);
    final ti = _stopIndex(bus, to);
    return fi != -1 && ti != -1 && fi < ti;
  }).toList()
    ..sort((a, b) => a.eta.compareTo(b.eta));
}

/// Buses that will reach the user's stop on the way toward CBT.
List<BusData> searchBusesToCbt(String fromLocation) {
  return searchBuses(fromLocation, 'CBT');
}

final _busColors = [
  const Color(0xFF1A3A5C),
  const Color(0xFF2E7D32),
  const Color(0xFF6A1B9A),
  const Color(0xFF00695C),
  const Color(0xFFB71C1C),
  const Color(0xFF1565C0),
  const Color(0xFFE65100),
  const Color(0xFF4527A0),
  const Color(0xFF558B2F),
  const Color(0xFFAD1457),
];

final _busTypes = ['Ordinary', 'Express', 'Rajahamsa', 'Karnataka Sarige', 'Airavat'];
final _crowds = ['Light', 'Moderate', 'Crowded'];
final _driverFirst = ['Raju', 'Mahesh', 'Basavraj', 'Nagesh', 'Santosh', 'Prakash', 'Vinod', 'Suresh', 'Girish', 'Anand'];
final _driverLast = ['Patil', 'Desai', 'Hungund', 'Kulkarni', 'Naik', 'Goudar', 'Kamble', 'Metri', 'Joshi', 'Sutar'];
final _conductorFirst = ['Suresh', 'Vinod', 'Prakash', 'Ramesh', 'Girish', 'Kumar', 'Shiva', 'Ravi', 'Deepak', 'Manoj'];
final _conductorLast = ['Kumar', 'Naik', 'Metri', 'Goudar', 'Kamble', 'Patil', 'Desai', 'Hiremath', 'Katti', 'Biradar'];

String _formatTime(int minutesFromMidnight) {
  final h = (minutesFromMidnight ~/ 60) % 24;
  final m = minutesFromMidnight % 60;
  final period = h >= 12 ? 'PM' : 'AM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
}

List<BusStop> _buildStops(List<String> routeStops, int seed) {
  final rng = Random(seed);
  var baseMinutes = 360 + (seed % 12) * 45;
  final stops = <BusStop>[];
  final span = routeStops.length > 2 ? routeStops.length - 2 : 1;
  final currentIdx = 1 + (seed % span);

  for (var i = 0; i < routeStops.length; i++) {
    String status;
    if (i < currentIdx) {
      status = 'passed';
    } else if (i == currentIdx) {
      status = 'current';
    } else {
      status = 'upcoming';
    }
    stops.add(BusStop(
      name: routeStops[i],
      time: _formatTime(baseMinutes),
      status: status,
    ));
    baseMinutes += 12 + rng.nextInt(18);
  }
  return stops;
}

BusData _makeBus({
  required int index,
  required List<String> routeStops,
  required String routeLabel,
}) {
  final rng = Random(index * 97);
  final color = _busColors[index % _busColors.length];
  final crowdIdx = rng.nextInt(3);
  final crowdLevel = crowdIdx == 0 ? 0.15 + rng.nextDouble() * 0.25 : crowdIdx == 1 ? 0.4 + rng.nextDouble() * 0.25 : 0.75 + rng.nextDouble() * 0.2;
  final num = 1000 + index;
  final busNo = 'KA 22 F $num';
  final df = _driverFirst[rng.nextInt(_driverFirst.length)];
  final dl = _driverLast[rng.nextInt(_driverLast.length)];
  final cf = _conductorFirst[rng.nextInt(_conductorFirst.length)];
  final cl = _conductorLast[rng.nextInt(_conductorLast.length)];
  final depMin = 300 + (index % 20) * 30;
  final stops = _buildStops(routeStops, index);

  return BusData(
    busNo: busNo,
    route: routeLabel,
    busType: _busTypes[index % _busTypes.length],
    departureTime: _formatTime(depMin),
    driverName: '$df $dl',
    driverPhone: '98${(70000000 + index * 137).toString().substring(0, 8)}',
    conductorName: '$cf $cl',
    conductorPhone: '98${(80000000 + index * 149).toString().substring(0, 8)}',
    eta: 2 + (index % 35),
    distance: '${(1.5 + (index % 25) * 0.4).toStringAsFixed(1)} km',
    crowd: _crowds[crowdIdx],
    crowdLevel: crowdLevel,
    color: color,
    stops: stops,
  );
}

List<BusData> _generateBuses() {
  final buses = <BusData>[];
  var idx = 0;

  // Hand-crafted flagship routes
  buses.add(_makeBus(
    index: idx++,
    routeStops: ['CBT', 'Tilakwadi', 'Vadgaon', 'Gokak Falls', 'Gokak Town', 'Athani'],
    routeLabel: 'CBT → Gokak → Athani',
  ));
  buses.add(_makeBus(
    index: idx++,
    routeStops: ['CBT', 'Angol', 'Hindalga', 'Bailhongal', 'Saundatti'],
    routeLabel: 'CBT → Bailhongal → Saundatti',
  ));
  buses.add(_makeBus(
    index: idx++,
    routeStops: ['CBT', 'Munavalli', 'Ramdurg', 'Lokapur', 'Badami'],
    routeLabel: 'CBT → Ramdurg → Badami',
  ));
  buses.add(_makeBus(
    index: idx++,
    routeStops: ['CBT', 'Hukkeri', 'Nippani', 'Chikkodi'],
    routeLabel: 'CBT → Hukkeri → Chikkodi',
  ));
  buses.add(_makeBus(
    index: idx++,
    routeStops: ['CBT', 'Khanapur', 'Castle Rock', 'Dandeli'],
    routeLabel: 'CBT → Khanapur → Dandeli',
  ));

  final midPoints = ruralStops.where((s) => s != 'CBT').toList();

  while (buses.length < 105) {
    final rng = Random(idx * 131);
    final destCount = 2 + rng.nextInt(4);
    final routeStops = <String>['CBT'];
    final used = <String>{'CBT'};
    while (routeStops.length < destCount + 1) {
      final pick = midPoints[rng.nextInt(midPoints.length)];
      if (used.add(pick)) routeStops.add(pick);
    }
    final label = routeStops.join(' → ');
    buses.add(_makeBus(index: idx++, routeStops: routeStops, routeLabel: label));

    // Reverse / feeder routes toward CBT
    if (buses.length < 105 && routeStops.length >= 3) {
      final reversed = routeStops.reversed.toList();
      buses.add(_makeBus(
        index: idx++,
        routeStops: reversed,
        routeLabel: reversed.join(' → '),
      ));
    }
  }

  return buses;
}

final List<BusData> allBuses = _generateBuses();
