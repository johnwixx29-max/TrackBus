import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'localization.dart';
import 'popular_places.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nlbbvahjcavhftxaozvf.supabase.co',
    anonKey: 'sb_publishable_vks3-LHIOvUwp9zihlBFGA_X-N-6KD9',
  );

  await testSupabaseConnection();

  await AuthService.init();
  await AppLang.init();
  runApp(const TrackBusApp());
}

Future<void> testSupabaseConnection() async {
  try {
    final response = await supabase.from('buses').select().limit(1);
    print('✅ Supabase connected! Response: $response');
  } catch (e) {
    print('❌ Supabase error: $e');
  }
}

Future<void> testInsertData() async {
  try {
    // Insert a test bus into the buses table
    await supabase.from('buses').insert({
      'bus_no': 'KA22F1001',
      'route': 'CBT → Gokak → Athani',
      'driver_name': 'Raju Patil',
      'driver_phone': '9876543201',
      'conductor_name': 'Suresh Kumar',
      'conductor_phone': '9876543202',
      'eta': 5,
      'distance': '2.1 km',
      'crowd': 'Moderate',
      'crowd_level': 0.5,
      'color_hex': '#1A3A5C',
      'is_active': true,
    });
    print('✅ Data inserted successfully!');
  } catch (e) {
    print('❌ Insert error: $e');
  }
}

final supabase = Supabase.instance.client;

class TrackBusApp extends StatefulWidget {
  const TrackBusApp({super.key});

  @override
  State<TrackBusApp> createState() => _TrackBusAppState();
}

class _TrackBusAppState extends State<TrackBusApp> {
  @override
  void initState() {
    super.initState();
    AppLang.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppLang.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrackBus',
      debugShowCheckedModeBanner: false,
      locale: Locale(AppLang.currentCode),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF4A024)),
        primaryColor: const Color(0xFFF4A024),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ─── SESSION ─────────────────────────────────────────────────────────────────

class UserSession {
  static bool isNewUser = true;
  static List<Map<String, dynamic>> travelHistory = [];

  static void addTrip(Map<String, dynamic> bus, String destination) {
    final exists = travelHistory
        .any((t) => t['busNo'] == bus['busNo'] && t['to'] == destination);
    if (!exists) {
      travelHistory.insert(0, {
        ...bus,
        'from': 'CBT',
        'to': destination,
        'lastTravelled': 'Today',
      });
    }
    isNewUser = false;
    // Save trip to Supabase
    _saveTripToSupabase(bus, destination);
  }

  static Future<void> _saveTripToSupabase(
      Map<String, dynamic> bus, String destination) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      await supabase.from('trips').insert({
        'user_id': userId,
        'bus_no': bus['busNo'],
        'route': bus['route'],
        'destination': destination,
        'crowd': bus['crowd'],
        'crowd_level': bus['crowdLevel'],
        'travelled_at': DateTime.now().toIso8601String(),
      });
      print('✅ Trip saved to Supabase!');
    } catch (e) {
      print('⚠️ Trip save error: \$e');
    }
  }
}

// ─── DATA ────────────────────────────────────────────────────────────────────

class BusStop {
  final String name;
  final String time;
  final String status; // passed / current / upcoming
  BusStop({required this.name, required this.time, required this.status});
}

class BusData {
  final String busNo;
  final String route;
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

final List<BusData> allBuses = [
  BusData(
    busNo: 'KA 22 F 1234',
    route: 'Belagavi → Gokak → Athani',
    driverName: 'Raju Patil',
    driverPhone: '9876543210',
    conductorName: 'Suresh Kumar',
    conductorPhone: '9876543211',
    eta: 5,
    distance: '2.1 km',
    crowd: 'Moderate',
    crowdLevel: 0.5,
    color: const Color(0xFF1A3A5C),
    stops: [
      BusStop(name: 'CBT', time: '07:00 AM', status: 'passed'),
      BusStop(name: 'Tilakwadi', time: '07:12 AM', status: 'passed'),
      BusStop(name: 'Vadgaon', time: '07:25 AM', status: 'current'),
      BusStop(name: 'Gokak Falls', time: '07:50 AM', status: 'upcoming'),
      BusStop(name: 'Gokak Town', time: '08:10 AM', status: 'upcoming'),
      BusStop(name: 'Soudatti', time: '08:35 AM', status: 'upcoming'),
      BusStop(name: 'Athani', time: '09:00 AM', status: 'upcoming'),
    ],
  ),
  BusData(
    busNo: 'KA 22 F 5678',
    route: 'Belagavi → Bailhongal → Saundatti',
    driverName: 'Mahesh Desai',
    driverPhone: '9845012345',
    conductorName: 'Vinod Naik',
    conductorPhone: '9845012346',
    eta: 12,
    distance: '4.8 km',
    crowd: 'Light',
    crowdLevel: 0.2,
    color: const Color(0xFF2E7D32),
    stops: [
      BusStop(name: 'CBT', time: '08:00 AM', status: 'passed'),
      BusStop(name: 'Angol', time: '08:15 AM', status: 'passed'),
      BusStop(name: 'Hindalga', time: '08:30 AM', status: 'current'),
      BusStop(name: 'Bailhongal', time: '09:00 AM', status: 'upcoming'),
      BusStop(name: 'Saundatti', time: '09:45 AM', status: 'upcoming'),
    ],
  ),
  BusData(
    busNo: 'KA 22 F 9101',
    route: 'Belagavi → Ramdurg → Badami',
    driverName: 'Basavraj Hungund',
    driverPhone: '9632587410',
    conductorName: 'Prakash Metri',
    conductorPhone: '9632587411',
    eta: 20,
    distance: '8.3 km',
    crowd: 'Crowded',
    crowdLevel: 0.9,
    color: const Color(0xFF6A1B9A),
    stops: [
      BusStop(name: 'CBT', time: '09:00 AM', status: 'passed'),
      BusStop(name: 'Munavalli', time: '09:20 AM', status: 'current'),
      BusStop(name: 'Ramdurg', time: '10:00 AM', status: 'upcoming'),
      BusStop(name: 'Lokapur', time: '10:30 AM', status: 'upcoming'),
      BusStop(name: 'Badami', time: '11:15 AM', status: 'upcoming'),
    ],
  ),
  BusData(
    busNo: 'KA 22 F 7742',
    route: 'Belagavi → Hukkeri → Chikkodi',
    driverName: 'Nagesh Patil',
    driverPhone: '9741236580',
    conductorName: 'Ramesh Goudar',
    conductorPhone: '9741236581',
    eta: 8,
    distance: '3.0 km',
    crowd: 'Crowded',
    crowdLevel: 0.85,
    color: const Color(0xFF00695C),
    stops: [
      BusStop(name: 'CBT', time: '06:30 AM', status: 'passed'),
      BusStop(name: 'Hukkeri', time: '07:10 AM', status: 'current'),
      BusStop(name: 'Nippani', time: '07:50 AM', status: 'upcoming'),
      BusStop(name: 'Chikkodi', time: '08:20 AM', status: 'upcoming'),
    ],
  ),
  BusData(
    busNo: 'KA 22 F 3321',
    route: 'CBT → Khanapur → Dandeli',
    driverName: 'Santosh Kulkarni',
    driverPhone: '9512347896',
    conductorName: 'Girish Kamble',
    conductorPhone: '9512347897',
    eta: 30,
    distance: '11.2 km',
    crowd: 'Light',
    crowdLevel: 0.15,
    color: const Color(0xFFB71C1C),
    stops: [
      BusStop(name: 'CBT', time: '10:00 AM', status: 'passed'),
      BusStop(name: 'Khanapur', time: '10:45 AM', status: 'current'),
      BusStop(name: 'Castle Rock', time: '11:30 AM', status: 'upcoming'),
      BusStop(name: 'Dandeli', time: '12:15 PM', status: 'upcoming'),
    ],
  ),
  // ── Additional 95 buses ──
  ..._extraBuses,
];

List<BusData> get _extraBuses => [
      _b(
          'KA22F1006',
          'CBT → Soundatti → Nargund → Gadag',
          'Vijay More',
          '9865432101',
          'Anil S',
          '9865432102',
          15,
          '6.5 km',
          'Moderate',
          0.55,
          const Color(0xFF0277BD),
          ['CBT', 'Soundatti', 'Nargund', 'Gadag']),
      _b(
          'KA22F1007',
          'CBT → Dharwad → Hubli',
          'Prakash Rao',
          '9754321001',
          'Sunil P',
          '9754321002',
          25,
          '18.0 km',
          'Crowded',
          0.88,
          const Color(0xFF4A148C),
          ['CBT', 'Dharwad', 'Hubli']),
      _b(
          'KA22F1008',
          'CBT → Kittur → Saundatti → Dharwad',
          'Ravi Kumar',
          '9643210901',
          'Mohan L',
          '9643210902',
          18,
          '12.4 km',
          'Light',
          0.25,
          const Color(0xFF006064),
          ['CBT', 'Kittur', 'Saundatti', 'Dharwad']),
      _b(
          'KA22F1009',
          'CBT → Raybag → Mudhol → Jamkhandi',
          'Suresh Patil',
          '9532109801',
          'Kiran D',
          '9532109802',
          35,
          '22.5 km',
          'Light',
          0.18,
          const Color(0xFF1B5E20),
          ['CBT', 'Raybag', 'Mudhol', 'Jamkhandi']),
          // ── Amboli buses: one passing through, one terminating at Amboli
          _b(
            'KA22F3001',
            'CBT → Khanapur → Amboli → Dandeli',
            'Sundar H',
            '9844012345',
            'Raju P',
            '9844012346',
            28,
            '12.4 km',
            'Moderate',
            0.45,
            const Color(0xFF00897B),
            ['CBT', 'Khanapur', 'Amboli', 'Dandeli']),
          _b(
            'KA22F3002',
            'CBT → Khanapur → Amboli',
            'Meena G',
            '9901122334',
            'Sunita R',
            '9901122335',
            40,
            '18.0 km',
            'Light',
            0.22,
            const Color(0xFF6D4C41),
            ['CBT', 'Khanapur', 'Amboli']),
      _b(
          'KA22F1010',
          'CBT → Chikkodi → Nippani → Sangli',
          'Ramesh N',
          '9421098701',
          'Deepak V',
          '9421098702',
          22,
          '15.3 km',
          'Moderate',
          0.6,
          const Color(0xFF880E4F),
          ['CBT', 'Chikkodi', 'Nippani', 'Sangli']),
      _b(
          'KA22F2001',
          'Athani → Soudatti → Gokak Town → CBT',
          'Arjun Patil',
          '9876543211',
          'Kishan K',
          '9876543212',
          7,
          '3.2 km',
          'Moderate',
          0.5,
          const Color(0xFF1565C0),
          ['Athani', 'Soudatti', 'Gokak Town', 'Vadgaon', 'Tilakwadi', 'CBT']),
      _b(
          'KA22F2002',
          'Saundatti → Bailhongal → Hindalga → CBT',
          'Girish More',
          '9845012311',
          'Satish N',
          '9845012312',
          14,
          '5.1 km',
          'Light',
          0.22,
          const Color(0xFF2E7D32),
          ['Saundatti', 'Bailhongal', 'Hindalga', 'Angol', 'CBT']),
      _b(
          'KA22F2003',
          'Badami → Lokapur → Ramdurg → CBT',
          'Lokesh B',
          '9632587411',
          'Naveen P',
          '9632587412',
          22,
          '9.0 km',
          'Crowded',
          0.92,
          const Color(0xFF6A1B9A),
          ['Badami', 'Lokapur', 'Ramdurg', 'Munavalli', 'CBT']),
      _b(
          'KA22F2004',
          'Chikkodi → Nippani → Hukkeri → CBT',
          'Sunil Goud',
          '9741236511',
          'Praveen R',
          '9741236512',
          10,
          '3.8 km',
          'Crowded',
          0.82,
          const Color(0xFF00695C),
          ['Chikkodi', 'Nippani', 'Hukkeri', 'CBT']),
      _b(
          'KA22F2005',
          'Dandeli → Castle Rock → Khanapur → CBT',
          'Manoj K',
          '9512347811',
          'Ashok M',
          '9512347812',
          32,
          '12.0 km',
          'Light',
          0.12,
          const Color(0xFFB71C1C),
          ['Dandeli', 'Castle Rock', 'Khanapur', 'CBT']),
      _b(
          'KA22F2006',
          'Gadag → Nargund → Soundatti → CBT',
          'Santosh R',
          '9865432111',
          'Vijay D',
          '9865432112',
          28,
          '14.2 km',
          'Moderate',
          0.48,
          const Color(0xFF0277BD),
          ['Gadag', 'Nargund', 'Soundatti', 'CBT']),
      _b(
          'KA22F2007',
          'Hubli → Dharwad → CBT',
          'Rajesh K',
          '9754321011',
          'Arun P',
          '9754321012',
          40,
          '19.5 km',
          'Crowded',
          0.78,
          const Color(0xFF4A148C),
          ['Hubli', 'Dharwad', 'CBT']),
      _b(
          'KA22F2008',
          'Dharwad → Saundatti → Kittur → CBT',
          'Mohan S',
          '9643210911',
          'Ravi L',
          '9643210912',
          20,
          '13.1 km',
          'Light',
          0.3,
          const Color(0xFF006064),
          ['Dharwad', 'Saundatti', 'Kittur', 'CBT']),
      _b(
          'KA22F2009',
          'Jamkhandi → Mudhol → Raybag → CBT',
          'Deepak P',
          '9532109811',
          'Suresh V',
          '9532109812',
          38,
          '23.8 km',
          'Light',
          0.2,
          const Color(0xFF1B5E20),
          ['Jamkhandi', 'Mudhol', 'Raybag', 'CBT']),
      _b(
          'KA22F2010',
          'Sangli → Nippani → Chikkodi → CBT',
          'Vinay N',
          '9421098711',
          'Kiran M',
          '9421098712',
          25,
          '16.0 km',
          'Moderate',
          0.55,
          const Color(0xFF880E4F),
          ['Sangli', 'Nippani', 'Chikkodi', 'CBT']),
      _b(
          'KA22F3001',
          'Tilakwadi → CBT → Gokak Town',
          'Amar Joshi',
          '9312345601',
          'Rahul S',
          '9312345602',
          6,
          '1.5 km',
          'Light',
          0.3,
          const Color(0xFF37474F),
          ['Tilakwadi', 'CBT', 'Vadgaon', 'Gokak Falls', 'Gokak Town']),
      _b(
          'KA22F3002',
          'Angol → CBT → Bailhongal',
          'Balu Patil',
          '9213456501',
          'Chetan D',
          '9213456502',
          9,
          '2.8 km',
          'Moderate',
          0.52,
          const Color(0xFF4E342E),
          ['Angol', 'CBT', 'Hindalga', 'Bailhongal']),
      _b(
          'KA22F3003',
          'Munavalli → CBT → Ramdurg',
          'Datta Rao',
          '9134567401',
          'Eshan K',
          '9134567402',
          11,
          '3.5 km',
          'Light',
          0.28,
          const Color(0xFF283593),
          ['Munavalli', 'CBT', 'Ramdurg']),
      _b(
          'KA22F3004',
          'Hukkeri → CBT → Chikkodi',
          'Faisal M',
          '9045678301',
          'Ganesh P',
          '9045678302',
          4,
          '1.2 km',
          'Crowded',
          0.91,
          const Color(0xFF00796B),
          ['Hukkeri', 'CBT', 'Nippani', 'Chikkodi']),
      _b(
          'KA22F3005',
          'Khanapur → CBT → Dandeli',
          'Harish N',
          '9956789201',
          'Irfan S',
          '9956789202',
          16,
          '5.8 km',
          'Light',
          0.19,
          const Color(0xFFC62828),
          ['Khanapur', 'CBT', 'Castle Rock', 'Dandeli']),
      _b(
          'KA22F3006',
          'Soundatti → CBT → Gadag',
          'Jagdish R',
          '9867890101',
          'Karan V',
          '9867890102',
          13,
          '4.9 km',
          'Moderate',
          0.47,
          const Color(0xFF1976D2),
          ['Soundatti', 'CBT', 'Nargund', 'Gadag']),
      _b(
          'KA22F3007',
          'Kittur → CBT → Dharwad',
          'Laxman K',
          '9778901001',
          'Mahesh B',
          '9778901002',
          19,
          '7.2 km',
          'Crowded',
          0.76,
          const Color(0xFF512DA8),
          ['Kittur', 'CBT', 'Dharwad']),
      _b(
          'KA22F3008',
          'Raybag → CBT → Jamkhandi',
          'Naresh P',
          '9689012901',
          'Om Patil',
          '9689012902',
          26,
          '10.8 km',
          'Light',
          0.14,
          const Color(0xFF00897B),
          ['Raybag', 'CBT', 'Mudhol', 'Jamkhandi']),
      _b(
          'KA22F3009',
          'Chikkodi → CBT → Sangli',
          'Praveen S',
          '9590123801',
          'Qasim A',
          '9590123802',
          21,
          '8.7 km',
          'Moderate',
          0.58,
          const Color(0xFFAD1457),
          ['Chikkodi', 'CBT', 'Nippani', 'Sangli']),
      _b(
          'KA22F3010',
          'Nippani → CBT → Hubli',
          'Ravi T',
          '9401234701',
          'Shiva K',
          '9401234702',
          17,
          '6.3 km',
          'Light',
          0.32,
          const Color(0xFF558B2F),
          ['Nippani', 'CBT', 'Dharwad', 'Hubli']),
      _b(
          'KA22F4001',
          'Gokak Town → Athani → Bijapur',
          'Suresh B',
          '9312345701',
          'Tejas P',
          '9312345702',
          45,
          '28.0 km',
          'Light',
          0.2,
          const Color(0xFF1A3A5C),
          ['Gokak Town', 'Athani', 'Bijapur']),
      _b(
          'KA22F4002',
          'Badami → Bagalkot → Bijapur',
          'Uma Patil',
          '9213456601',
          'Vishal D',
          '9213456602',
          55,
          '35.0 km',
          'Moderate',
          0.45,
          const Color(0xFF2E7D32),
          ['Badami', 'Bagalkot', 'Bijapur']),
      _b(
          'KA22F4003',
          'Hubli → Gadag → Haveri',
          'Wasim K',
          '9134567501',
          'Xavier N',
          '9134567502',
          50,
          '31.5 km',
          'Crowded',
          0.82,
          const Color(0xFF6A1B9A),
          ['Hubli', 'Gadag', 'Haveri']),
      _b(
          'KA22F4004',
          'Dharwad → Gadag → Koppal',
          'Yash More',
          '9045678401',
          'Zahid S',
          '9045678402',
          60,
          '38.0 km',
          'Light',
          0.18,
          const Color(0xFF00695C),
          ['Dharwad', 'Gadag', 'Koppal']),
      _b(
          'KA22F4005',
          'Dandeli → Karwar → Ankola',
          'Aakash P',
          '9956789301',
          'Bharat K',
          '9956789302',
          90,
          '58.0 km',
          'Light',
          0.12,
          const Color(0xFFB71C1C),
          ['Dandeli', 'Karwar', 'Ankola']),
      _b(
          'KA22F4006',
          'Jamkhandi → Bijapur → Gulbarga',
          'Chandan R',
          '9867890201',
          'Dinesh V',
          '9867890202',
          75,
          '48.5 km',
          'Moderate',
          0.5,
          const Color(0xFF0277BD),
          ['Jamkhandi', 'Bijapur', 'Gulbarga']),
      _b(
          'KA22F4007',
          'CBT → Belgaum Village → Kanabargi',
          'Eknath K',
          '9778901101',
          'Farhan B',
          '9778901102',
          10,
          '4.2 km',
          'Crowded',
          0.88,
          const Color(0xFF4A148C),
          ['CBT', 'Belgaum Village', 'Kanabargi']),
      _b(
          'KA22F4008',
          'CBT → Udyambag → Shahpur',
          'Ganpat P',
          '9689012001',
          'Harshit N',
          '9689013002',
          8,
          '3.1 km',
          'Light',
          0.25,
          const Color(0xFF006064),
          ['CBT', 'Udyambag', 'Shahpur']),
      _b(
          'KA22F4009',
          'CBT → Shivaji Nagar → Sambra',
          'Indira K',
          '9590123901',
          'Jayesh A',
          '9590123902',
          12,
          '4.7 km',
          'Moderate',
          0.52,
          const Color(0xFF1B5E20),
          ['CBT', 'Shivaji Nagar', 'Sambra']),
      _b(
          'KA22F4010',
          'CBT → Maratha Colony → Kakati',
          'Kamal T',
          '9401234801',
          'Lokesh K',
          '9401234802',
          15,
          '5.9 km',
          'Light',
          0.22,
          const Color(0xFF880E4F),
          ['CBT', 'Maratha Colony', 'Kakati']),
      _b(
          'KA22F5001',
          'CBT → Vadgaon → Shiraguppi',
          'Mohan R',
          '9312345801',
          'Nitin P',
          '9312345802',
          14,
          '5.5 km',
          'Moderate',
          0.48,
          const Color(0xFF1565C0),
          ['CBT', 'Vadgaon', 'Shiraguppi']),
      _b(
          'KA22F5002',
          'CBT → Gokak Falls → Mudalagi',
          'Omkar B',
          '9213456701',
          'Prasad D',
          '9213456702',
          23,
          '9.2 km',
          'Light',
          0.3,
          const Color(0xFF2E7D32),
          ['CBT', 'Gokak Falls', 'Mudalagi']),
      _b(
          'KA22F5003',
          'CBT → Bailhongal → Saundatti → Ron',
          'Qasim K',
          '9134567601',
          'Rajiv N',
          '9134567602',
          28,
          '11.8 km',
          'Crowded',
          0.78,
          const Color(0xFF6A1B9A),
          ['CBT', 'Bailhongal', 'Saundatti', 'Ron']),
      _b(
          'KA22F5004',
          'CBT → Ramdurg → Nargund',
          'Sachin P',
          '9045678501',
          'Tushar S',
          '9045678502',
          32,
          '13.4 km',
          'Light',
          0.2,
          const Color(0xFF00695C),
          ['CBT', 'Ramdurg', 'Nargund']),
      _b(
          'KA22F5005',
          'CBT → Chikkodi → Kagwad',
          'Uday More',
          '9956789401',
          'Vivek K',
          '9956789402',
          18,
          '7.1 km',
          'Moderate',
          0.55,
          const Color(0xFFB71C1C),
          ['CBT', 'Chikkodi', 'Kagwad']),
      _b(
          'KA22F5006',
          'CBT → Hukkeri → Athani',
          'Wasim P',
          '9867890301',
          'Xavier D',
          '9867890302',
          20,
          '8.0 km',
          'Light',
          0.28,
          const Color(0xFF0277BD),
          ['CBT', 'Hukkeri', 'Athani']),
      _b(
          'KA22F5007',
          'CBT → Khanapur → Chorla',
          'Yakub R',
          '9778901201',
          'Zaheer V',
          '9778901202',
          25,
          '10.2 km',
          'Light',
          0.15,
          const Color(0xFF4A148C),
          ['CBT', 'Khanapur', 'Chorla']),
      _b(
          'KA22F5008',
          'CBT → Kanabargi → Macche',
          'Amit K',
          '9689012101',
          'Binod B',
          '9689012102',
          9,
          '3.5 km',
          'Crowded',
          0.87,
          const Color(0xFF006064),
          ['CBT', 'Kanabargi', 'Macche']),
      _b(
          'KA22F5009',
          'CBT → Sambra → Airport',
          'Chirag N',
          '9590124001',
          'Dhruv A',
          '9590124002',
          16,
          '6.2 km',
          'Moderate',
          0.6,
          const Color(0xFF1B5E20),
          ['CBT', 'Sambra', 'Airport']),
      _b(
          'KA22F5010',
          'CBT → Shahpur → Ramtirth',
          'Elan T',
          '9401234901',
          'Feroz K',
          '9401234902',
          11,
          '4.4 km',
          'Light',
          0.18,
          const Color(0xFF880E4F),
          ['CBT', 'Shahpur', 'Ramtirth']),
      _b(
          'KA22F6001',
          'Ramtirth → Shahpur → CBT',
          'Gaurav R',
          '9312345901',
          'Harsh P',
          '9312345902',
          13,
          '4.8 km',
          'Moderate',
          0.5,
          const Color(0xFF1565C0),
          ['Ramtirth', 'Shahpur', 'CBT']),
      _b(
          'KA22F6002',
          'Airport → Sambra → CBT',
          'Ishan B',
          '9213456801',
          'Jatin D',
          '9213456802',
          17,
          '6.5 km',
          'Light',
          0.25,
          const Color(0xFF2E7D32),
          ['Airport', 'Sambra', 'CBT']),
      _b(
          'KA22F6003',
          'Macche → Kanabargi → CBT',
          'Kapil K',
          '9134567701',
          'Lalan N',
          '9134567702',
          10,
          '3.8 km',
          'Crowded',
          0.9,
          const Color(0xFF6A1B9A),
          ['Macche', 'Kanabargi', 'CBT']),
      _b(
          'KA22F6004',
          'Chorla → Khanapur → CBT',
          'Madan P',
          '9045678601',
          'Neel S',
          '9045678602',
          27,
          '10.8 km',
          'Light',
          0.14,
          const Color(0xFF00695C),
          ['Chorla', 'Khanapur', 'CBT']),
      _b(
          'KA22F6005',
          'Athani → Hukkeri → CBT',
          'Om More',
          '9956789501',
          'Pranav K',
          '9956789502',
          22,
          '8.5 km',
          'Light',
          0.28,
          const Color(0xFFB71C1C),
          ['Athani', 'Hukkeri', 'CBT']),
      _b(
          'KA22F6006',
          'Kagwad → Chikkodi → CBT',
          'Qasim R',
          '9867890401',
          'Rakesh V',
          '9867890402',
          19,
          '7.5 km',
          'Moderate',
          0.52,
          const Color(0xFF0277BD),
          ['Kagwad', 'Chikkodi', 'CBT']),
      _b(
          'KA22F6007',
          'Nargund → Ramdurg → CBT',
          'Suresh K',
          '9778901301',
          'Tarun B',
          '9778901302',
          34,
          '14.0 km',
          'Light',
          0.2,
          const Color(0xFF4A148C),
          ['Nargund', 'Ramdurg', 'CBT']),
      _b(
          'KA22F6008',
          'Ron → Saundatti → Bailhongal → CBT',
          'Umesh N',
          '9689012201',
          'Vijay A',
          '9689012202',
          30,
          '12.2 km',
          'Crowded',
          0.8,
          const Color(0xFF006064),
          ['Ron', 'Saundatti', 'Bailhongal', 'CBT']),
      _b(
          'KA22F6009',
          'Mudalagi → Gokak Falls → CBT',
          'Waqar T',
          '9590124101',
          'Xavier K',
          '9590124102',
          24,
          '9.6 km',
          'Light',
          0.3,
          const Color(0xFF1B5E20),
          ['Mudalagi', 'Gokak Falls', 'CBT']),
      _b(
          'KA22F6010',
          'Shiraguppi → Vadgaon → CBT',
          'Yash P',
          '9401235001',
          'Zahid R',
          '9401235002',
          15,
          '5.8 km',
          'Moderate',
          0.48,
          const Color(0xFF880E4F),
          ['Shiraguppi', 'Vadgaon', 'CBT']),
      _b(
          'KA22F7001',
          'CBT → Udyambag → Goaves',
          'Anil B',
          '9312346001',
          'Babu D',
          '9312346002',
          7,
          '2.8 km',
          'Moderate',
          0.55,
          const Color(0xFF1565C0),
          ['CBT', 'Udyambag', 'Goaves']),
      _b(
          'KA22F7002',
          'CBT → Shivaji Nagar → Hanuman Nagar',
          'Chetan K',
          '9213456901',
          'Dinesh N',
          '9213456902',
          6,
          '2.3 km',
          'Crowded',
          0.85,
          const Color(0xFF2E7D32),
          ['CBT', 'Shivaji Nagar', 'Hanuman Nagar']),
      _b(
          'KA22F7003',
          'CBT → Maratha Colony → Gandhinagar',
          'Elan P',
          '9134567801',
          'Farhan S',
          '9134567802',
          8,
          '3.0 km',
          'Light',
          0.22,
          const Color(0xFF6A1B9A),
          ['CBT', 'Maratha Colony', 'Gandhinagar']),
      _b(
          'KA22F7004',
          'CBT → Camp Area → Cantonment',
          'Girish T',
          '9045678701',
          'Hari K',
          '9045678702',
          5,
          '1.9 km',
          'Moderate',
          0.5,
          const Color(0xFF00695C),
          ['CBT', 'Camp Area', 'Cantonment']),
      _b(
          'KA22F7005',
          'CBT → Fort Area → Shahapur',
          'Ishan More',
          '9956789601',
          'Jagdish P',
          '9956789602',
          4,
          '1.5 km',
          'Crowded',
          0.92,
          const Color(0xFFB71C1C),
          ['CBT', 'Fort Area', 'Shahapur']),
      _b(
          'KA22F7006',
          'CBT → Nehru Nagar → Lingaraj Nagar',
          'Kiran R',
          '9867890501',
          'Laxman V',
          '9867890502',
          10,
          '3.8 km',
          'Light',
          0.18,
          const Color(0xFF0277BD),
          ['CBT', 'Nehru Nagar', 'Lingaraj Nagar']),
      _b(
          'KA22F7007',
          'CBT → Subhash Nagar → Kapil Nagar',
          'Mohan K',
          '9778901401',
          'Nitin B',
          '9778901402',
          12,
          '4.5 km',
          'Moderate',
          0.48,
          const Color(0xFF4A148C),
          ['CBT', 'Subhash Nagar', 'Kapil Nagar']),
      _b(
          'KA22F7008',
          'CBT → Raviwar Peth → Tilakwadi',
          'Omkar N',
          '9689012301',
          'Prasad A',
          '9689012302',
          9,
          '3.4 km',
          'Crowded',
          0.78,
          const Color(0xFF006064),
          ['CBT', 'Raviwar Peth', 'Tilakwadi']),
      _b(
          'KA22F7009',
          'CBT → Angol → Naganur',
          'Qasim P',
          '9590124201',
          'Rajesh T',
          '9590124202',
          11,
          '4.2 km',
          'Light',
          0.25,
          const Color(0xFF1B5E20),
          ['CBT', 'Angol', 'Naganur']),
      _b(
          'KA22F7010',
          'CBT → Hindalga → Kerwad',
          'Sachin K',
          '9401235101',
          'Tarun R',
          '9401235102',
          14,
          '5.3 km',
          'Moderate',
          0.52,
          const Color(0xFF880E4F),
          ['CBT', 'Hindalga', 'Kerwad']),
      _b(
          'KA22F8001',
          'Goaves → Udyambag → CBT',
          'Uday B',
          '9312346101',
          'Vinod D',
          '9312346102',
          8,
          '3.1 km',
          'Moderate',
          0.5,
          const Color(0xFF1565C0),
          ['Goaves', 'Udyambag', 'CBT']),
      _b(
          'KA22F8002',
          'Hanuman Nagar → Shivaji Nagar → CBT',
          'Wasim K',
          '9213457001',
          'Xavier N',
          '9213457002',
          7,
          '2.6 km',
          'Crowded',
          0.88,
          const Color(0xFF2E7D32),
          ['Hanuman Nagar', 'Shivaji Nagar', 'CBT']),
      _b(
          'KA22F8003',
          'Gandhinagar → Maratha Colony → CBT',
          'Yakub P',
          '9134567901',
          'Zaheer S',
          '9134567902',
          9,
          '3.3 km',
          'Light',
          0.2,
          const Color(0xFF6A1B9A),
          ['Gandhinagar', 'Maratha Colony', 'CBT']),
      _b(
          'KA22F8004',
          'Cantonment → Camp Area → CBT',
          'Amit T',
          '9045678801',
          'Binod K',
          '9045678802',
          6,
          '2.2 km',
          'Moderate',
          0.48,
          const Color(0xFF00695C),
          ['Cantonment', 'Camp Area', 'CBT']),
      _b(
          'KA22F8005',
          'Shahapur → Fort Area → CBT',
          'Chirag More',
          '9956789701',
          'Dhruv P',
          '9956789702',
          5,
          '1.8 km',
          'Crowded',
          0.9,
          const Color(0xFFB71C1C),
          ['Shahapur', 'Fort Area', 'CBT']),
      _b(
          'KA22F8006',
          'Lingaraj Nagar → Nehru Nagar → CBT',
          'Elan R',
          '9867890601',
          'Feroz V',
          '9867890602',
          11,
          '4.1 km',
          'Light',
          0.15,
          const Color(0xFF0277BD),
          ['Lingaraj Nagar', 'Nehru Nagar', 'CBT']),
      _b(
          'KA22F8007',
          'Kapil Nagar → Subhash Nagar → CBT',
          'Gaurav K',
          '9778901501',
          'Harsh B',
          '9778901502',
          13,
          '4.8 km',
          'Moderate',
          0.55,
          const Color(0xFF4A148C),
          ['Kapil Nagar', 'Subhash Nagar', 'CBT']),
      _b(
          'KA22F8008',
          'Tilakwadi → Raviwar Peth → CBT',
          'Ishan N',
          '9689012401',
          'Jatin A',
          '9689012402',
          10,
          '3.7 km',
          'Crowded',
          0.82,
          const Color(0xFF006064),
          ['Tilakwadi', 'Raviwar Peth', 'CBT']),
      _b(
          'KA22F8009',
          'Naganur → Angol → CBT',
          'Kapil P',
          '9590124301',
          'Lalan T',
          '9590124302',
          12,
          '4.5 km',
          'Light',
          0.22,
          const Color(0xFF1B5E20),
          ['Naganur', 'Angol', 'CBT']),
      _b(
          'KA22F8010',
          'Kerwad → Hindalga → CBT',
          'Madan K',
          '9401235201',
          'Neel R',
          '9401235202',
          15,
          '5.6 km',
          'Moderate',
          0.5,
          const Color(0xFF880E4F),
          ['Kerwad', 'Hindalga', 'CBT']),
      _b(
          'KA22F9001',
          'CBT → Belgaum Village → Desur',
          'Om B',
          '9312346201',
          'Pranav D',
          '9312346202',
          16,
          '6.1 km',
          'Light',
          0.28,
          const Color(0xFF1565C0),
          ['CBT', 'Belgaum Village', 'Desur']),
      _b(
          'KA22F9002',
          'CBT → Macche → Kakati → Hattargi',
          'Qasim K',
          '9213457101',
          'Rakesh N',
          '9213457102',
          20,
          '7.8 km',
          'Moderate',
          0.52,
          const Color(0xFF2E7D32),
          ['CBT', 'Macche', 'Kakati', 'Hattargi']),
      _b(
          'KA22F9003',
          'CBT → Shivapur → Ugar',
          'Suresh P',
          '9134568001',
          'Tarun S',
          '9134568002',
          28,
          '11.0 km',
          'Light',
          0.18,
          const Color(0xFF6A1B9A),
          ['CBT', 'Shivapur', 'Ugar']),
      _b(
          'KA22F9004',
          'CBT → Harugeri → Yamakanamardi',
          'Umesh T',
          '9045678901',
          'Vijay K',
          '9045678902',
          24,
          '9.5 km',
          'Light',
          0.2,
          const Color(0xFF00695C),
          ['CBT', 'Harugeri', 'Yamakanamardi']),
      _b(
          'KA22F9005',
          'CBT → Ghataprabha → Hidkal',
          'Waqar More',
          '9956789801',
          'Xavier P',
          '9956789802',
          35,
          '14.5 km',
          'Moderate',
          0.45,
          const Color(0xFFB71C1C),
          ['CBT', 'Ghataprabha', 'Hidkal']),
      _b(
          'KA22F9006',
          'CBT → Nandagad → Parasgad',
          'Yash R',
          '9867890701',
          'Zahid V',
          '9867890702',
          40,
          '16.8 km',
          'Light',
          0.15,
          const Color(0xFF0277BD),
          ['CBT', 'Nandagad', 'Parasgad']),
      _b(
          'KA22F9007',
          'CBT → Ankali → Benakanhalli',
          'Anil K',
          '9778901601',
          'Babu B',
          '9778901602',
          18,
          '7.0 km',
          'Crowded',
          0.75,
          const Color(0xFF4A148C),
          ['CBT', 'Ankali', 'Benakanhalli']),
      _b(
          'KA22F9008',
          'CBT → Savadatti → Mugad',
          'Chetan N',
          '9689012501',
          'Dinesh A',
          '9689012502',
          22,
          '8.8 km',
          'Moderate',
          0.58,
          const Color(0xFF006064),
          ['CBT', 'Savadatti', 'Mugad']),
      _b(
          'KA22F9009',
          'CBT → Sampgaon → Yargatti',
          'Elan K',
          '9590124401',
          'Farhan R',
          '9590124402',
          30,
          '12.5 km',
          'Light',
          0.22,
          const Color(0xFF1B5E20),
          ['CBT', 'Sampgaon', 'Yargatti']),
      _b(
          'KA22F9010',
          'CBT → Kalghatgi → Dharwad',
          'Girish P',
          '9401235301',
          'Hari T',
          '9401235302',
          45,
          '19.0 km',
          'Crowded',
          0.8,
          const Color(0xFF880E4F),
          ['CBT', 'Kalghatgi', 'Dharwad']),
      _b(
          'KA22FA001',
          'Desur → Belgaum Village → CBT',
          'Ishan B',
          '9312346301',
          'Jagdish D',
          '9312346302',
          17,
          '6.4 km',
          'Light',
          0.27,
          const Color(0xFF1565C0),
          ['Desur', 'Belgaum Village', 'CBT']),
      _b(
          'KA22FA002',
          'Hattargi → Kakati → Macche → CBT',
          'Kiran K',
          '9213457201',
          'Laxman N',
          '9213457202',
          21,
          '8.2 km',
          'Moderate',
          0.5,
          const Color(0xFF2E7D32),
          ['Hattargi', 'Kakati', 'Macche', 'CBT']),
      _b(
          'KA22FA003',
          'Ugar → Shivapur → CBT',
          'Mohan P',
          '9134568101',
          'Nitin S',
          '9134568102',
          29,
          '11.5 km',
          'Light',
          0.17,
          const Color(0xFF6A1B9A),
          ['Ugar', 'Shivapur', 'CBT']),
      _b(
          'KA22FA004',
          'Yamakanamardi → Harugeri → CBT',
          'Omkar T',
          '9045679001',
          'Prasad K',
          '9045679002',
          26,
          '10.0 km',
          'Light',
          0.19,
          const Color(0xFF00695C),
          ['Yamakanamardi', 'Harugeri', 'CBT']),
      _b(
          'KA22FA005',
          'Hidkal → Ghataprabha → CBT',
          'Qasim More',
          '9956789901',
          'Rajesh P',
          '9956789902',
          37,
          '15.2 km',
          'Moderate',
          0.44,
          const Color(0xFFB71C1C),
          ['Hidkal', 'Ghataprabha', 'CBT']),
      _b(
          'KA22FA006',
          'Parasgad → Nandagad → CBT',
          'Sachin R',
          '9867890801',
          'Tarun V',
          '9867890802',
          42,
          '17.5 km',
          'Light',
          0.14,
          const Color(0xFF0277BD),
          ['Parasgad', 'Nandagad', 'CBT']),
      _b(
          'KA22FA007',
          'Benakanhalli → Ankali → CBT',
          'Uday K',
          '9778901701',
          'Vinod B',
          '9778901702',
          20,
          '7.5 km',
          'Crowded',
          0.72,
          const Color(0xFF4A148C),
          ['Benakanhalli', 'Ankali', 'CBT']),
      _b(
          'KA22FA008',
          'Mugad → Savadatti → CBT',
          'Wasim N',
          '9689012601',
          'Xavier A',
          '9689012602',
          23,
          '9.2 km',
          'Moderate',
          0.55,
          const Color(0xFF006064),
          ['Mugad', 'Savadatti', 'CBT']),
      _b(
          'KA22FA009',
          'Yargatti → Sampgaon → CBT',
          'Yakub K',
          '9590124501',
          'Zaheer R',
          '9590124502',
          32,
          '13.2 km',
          'Light',
          0.21,
          const Color(0xFF1B5E20),
          ['Yargatti', 'Sampgaon', 'CBT']),
      _b(
          'KA22FA010',
          'Dharwad → Kalghatgi → CBT',
          'Amit P',
          '9401235401',
          'Binod T',
          '9401235402',
          47,
          '20.0 km',
          'Crowded',
          0.79,
          const Color(0xFF880E4F),
          ['Dharwad', 'Kalghatgi', 'CBT']),
    ];

BusData _b(
    String no,
    String route,
    String drName,
    String drPhone,
    String coName,
    String coPhone,
    int eta,
    String dist,
    String crowd,
    double level,
    Color color,
    List<String> stopNames) {
  final stops = stopNames.asMap().entries.map((e) {
    final i = e.key;
    final n = e.value;
    String status;
    if (i == 0)
      status = 'passed';
    else if (i == 1)
      status = 'current';
    else
      status = 'upcoming';
    final hour = 7 + i;
    final min = (i * 17) % 60;
    final ampm = hour < 12 ? 'AM' : 'PM';
    final h = hour > 12 ? hour - 12 : hour;
    return BusStop(
      name: n,
      time:
          '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')} $ampm',
      status: status,
    );
  }).toList();
  return BusData(
    busNo: no,
    route: route,
    driverName: drName,
    driverPhone: drPhone,
    conductorName: coName,
    conductorPhone: coPhone,
    eta: eta,
    distance: dist,
    crowd: crowd,
    crowdLevel: level,
    color: color,
    stops: stops,
  );
}

List<BusData> searchBuses(String from, String to) {
  if (from.isEmpty || to.isEmpty) return [];
  return allBuses.where((bus) {
    final names = bus.stops.map((s) => s.name.toLowerCase()).toList();
    final fi = names.indexWhere((n) => n.contains(from.toLowerCase()));
    final ti = names.indexWhere((n) => n.contains(to.toLowerCase()));
    return fi != -1 && ti != -1 && fi < ti;
  }).toList();
}

List<String> get allStops {
  final s = <String>{};
  for (final b in allBuses) {
    for (final st in b.stops) {
      s.add(st.name);
    }
  }
  final l = s.toList()..sort();
  return l;
}

List<BusData> busesForPlace(String searchKey) {
  final key = searchKey.toLowerCase();
  return allBuses.where((b) {
    if (b.route.toLowerCase().contains(key)) return true;
    return b.stops.any((s) => s.name.toLowerCase().contains(key));
  }).toList()
    ..sort((a, b) => a.eta.compareTo(b.eta));
}

String formatCbtRoute(BusData bus) {
  if (bus.stops.isEmpty) return bus.route;
  final first = bus.stops.first.name;
  final last = bus.stops.last.name;
  if (first == 'CBT') return 'CBT → $last';
  if (last == 'CBT') return '$first → CBT';
  return '$first → $last';
}

// ─── AUTH (Local Storage) ───────────────────────────────────────────────

class AuthUser {
  final String name;
  final String mobile;
  final String email;
  final String password;
  final String? photoPath;

  const AuthUser({
    required this.name,
    required this.mobile,
    required this.email,
    required this.password,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobile': mobile,
        'email': email,
        'password': password,
        'photoPath': photoPath,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        name: json['name'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        email: json['email'] as String? ?? '',
        password: json['password'] as String? ?? '',
        photoPath: json['photoPath'] as String?,
      );
}

class AuthService {
  static const _usersKey = 'trackbus_users_v1';
  static const _sessionKey = 'trackbus_session_email_v1';

  static List<AuthUser> _users = [];
  static AuthUser? currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final rawUsers = prefs.getString(_usersKey);
    if (rawUsers != null && rawUsers.isNotEmpty) {
      final decoded = jsonDecode(rawUsers) as List<dynamic>;
      _users = decoded
          .map((e) => AuthUser.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final sessionEmail = prefs.getString(_sessionKey);
    if (sessionEmail != null) {
      for (final u in _users) {
        if (u.email.toLowerCase() == sessionEmail.toLowerCase()) {
          currentUser = u;
          break;
        }
      }
    }

    // ── NEW: Also restore Supabase session ── ADD THESE LINES
    final supabaseSession = supabase.auth.currentSession;
    if (supabaseSession != null) {
      print('✅ Supabase session restored: ${supabaseSession.user.email}');
    } else if (currentUser != null) {
      // Try to sign in again silently
      try {
        await supabase.auth.signInWithPassword(
          email: currentUser!.email,
          password: currentUser!.password,
        );
        print('✅ Supabase auto-login success!');
      } catch (e) {
        print('⚠️ Supabase auto-login: $e');
      }
    }
  }

  static Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _usersKey,
      jsonEncode(_users.map((u) => u.toJson()).toList()),
    );
  }

  static bool _isValidEmail(String email) {
    return RegExp(r'^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(email.trim());
  }

  static bool _isValidMobile(String mobile) {
    return RegExp(r'^\d{10}$').hasMatch(mobile.trim());
  }

  static Future<String?> register(AuthUser user) async {
    if (_users.any((u) => u.email.toLowerCase() == user.email.toLowerCase())) {
      return 'An account with this email already exists';
    }
    _users.add(user);
    await _saveUsers();

    // ── Save to Supabase ──
    try {
      final response = await supabase.auth.signUp(
        email: user.email,
        password: user.password,
      );
      if (response.user != null) {
        await supabase.from('users').insert({
          'id': response.user!.id,
          'name': user.name,
          'email': user.email,
          'mobile': user.mobile,
          'location': 'Belagavi, Karnataka',
        });
        print('✅ User saved to Supabase!');
      }
    } catch (e) {
      print('⚠️ Supabase register error: $e');
      // Don't return error — local registration still worked
    }

    return null;
  }

  static Future<String?> login(String email, String password) async {
    final match = _users.where(
      (u) =>
          u.email.toLowerCase() == email.trim().toLowerCase() &&
          u.password == password,
    );
    if (match.isEmpty) return 'Invalid email or password';

    currentUser = match.first;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, currentUser!.email);

    // ── Also login to Supabase ──
    try {
      await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      print('✅ Supabase login success!');
    } catch (e) {
      print('⚠️ Supabase login error: $e');
      // Don't return error — local login still worked
    }

    return null;
  }

  static Future<String?> updateProfile({
    required String name,
    required String mobile,
    required String? photoPath,
  }) async {
    final existing = currentUser;
    if (existing == null) return 'Please login again';

    if (name.trim().isEmpty) return 'Name is required';
    if (!_isValidMobile(mobile)) return 'Enter a valid 10-digit mobile number';

    final idx = _users.indexWhere(
        (u) => u.email.toLowerCase() == existing.email.toLowerCase());
    if (idx == -1) return 'User not found';

    final updated = AuthUser(
      name: name.trim(),
      mobile: mobile.trim(),
      email: existing.email,
      password: existing.password,
      photoPath: photoPath,
    );

    _users[idx] = updated;
    currentUser = updated;
    await _saveUsers();

    // Sync profile update to Supabase
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('users').upsert({
          'id': userId,
          'name': name.trim(),
          'mobile': mobile.trim(),
          'email': existing.email,
        });
        print('✅ Profile synced to Supabase!');
      }
    } catch (e) {
      print('⚠️ Supabase profile sync error: \$e');
    }

    return null;
  }

  static Future<void> logout() async {
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);

    // ── Also logout from Supabase ──
    try {
      await supabase.auth.signOut();
      print('✅ Supabase logout success!');
    } catch (e) {
      print('⚠️ Supabase logout error: $e');
    }
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final int? maxLength;
  final Widget? suffixIcon;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A3A5C))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF1A3A5C), size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFF1A3A5C), width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A3A5C)),
    );
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (name.isEmpty || mobile.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Please fill all fields');
      return;
    }
    if (!AuthService._isValidMobile(mobile)) {
      _snack('Enter a valid 10-digit mobile number');
      return;
    }
    if (!AuthService._isValidEmail(email)) {
      _snack('Enter a valid email address');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true);
    final err = await AuthService.register(
        AuthUser(name: name, mobile: mobile, email: email, password: password));
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      _snack(err);
      return;
    }

    _snack('Registered successfully. Please login.');
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('Create your TrackBus account',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              _AuthField(
                  controller: _nameCtrl,
                  label: 'Name',
                  hint: 'Your name',
                  icon: Icons.person_outline),
              const SizedBox(height: 16),
              _AuthField(
                controller: _mobileCtrl,
                label: 'Mobile Number',
                hint: '10-digit number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 16),
              _AuthField(
                controller: _emailCtrl,
                label: 'Email ID',
                hint: 'you@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _AuthField(
                controller: _passCtrl,
                label: 'Password',
                hint: 'Min. 6 characters',
                icon: Icons.lock_outline,
                obscureText: _hidePassword,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                      _hidePassword ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Register',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Login',
                        style: TextStyle(
                            color: Color(0xFFF4A024),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A3A5C)),
    );
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _snack('Enter email and password');
      return;
    }
    if (!AuthService._isValidEmail(email)) {
      _snack('Enter a valid email address');
      return;
    }

    setState(() => _loading = true);
    final err = await AuthService.login(email, password);
    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      _snack(err);
      return;
    }

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Text('Login to continue to TrackBus dashboard',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              _AuthField(
                controller: _emailCtrl,
                label: 'Email ID',
                hint: 'you@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _AuthField(
                controller: _passCtrl,
                label: 'Password',
                hint: 'Enter password',
                icon: Icons.lock_outline,
                obscureText: _hidePassword,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                      _hidePassword ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Login',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New here? ',
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen())),
                    child: const Text('Register',
                        style: TextStyle(
                            color: Color(0xFFF4A024),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  String? _photoPath;
  bool _saving = false;

  // Email OTP flow
  String _emailStep = 'view'; // view | otp_old | new_email | otp_new
  final _oldOtpCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  final _newOtpCtrl = TextEditingController();
  static const _demoOtp = '123456';

  void _sendOldOtp() {
    setState(() => _emailStep = 'otp_old');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'OTP sent to ${AuthService.currentUser?.email ?? ""}  (Demo: 123456)'),
      backgroundColor: const Color(0xFF1A3A5C),
    ));
  }

  void _verifyOldOtp() {
    if (_oldOtpCtrl.text.trim() == _demoOtp) {
      setState(() => _emailStep = 'new_email');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Wrong OTP. Try 123456'), backgroundColor: Colors.red));
    }
  }

  void _sendNewOtp() {
    if (_newEmailCtrl.text.isEmpty || !_newEmailCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid email'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _emailStep = 'otp_new');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('OTP sent to ${_newEmailCtrl.text}  (Demo: 123456)'),
      backgroundColor: const Color(0xFF1A3A5C),
    ));
  }

  void _verifyNewOtp() {
    if (_newOtpCtrl.text.trim() == _demoOtp) {
      // In real app: update email in backend
      setState(() {
        _emailStep = 'view';
        _oldOtpCtrl.clear();
        _newEmailCtrl.clear();
        _newOtpCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Email updated successfully!'),
          backgroundColor: Color(0xFF2E7D32)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Wrong OTP. Try 123456'), backgroundColor: Colors.red));
    }
  }

  @override
  void initState() {
    super.initState();
    final u = AuthService.currentUser;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _mobileCtrl = TextEditingController(text: u?.mobile ?? '');
    _photoPath = u?.photoPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _oldOtpCtrl.dispose();
    _newEmailCtrl.dispose();
    _newOtpCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A3A5C)),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _photoPath = file.path);
  }

  Future<void> _deletePhoto() async {
    final path = _photoPath;
    if (path != null && !kIsWeb) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
        // Ignore delete failure; still clear UI and persisted value.
      }
    }
    setState(() => _photoPath = null);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final err = await AuthService.updateProfile(
        name: name, mobile: mobile, photoPath: _photoPath);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      _snack(err);
      return;
    }
    _snack('Profile updated!');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        _photoPath != null && !kIsWeb && File(_photoPath!).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3A5C),
        foregroundColor: Colors.white,
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: hasPhoto
                              ? ClipOval(
                                  child: Image.file(File(_photoPath!),
                                      fit: BoxFit.cover))
                              : const Icon(Icons.person,
                                  size: 52, color: Color(0xFF1A3A5C)),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFF4A024),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload Photo'),
                        ),
                        if (hasPhoto)
                          OutlinedButton.icon(
                            onPressed: _deletePhoto,
                            icon: const Icon(Icons.delete_outline,
                                color: Color(0xFFC62828)),
                            label: const Text('Delete',
                                style: TextStyle(color: Color(0xFFC62828))),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _AuthField(
                controller: _nameCtrl,
                label: 'Name',
                hint: 'Your name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _AuthField(
                controller: _mobileCtrl,
                label: 'Mobile Number',
                hint: '10-digit number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A5C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(height: 20),
              // ── Email Change Section ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 10)
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Change Email Address',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 4),
                      Text('Current: ${AuthService.currentUser?.email ?? ""}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 14),
                      if (_emailStep == 'view') ...[
                        const Text(
                            'To change your email, we will verify your current email first.',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _sendOldOtp,
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Send OTP to current email'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0277BD),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                            )),
                      ],
                      if (_emailStep == 'otp_old') ...[
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(
                                'OTP sent to your email\n(Demo OTP: 123456)',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF0277BD)))),
                        const SizedBox(height: 12),
                        _AuthField(
                            controller: _oldOtpCtrl,
                            label: 'Enter OTP from current email',
                            hint: '123456',
                            icon: Icons.lock_outline,
                            keyboardType: TextInputType.number,
                            maxLength: 6),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _verifyOldOtp,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: const Text('Verify OTP',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            )),
                      ],
                      if (_emailStep == 'new_email') ...[
                        const Text(
                            'OTP verified! Enter your new email address.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _AuthField(
                            controller: _newEmailCtrl,
                            label: 'New Email Address',
                            hint: 'newemail@example.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _sendNewOtp,
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Send OTP to new email'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0277BD),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                            )),
                      ],
                      if (_emailStep == 'otp_new') ...[
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(
                                'OTP sent to ${_newEmailCtrl.text}\n(Demo OTP: 123456)',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF2E7D32)))),
                        _AuthField(
                            controller: _newOtpCtrl,
                            label: 'Enter OTP from new email',
                            hint: '123456',
                            icon: Icons.lock_outline,
                            keyboardType: TextInputType.number,
                            maxLength: 6),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _verifyNewOtp,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: const Text('Confirm Email Change',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            )),
                      ],
                    ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SPLASH ──────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      _goNext();
    });
  }

  void _goNext() {
    if (!mounted) return;
    final next =
        AuthService.isLoggedIn ? const MainShell() : PhoneEntryScreen();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2137),
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4A024),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFF4A024).withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4)
                  ],
                ),
                child: const Icon(Icons.directions_bus,
                    color: Colors.white, size: 52),
              ),
              const SizedBox(height: 24),
              const TrackBusLogoText(fontSize: 34),
              const SizedBox(height: 6),
              Text(AppLang.t('splash_subtitle'),
                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 40),
              const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      color: Color(0xFFF4A024), strokeWidth: 2.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── LANGUAGE SELECT (first launch) ──────────────────────────────────────────

class LanguageSelectScreen extends StatefulWidget {
  final bool fromSettings;
  const LanguageSelectScreen({super.key, this.fromSettings = false});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  late String? _selected;

  final _options = const [
    {'code': 'en', 'key': 'lang_en'},
    {'code': 'kn', 'key': 'lang_kn'},
    {'code': 'mr', 'key': 'lang_mr'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = AppLang.currentCode;
  }

  Future<void> _continue() async {
    if (_selected == null) return;
    await AppLang.instance.setLocale(_selected!);
    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.pop(context);
      return;
    }
    final next =
        AuthService.isLoggedIn ? const MainShell() : PhoneEntryScreen();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const TrackBusLogoText(
                fontSize: 28,
                trackColor: Color(0xFF1A3A5C),
                busColor: Color(0xFFF4A024),
              ),
              const SizedBox(height: 8),
              Text(AppLang.t('splash_subtitle'),
                  style:
                      const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
              const SizedBox(height: 32),
              Text(AppLang.t('choose_language'),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D1F35))),
              const SizedBox(height: 20),
              ..._options.map((opt) {
                final code = opt['code']!;
                final sel = _selected == code;
                return GestureDetector(
                  onTap: () => setState(() => _selected = code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFFFF8E6) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFFF4A024)
                            : Colors.grey.shade200,
                        width: sel ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppLang.t(opt['key']!),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                              color: const Color(0xFF0D1F35),
                            ),
                          ),
                        ),
                        Icon(
                          sel
                              ? Icons.radio_button_checked
                              : Icons.circle_outlined,
                          color: sel
                              ? const Color(0xFFF4A024)
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selected != null ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4A024),
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(AppLang.t('select_language'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MAIN SHELL ──────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  Widget _cbtLabel(bool selected) {
    return Text(
      AppLang.t('cbt'),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: selected ? const Color(0xFFF4A024) : Colors.white54,
        letterSpacing: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3 tabs: Home (0), CBT (1), Profile (2)
    final screens = [
      HomeScreen(onTabChange: _goToTab),
      const CBTScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A3A5C),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                // Home
                Expanded(
                  child: GestureDetector(
                    onTap: () => _goToTab(0),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home,
                            size: 24,
                            color: _index == 0
                                ? const Color(0xFFF4A024)
                                : Colors.white54),
                        const SizedBox(height: 3),
                        Text(AppLang.t('home'),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _index == 0
                                    ? const Color(0xFFF4A024)
                                    : Colors.white54)),
                        if (_index == 0)
                          Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF4A024),
                                  borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                ),
                // CBT (bus terminal search)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _goToTab(1),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _cbtLabel(_index == 1),
                        if (_index == 1)
                          Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF4A024),
                                  borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                ),
                // Profile
                Expanded(
                  child: GestureDetector(
                    onTap: () => _goToTab(2),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person,
                            size: 24,
                            color: _index == 2
                                ? const Color(0xFFF4A024)
                                : Colors.white54),
                        const SizedBox(height: 3),
                        Text(AppLang.t('profile'),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _index == 2
                                    ? const Color(0xFFF4A024)
                                    : Colors.white54)),
                        if (_index == 2)
                          Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 20,
                              height: 3,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF4A024),
                                  borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late List<BusData> _arriving;
  late Timer _timer;
  String? _destination;

  static const _homePurple = Color(0xFF7B61FF);
  static const _homeBg = Color(0xFFF8F9FE);

  @override
  void initState() {
    super.initState();
    _arriving = List.from(allBuses)..sort((a, b) => a.eta.compareTo(b.eta));
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _userName() {
    final name = AuthService.currentUser?.name.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;
    return 'Udiksha';
  }

  void _pickDestination() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select destination',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allStops.length,
                itemBuilder: (_, i) {
                  final stop = allStops[i];
                  return ListTile(
                    leading: const Icon(Icons.location_on,
                        color: Color(0xFFE53935), size: 20),
                    title: Text(stop),
                    onTap: () {
                      setState(() => _destination = stop);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchBuses() async {
    // Try reading a saved user location name from prefs; fallback to CBT
    String from = 'CBT';
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('trackbus_current_location_name') ??
          prefs.getString('trackbus_last_location_name');
      if (saved != null && saved.isNotEmpty) from = saved;
    } catch (_) {}

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SearchScreen(
                autoFocus: true,
                initialFrom: from,
                initialTo: _destination,
              )),
    );
  }

  void _openSavedRoutes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen(autoFocus: false)),
    );
  }

  String _busLabel(int index, BusData bus) {
    final digits = bus.busNo.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 3) return 'Bus ${digits.substring(digits.length - 3)}';
    return 'Bus ${101 + index}';
  }

  String _busDestination(BusData bus) {
    final current = bus.stops
        .where((s) => s.status == 'current')
        .map((s) => s.name)
        .firstOrNull;
    return current ?? bus.stops.last.name;
  }

  Color _etaColor(int eta) =>
      eta <= 5 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);

  void _openPlace(PopularPlace place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceBusesScreen(place: place),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nearbyBuses = _arriving.take(4).toList();
    final savedHistory = UserSession.travelHistory;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── TOP: MAP fills top half ──
          Expanded(
            flex: 5,
            child: Stack(children: [
              // Map background
              SizedBox.expand(
                child: CustomPaint(
                  painter: _RapidoMapPainter(),
                ),
              ),
              // Pickup Point label + pin — center of map
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3A5C),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Text(AppLang.t('your_location'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                        width: 2, height: 16, color: const Color(0xFF1A3A5C)),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Top safe area row with TrackBus logo + notification
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(children: [
                    // Logo pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8)
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                              color: const Color(0xFFF4A024),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.directions_bus,
                              color: Colors.white, size: 14),
                        ),
                        const SizedBox(width: 6),
                        const TrackBusLogoText(
                            fontSize: 14,
                            trackColor: Color(0xFF1A3A5C),
                            busColor: Color(0xFFF4A024)),
                      ]),
                    ),
                    const Spacer(),
                    // Notification bell
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8)
                        ],
                      ),
                      child: Stack(children: [
                        const Center(
                          child: Icon(Icons.notifications_outlined,
                              size: 22, color: Color(0xFF1A3A5C)),
                        ),
                        Positioned(
                          right: 7,
                          top: 7,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          // ── BOTTOM SHEET PANEL (white) ──
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current location pill strip (like Rapido's plus code address)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppLang.t('cbt_belagavi'),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── WHERE DO YOU WANT TO GO? (Rapido-style) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const SearchScreen(autoFocus: true)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: Colors.grey.shade200, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: Row(children: [
                            Icon(Icons.search,
                                color: Colors.grey.shade500, size: 22),
                            const SizedBox(width: 10),
                            Text(AppLang.t('where_go'),
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Recent stop (like Rapido's "Majestic Avenue" row)
                    if (UserSession.travelHistory.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: _searchBuses,
                          child: Row(children: [
                            const Icon(Icons.history,
                                color: Colors.grey, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        UserSession.travelHistory.first['to']
                                                as String? ??
                                            'CBT',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1A1A2E))),
                                    Text(
                                        UserSession.travelHistory.first['route']
                                                as String? ??
                                            '',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9CA3AF)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ]),
                            ),
                            Icon(Icons.favorite_border,
                                color: Colors.grey.shade400, size: 20),
                          ]),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: _searchBuses,
                          child: Row(children: [
                            const Icon(Icons.history,
                                color: Colors.grey, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppLang.t('cbt_bus_stand'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1A1A2E))),
                                    Text(AppLang.t('cbt_subtitle'),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF9CA3AF))),
                                  ]),
                            ),
                            Icon(Icons.favorite_border,
                                color: Colors.grey.shade400, size: 20),
                          ]),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Divider(color: Colors.grey.shade200, height: 1),
                    ),

                    // ── Buses arriving soon banner ──
                    if (nearbyBuses.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    const Color(0xFFF4A024).withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF4A024),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.directions_bus,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                    nearbyBuses.first.stops.isNotEmpty
                                        ? '${nearbyBuses.first.stops.first.name} → ${nearbyBuses.first.stops.last.name} — ${nearbyBuses.first.eta} min'
                                        : '${nearbyBuses.first.route} — ${nearbyBuses.first.eta} min',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A2E)),
                                  ),
                                  Text(nearbyBuses.first.route,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9CA3AF)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ])),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => BusDetailScreen(
                                          bus: nearbyBuses.first))),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF4A024),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(AppLang.t('track'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ]),
                        ),
                      ),

                    const SizedBox(height: 14),

                    // ── Saved Routes ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(AppLang.t('saved_routes'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A2E))),
                          const Spacer(),
                          if (savedHistory.isNotEmpty)
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SavedRoutesScreen()),
                              ),
                              child: Text(AppLang.t('view_all'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF7B61FF))),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (savedHistory.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(AppLang.t('save_routes_hint'),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF))),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 88,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: const [
                            _SavedRouteChip(
                              from: 'CBT',
                              to: 'Chikkodi',
                              via: 'Via Hukkeri',
                              icon: Icons.directions_bus,
                              color: Color(0xFF7B61FF),
                            ),
                            _SavedRouteChip(
                              from: 'CBT',
                              to: 'Gokak Falls',
                              via: 'Via Gokak Town',
                              icon: Icons.water,
                              color: Color(0xFF22C55E),
                            ),
                            _SavedRouteChip(
                              from: 'CBT',
                              to: 'Dandeli',
                              via: 'Via Khanapur',
                              icon: Icons.forest,
                              color: Color(0xFF3B82F6),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      SizedBox(
                        height: 88,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: savedHistory.length,
                          itemBuilder: (_, i) {
                            final trip = savedHistory[i];
                            final from = trip['from'] as String? ?? 'CBT';
                            final to = trip['to'] as String? ?? 'Destination';
                            return _SavedRouteChip(
                              from: from,
                              to: to,
                              via: trip['route'] as String? ?? '',
                              icon: Icons.directions_bus,
                              color: const Color(0xFF7B61FF),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 18),

                    // ── Popular Places (photos) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(AppLang.t('popular_places'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E))),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 130,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: popularPlaces.length,
                        itemBuilder: (_, i) {
                          final place = popularPlaces[i];
                          return _PopularPlacePhotoCard(
                            place: place,
                            onTap: () => _openPlace(place),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularPlacePhotoCard extends StatelessWidget {
  final PopularPlace place;
  final VoidCallback onTap;

  const _PopularPlacePhotoCard({
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                place.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A3A5C),
                  child: const Icon(Icons.landscape,
                      color: Colors.white54, size: 40),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    Text(place.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Rapido-style map painter (green roads on light background)
class _RapidoMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background — light greenish map colour like Rapido
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFE8F0E8));

    // Water body (lake — top left, like in the screenshot)
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.01, size.height * 0.04, size.width * 0.18,
            size.height * 0.22),
        Paint()..color = const Color(0xFFADD8E6).withOpacity(0.7));

    // Roads (white lines)
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final thinRoad = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3.5;

    // Horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.25),
        Offset(size.width, size.height * 0.25), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.55),
        Offset(size.width, size.height * 0.55), thinRoad);
    canvas.drawLine(Offset(0, size.height * 0.78),
        Offset(size.width, size.height * 0.78), thinRoad);

    // Vertical roads
    canvas.drawLine(Offset(size.width * 0.3, 0),
        Offset(size.width * 0.3, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.62, 0),
        Offset(size.width * 0.62, size.height), thinRoad);
    canvas.drawLine(Offset(size.width * 0.82, 0),
        Offset(size.width * 0.82, size.height), thinRoad);

    // Diagonal road (like Shindoli Rd in screenshot)
    canvas.drawLine(Offset(size.width * 0.22, 0),
        Offset(size.width * 0.45, size.height), roadPaint);

    // Road labels
    final textStyle =
        const TextStyle(color: Color(0xFF555555), fontSize: 10, height: 1);
    _drawText(canvas, 'Shindoli Rd', size.width * 0.06, size.height * 0.44,
        textStyle);
    _drawText(
        canvas, '6th Cross', size.width * 0.52, size.height * 0.57, textStyle);
    _drawText(
        canvas, '13th Cross', size.width * 0.65, size.height * 0.05, textStyle);

    // Building blocks
    final buildPaint = Paint()..color = Colors.white.withOpacity(0.6);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.04, size.height * 0.36,
                size.width * 0.14, size.height * 0.14),
            const Radius.circular(3)),
        buildPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.65, size.height * 0.28,
                size.width * 0.1, size.height * 0.1),
            const Radius.circular(3)),
        buildPaint);
  }

  void _drawText(
      Canvas canvas, String text, double x, double y, TextStyle style) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── HOME UI HELPERS ─────────────────────────────────────────────────────────

class _HomeDrawer extends StatelessWidget {
  final void Function(int tabIndex)? onTabChange;

  const _HomeDrawer({this.onTabChange});

  void _go(BuildContext context, int tab) {
    Navigator.pop(context);
    onTabChange?.call(tab);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D2137), Color(0xFF1A3A5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF7B61FF).withOpacity(0.2),
                    child:
                        const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Guest',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Sign in to sync your trips',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            _DrawerTile(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () => _go(context, 0),
            ),
            _DrawerTile(
              icon: Icons.directions_bus,
              label: 'CBT Buses',
              onTap: () => _go(context, 1),
            ),
            _DrawerTile(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () => _go(context, 2),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'TrackBus · Belagavi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF7B61FF)),
      title: Text(label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1F35))),
      onTap: onTap,
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashHeight = 4.0;
    const gap = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashHeight), paint);
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LiveMapPainter extends CustomPainter {
  final List<BusData> buses;
  _LiveMapPainter({required this.buses});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFE8F0FE),
    );

    final parkPaint = Paint()
      ..color = const Color(0xFFBBF7D0).withOpacity(0.45);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.08, size.width * 0.22,
            size.height * 0.28),
        parkPaint);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.55, size.width * 0.25,
            size.height * 0.3),
        parkPaint);

    final streetPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), streetPaint);
    }
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), streetPaint);
    }

    final userX = size.width * 0.48;
    final userY = size.height * 0.52;
    for (var r = 3; r > 0; r--) {
      canvas.drawCircle(
        Offset(userX, userY),
        10.0 * r,
        Paint()
          ..color = const Color(0xFF3B82F6).withOpacity(0.1 * r)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawCircle(
      Offset(userX, userY),
      6,
      Paint()..color = const Color(0xFF3B82F6),
    );

    final positions = [
      [0.2, 0.22],
      [0.72, 0.28],
      [0.28, 0.72],
      [0.62, 0.68],
      [0.82, 0.78],
    ];
    for (var i = 0; i < positions.length; i++) {
      final px = size.width * positions[i][0];
      final py = size.height * positions[i][1];
      final isFeatured = i == 0;
      canvas.drawCircle(
        Offset(px, py),
        isFeatured ? 13 : 11,
        Paint()
          ..color =
              isFeatured ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
      );
      final icon = TextPainter(
        text: const TextSpan(text: '🚌', style: TextStyle(fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      icon.paint(canvas, Offset(px - icon.width / 2, py - icon.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LiveMapPainter oldDelegate) =>
      oldDelegate.buses != buses;
}

class _MapBusPopup extends StatelessWidget {
  final BusData bus;
  final String label;
  const _MapBusPopup({required this.bus, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1F35))),
          Text('${bus.eta} mins away',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF22C55E))),
        ],
      ),
    );
  }
}

class _HomeInfoCard extends StatelessWidget {
  final String title;
  final String linkText;
  final VoidCallback onLinkTap;
  final List<Widget> children;

  const _HomeInfoCard({
    required this.title,
    required this.linkText,
    required this.onLinkTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D1F35))),
              ),
              GestureDetector(
                onTap: onLinkTap,
                child: Text(linkText,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B61FF))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _HomeBusListRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String eta;
  final Color etaColor;
  final String? trailing;
  final bool isLast;
  final VoidCallback onTap;

  const _HomeBusListRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.eta,
    required this.etaColor,
    this.trailing,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D1F35))),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 9, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(eta,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: etaColor)),
                if (trailing != null)
                  Text(trailing!,
                      style: const TextStyle(
                          fontSize: 8, color: Color(0xFF9CA3AF))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedRouteChip extends StatelessWidget {
  final String from;
  final String to;
  final String via;
  final IconData icon;
  final Color color;

  const _SavedRouteChip({
    required this.from,
    required this.to,
    required this.via,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$from → $to',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D1F35))),
                const SizedBox(height: 2),
                Text(via,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
        ],
      ),
    );
  }
}

class _ArrivingSection extends StatelessWidget {
  final List<BusData> buses;
  const _ArrivingSection({required this.buses});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.access_time, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          const Text('Buses Arriving Now',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(children: [
                Icon(Icons.circle, color: Color(0xFF2196F3), size: 7),
                SizedBox(width: 4),
                Text('Live',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1A3A5C),
                        fontWeight: FontWeight.w600))
              ])),
        ]),
        const SizedBox(height: 12),
        ...buses.map((bus) => _HomeBusTile(bus: bus)),
      ],
    );
  }
}

class _HomeBusTile extends StatelessWidget {
  final BusData bus;
  const _HomeBusTile({required this.bus});

  @override
  Widget build(BuildContext context) {
    final level = bus.crowdLevel;
    Color crowdColor = level < 0.4
        ? const Color(0xFF2E7D32)
        : level < 0.7
            ? const Color(0xFFF57C00)
            : const Color(0xFFC62828);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => BusDetailScreen(bus: bus))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: bus.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child:
                      Icon(Icons.directions_bus, color: bus.color, size: 24)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(bus.busNo,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E))),
                    Text(bus.route,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.people, size: 12, color: crowdColor),
                      const SizedBox(width: 3),
                      Text(bus.crowd,
                          style: TextStyle(
                              fontSize: 11,
                              color: crowdColor,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                  value: level,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(crowdColor),
                                  minHeight: 5))),
                    ]),
                  ])),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: bus.eta <= 5
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(bus.eta <= 1 ? 'Now!' : '${bus.eta} min',
                    style: TextStyle(
                        color: bus.eta <= 5
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTripTile extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _RecentTripTile({required this.trip});
  @override
  Widget build(BuildContext context) {
    final color = trip['color'] as Color;
    final level = trip['crowdLevel'] as double;
    Color crowdColor = level < 0.4
        ? const Color(0xFF2E7D32)
        : level < 0.7
            ? const Color(0xFFF57C00)
            : const Color(0xFFC62828);
    return GestureDetector(
      onTap: () {
        final bus = allBuses.firstWhere((b) => b.busNo == trip['busNo'],
            orElse: () => allBuses.first);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => BusDetailScreen(bus: bus)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
            ]),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.directions_bus, color: color, size: 24)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(trip['busNo'] as String,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E))),
                    Text(trip['route'] as String,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(
                          level < 0.4
                              ? Icons.sentiment_very_satisfied
                              : level < 0.7
                                  ? Icons.sentiment_neutral
                                  : Icons.sentiment_very_dissatisfied,
                          size: 13,
                          color: crowdColor),
                      const SizedBox(width: 3),
                      Text(trip['crowd'] as String,
                          style: TextStyle(
                              fontSize: 11,
                              color: crowdColor,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                  value: level,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(crowdColor),
                                  minHeight: 5))),
                    ]),
                  ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('To ${trip['to']}',
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600))),
                const SizedBox(height: 4),
                Text(trip['lastTravelled'] as String,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ]),
            ])),
      ),
    );
  }
}

// ─── SEARCH SCREEN (Rapido-style: destination only, autofocused) ─────────────

// ─── PLACE BUSES SCREEN ──────────────────────────────────────────────────────

class PlaceBusesScreen extends StatelessWidget {
  final PopularPlace place;
  const PlaceBusesScreen({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final key = place.searchKey.toLowerCase();
    final all = busesForPlace(place.searchKey);
    final toBuses = all.where((b) {
      return b.stops.isNotEmpty &&
          b.stops.last.name.toLowerCase().contains(key);
    }).toList();
    final viaBuses = all.where((b) {
      final contains = b.stops.any((s) => s.name.toLowerCase().contains(key));
      final isTo =
          b.stops.isNotEmpty && b.stops.last.name.toLowerCase().contains(key);
      return contains && !isTo;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Stack(
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  place.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A3A5C),
                  ),
                ),
              ),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${AppLang.t('buses_to')} ${place.name}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            Text(place.subtitle,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: (toBuses.isEmpty && viaBuses.isEmpty)
                ? Center(
                    child: Text(AppLang.t('no_buses_to_place'),
                        style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView(padding: const EdgeInsets.all(16), children: [
                    if (toBuses.isNotEmpty) ...[
                      const Text('Buses to destination',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ...toBuses.map((b) => Column(children: [
                            _SearchBusCard(bus: b),
                            const SizedBox(height: 10),
                          ])),
                      const SizedBox(height: 16),
                    ],
                    if (viaBuses.isNotEmpty) ...[
                      const Text('Buses passing through',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      ...viaBuses.map((b) => Column(children: [
                            _SearchBusCard(bus: b),
                            const SizedBox(height: 10),
                          ])),
                    ],
                  ]),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool autoFocus;
  final String? initialFrom;
  final String? initialTo;
  const SearchScreen({
    super.key,
    this.onBack,
    this.autoFocus = false,
    this.initialFrom,
    this.initialTo,
  });
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();

  String _from = '';
  String _to = '';
  bool _fromActive = false;
  bool _toActive = false;
  List<BusData> _results = [];

  static const _yellow = Color(0xFFF4A024);
  static const _navy = Color(0xFF1A3A5C);

  // All unique stop names for suggestions
  List<String> get _allStops => allStops;

  List<String> _suggest(String q) {
    if (q.isEmpty) return suggestedStops.take(6).toList();
    final ql = q.toLowerCase();
    return _allStops
      .where((s) => s.toLowerCase().startsWith(ql))
      .take(6)
      .toList();
  }

  @override
  void initState() {
    super.initState();
    _fromCtrl.text = widget.initialFrom ?? 'CBT';
    _from = widget.initialFrom ?? 'CBT';
    if (widget.initialTo != null) {
      _toCtrl.text = widget.initialTo!;
      _to = widget.initialTo!;
    }
    _results = List.from(allBuses);
    _fromFocus
        .addListener(() => setState(() => _fromActive = _fromFocus.hasFocus));
    _toFocus.addListener(() => setState(() => _toActive = _toFocus.hasFocus));
    if (widget.autoFocus) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _toFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _filter() {
    setState(() {
      _results = allBuses.where((b) {
        final routeLower = b.route.toLowerCase();
        final stopsLower = b.stops.map((s) => s.name.toLowerCase()).toList();
        final fromOk = _from.isEmpty ||
            routeLower.contains(_from.toLowerCase()) ||
            stopsLower.any((s) => s.contains(_from.toLowerCase()));
        final toOk = _to.isEmpty ||
            routeLower.contains(_to.toLowerCase()) ||
            stopsLower.any((s) => s.contains(_to.toLowerCase()));
        return fromOk && toOk;
      }).toList();
    });
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _suggestionList(String query, void Function(String) onSelect,
      {bool showLabel = false}) {
    final sug = _suggest(query);
    if (sug.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLabel && query.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(AppLang.t('suggested_places'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF))),
            ),
          ...sug.map((s) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(s),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A2E))),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 16, color: Color(0xFF9CA3AF)),
                  ]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _locationField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required Color dotColor,
    required bool isSquareDot,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    required bool showClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focusNode.hasFocus ? _yellow : Colors.grey.shade200,
          width: focusNode.hasFocus ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: isSquareDot ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isSquareDot ? BorderRadius.circular(2) : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500)),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E)),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 2),
                  ),
                ),
              ],
            ),
          ),
          if (showClear)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        // ── Header: FROM + TO ──
        Container(
          color: _navy,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconButton(
                  onPressed: _handleBack,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _locationField(
                        controller: _fromCtrl,
                        focusNode: _fromFocus,
                        label: AppLang.t('from'),
                        hint: AppLang.t('from_hint'),
                        dotColor: const Color(0xFF4CAF50),
                        isSquareDot: false,
                        showClear: _from.isNotEmpty,
                        onChanged: (v) {
                          setState(() => _from = v);
                          _filter();
                        },
                        onClear: () {
                          _fromCtrl.clear();
                          setState(() => _from = '');
                          _filter();
                        },
                      ),
                      const SizedBox(height: 12),
                      _locationField(
                        controller: _toCtrl,
                        focusNode: _toFocus,
                        label: AppLang.t('to'),
                        hint: AppLang.t('to_hint'),
                        dotColor: _yellow,
                        isSquareDot: true,
                        showClear: _to.isNotEmpty,
                        onChanged: (v) {
                          setState(() => _to = v);
                          _filter();
                        },
                        onClear: () {
                          _toCtrl.clear();
                          setState(() => _to = '');
                          _filter();
                        },
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Suggestions dropdown ──
        if (_fromActive || _toActive)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _fromActive
                ? _suggestionList(_from, (s) {
                    _fromCtrl.text = s;
                    setState(() => _from = s);
                    _fromFocus.unfocus();
                    _filter();
                    _toFocus.requestFocus();
                  }, showLabel: true)
                : _suggestionList(_to, (s) {
                    _toCtrl.text = s;
                    setState(() => _to = s);
                    // ensure keyboard is dismissed and results updated
                    _toFocus.unfocus();
                    FocusScope.of(context).unfocus();
                    _filter();
                  }, showLabel: true),
          ),

        // ── Results ──
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off,
                        size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(AppLang.t('no_buses_found'),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(AppLang.t('try_different'),
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _SearchBusCard(bus: _results[i]),
                ),
        ),
      ]),
    );
  }
}

class _SearchBusCard extends StatelessWidget {
  final BusData bus;
  const _SearchBusCard({required this.bus});

  String get _routeLabel => formatCbtRoute(bus);

  // Middle stops as a short preview
  String get _via {
    if (bus.stops.length > 2) {
      final mid = bus.stops
          .sublist(1, bus.stops.length - 1)
          .map((s) => s.name)
          .take(2)
          .join(', ');
      return 'Via $mid';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => BusDetailScreen(bus: bus))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: bus.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.directions_bus, color: bus.color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // FROM → TO in bold
              Text(_routeLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E))),
              if (_via.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(_via,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: bus.eta <= 5
                      ? const Color(0xFF22C55E).withOpacity(0.12)
                      : const Color(0xFFF4A024).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${bus.eta} min',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: bus.eta <= 5
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF4A024))),
            ),
            const SizedBox(height: 4),
            Text(bus.distance,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ]),
        ]),
      ),
    );
  }
}

// ─── CBT SCREEN — Bus grid with all buses at CBT ──────────────────────────────

class CBTScreen extends StatefulWidget {
  const CBTScreen({super.key});
  @override
  State<CBTScreen> createState() => _CBTScreenState();
}

class _CBTScreenState extends State<CBTScreen> {
  static const _yellow = Color(0xFFF4A024);
  static const _navy = Color(0xFF1A3A5C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        // Header
        Container(
          color: _navy,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Row(children: [
                Text(AppLang.t('cbt'),
                    style: const TextStyle(
                        color: Color(0xFFF4A024),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppLang.t('cbt_terminal'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  Text(AppLang.t('central_terminal'),
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12)),
                ]),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${allBuses.length} ${AppLang.t('buses')}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),

        // Bus grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: allBuses.length,
            itemBuilder: (_, i) {
              final bus = allBuses[i];
              return _CBTBusBox(bus: bus, index: i);
            },
          ),
        ),
      ]),
    );
  }
}

class _CBTBusBox extends StatelessWidget {
  final BusData bus;
  final int index;
  const _CBTBusBox({required this.bus, required this.index});

  // Give each bus a platform number
  String get _platform => 'P${(index % 12) + 1}';

  Color get _statusColor {
    if (bus.eta <= 3) return const Color(0xFF22C55E); // arriving
    if (bus.eta <= 8) return const Color(0xFFF4A024); // soon
    return const Color(0xFF94A3B8); // later
  }

  String get _statusLabel {
    if (bus.eta <= 3) return AppLang.t('arriving');
    if (bus.eta <= 8) return AppLang.t('soon');
    return '${bus.eta} ${AppLang.t('min')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => BusDetailScreen(bus: bus))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          // Top coloured band with bus icon
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: bus.color.withOpacity(0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Column(children: [
              Icon(Icons.directions_bus, color: bus.color, size: 30),
              const SizedBox(height: 4),
              Text(AppLang.t('cbt'),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: bus.color,
                      letterSpacing: 0.5),
                  textAlign: TextAlign.center),
            ]),
          ),
          // Bus info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatCbtRoute(bus),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(_statusLabel,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _statusColor)),
                    ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── BUS DETAIL SCREEN ───────────────────────────────────────────────────────

class BusDetailScreen extends StatefulWidget {
  final BusData bus;
  const BusDetailScreen({super.key, required this.bus});
  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  late int _eta;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _eta = widget.bus.eta;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() {
        if (_eta > 0) _eta--;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color get _crowdColor => widget.bus.crowdLevel < 0.4
      ? const Color(0xFF2E7D32)
      : widget.bus.crowdLevel < 0.7
          ? const Color(0xFFF57C00)
          : const Color(0xFFC62828);

  IconData get _crowdIcon => widget.bus.crowdLevel < 0.4
      ? Icons.sentiment_very_satisfied
      : widget.bus.crowdLevel < 0.7
          ? Icons.sentiment_neutral
          : Icons.sentiment_very_dissatisfied;

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    final color = bus.color;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero header ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Back + title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 20)),
                        ),
                        const SizedBox(width: 12),
                        const Text('Bus Details',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Row(children: [
                              Icon(Icons.circle,
                                  color: Colors.greenAccent, size: 8),
                              SizedBox(width: 4),
                              Text('Live',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))
                            ])),
                      ]),
                    ),
                    // TrackBus logo + bus number
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.directions_bus,
                                color: Colors.white, size: 32)),
                        const SizedBox(width: 14),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TrackBusLogoText(
                                  fontSize: 11,
                                  trackColor: Colors.white70,
                                  busColor: Color(0xFFF4A024)),
                              Text(bus.busNo,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800)),
                              Text(bus.route,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ]),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            // ── Driver & Conductor ──
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Text('Staff Details',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.3)),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _StaffRow(
                      icon: Icons.drive_eta,
                      label: 'Driver',
                      name: bus.driverName,
                      phone: bus.driverPhone,
                      color: color),
                  Divider(height: 1, color: Colors.grey.shade100, indent: 56),
                  _StaffRow(
                      icon: Icons.confirmation_number,
                      label: 'Conductor',
                      name: bus.conductorName,
                      phone: bus.conductorPhone,
                      color: color),
                ],
              ),
            ),

            // ── 3 info boxes ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                // ETA
                Expanded(
                    child: _InfoBox(
                  color: color,
                  icon: Icons.access_time_filled,
                  label: 'Arrival Time',
                  value: _eta <= 0 ? 'Here!' : '$_eta min',
                  sub: _eta <= 0 ? 'Bus arrived' : 'away from you',
                )),
                const SizedBox(width: 10),
                // Distance
                Expanded(
                    child: _InfoBox(
                  color: const Color(0xFF1565C0),
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: bus.distance,
                  sub: 'from your stop',
                )),
                const SizedBox(width: 10),
                // Crowd
                Expanded(
                    child: _InfoBox(
                  color: _crowdColor,
                  icon: _crowdIcon,
                  label: 'Crowd',
                  value: bus.crowd,
                  sub: '${(bus.crowdLevel * 100).toInt()}% full',
                  progress: bus.crowdLevel,
                )),
              ]),
            ),

            // ── Route Timeline ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(children: [
                      Icon(Icons.route, color: color, size: 18),
                      const SizedBox(width: 6),
                      Text('Route & Live Position',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700)),
                    ]),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: bus.stops.asMap().entries.map((entry) {
                        final i = entry.key;
                        final stop = entry.value;
                        final isLast = i == bus.stops.length - 1;
                        return _StopTimelineTile(
                            stop: stop, color: color, isLast: isLast);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  final IconData icon;
  final String label, name, phone;
  final Color color;
  const _StaffRow(
      {required this.icon,
      required this.label,
      required this.name,
      required this.phone,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          Text(name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E))),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const Icon(Icons.phone, size: 12, color: Color(0xFF2E7D32)),
            const SizedBox(width: 4),
            Text(phone,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600))
          ]),
        ),
      ]),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label, value, sub;
  final double? progress;
  const _InfoBox(
      {required this.color,
      required this.icon,
      required this.label,
      required this.value,
      required this.sub,
      this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        if (progress != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4)),
        ],
      ]),
    );
  }
}

class _StopTimelineTile extends StatelessWidget {
  final BusStop stop;
  final Color color;
  final bool isLast;
  const _StopTimelineTile(
      {required this.stop, required this.color, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isPassed = stop.status == 'passed';
    final isCurrent = stop.status == 'current';

    Color dotColor = isCurrent
        ? color
        : isPassed
            ? Colors.grey.shade400
            : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(
              width: isCurrent ? 18 : 12,
              height: isCurrent ? 18 : 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: color.withOpacity(0.3), width: 3)
                    : null,
                boxShadow: isCurrent
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)]
                    : null,
              ),
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 44,
                  color:
                      isPassed ? Colors.grey.shade300 : Colors.grey.shade200),
          ]),
        ),
        const SizedBox(width: 12),
        // Stop info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(stop.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isPassed
                                    ? Colors.grey
                                    : const Color(0xFF1A1A2E)))),
                    Text(stop.time,
                        style: TextStyle(
                            fontSize: 12,
                            color: isPassed
                                ? Colors.grey
                                : const Color(0xFF1A3A5C),
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.normal)),
                  ],
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.directions_bus, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text('Bus is here now',
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── SAVED ROUTES SCREEN ────────────────────────────────────────────────────

class SavedRoutesScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const SavedRoutesScreen({super.key, this.onBack});

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  bool _showBack(BuildContext context) =>
      onBack != null || Navigator.canPop(context);

  @override
  Widget build(BuildContext context) {
    final history = UserSession.travelHistory;
    final showBack = _showBack(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // ── Header ──
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D2137),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (showBack)
                        IconButton(
                          onPressed: () => _handleBack(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 24),
                        ),
                      if (showBack) const SizedBox(width: 8),
                      const Icon(Icons.bookmark,
                          color: Color(0xFFF4A024), size: 22),
                      const SizedBox(width: 10),
                      const Text('Saved Routes',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 8),
                    const Text('Your travel history & saved buses',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          // ── Body ──
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.bookmark_outline,
                            size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No saved routes yet',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('Travel on a bus to save routes here',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ]))
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      const SizedBox(height: 4),
                      const Text('YOUR TRAVELLED ROUTES',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      ...history.map((t) {
                        final color = t['color'] as Color;
                        return GestureDetector(
                          onTap: () {
                            final bus = allBuses.firstWhere(
                                (b) => b.busNo == t['busNo'],
                                orElse: () => allBuses.first);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => BusDetailScreen(bus: bus)));
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8)
                                ]),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(Icons.directions_bus,
                                        color: color, size: 24)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(t['busNo'] as String,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1A1A2E))),
                                      Text(t['route'] as String,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Text(
                                              'To ' + (t['to'] as String),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: color,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                    ])),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Icon(Icons.arrow_forward_ios,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(height: 6),
                                      Text(t['lastTravelled'] as String,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade400)),
                                    ]),
                              ]),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── PROFILE SCREEN ──────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editProfile() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
        (_) => false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A3A5C)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.currentUser;
    final hasPhoto =
        u?.photoPath != null && !kIsWeb && File(u!.photoPath!).existsSync();

    if (u == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const RegisterScreen())),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A5C)),
            child: const Text('Login / Register'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // ── Blue top half with user details ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D2137), Color(0xFF1A3A5C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                child: Column(
                  children: [
                    // Top bar
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF4A024),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.directions_bus,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const TrackBusLogoText(fontSize: 20),
                    ]),
                    const SizedBox(height: 24),
                    // Photo LEFT, details RIGHT
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _editProfile,
                          child: Stack(children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 3),
                              ),
                              child: hasPhoto
                                  ? ClipOval(
                                      child: Image.file(File(u.photoPath!),
                                          fit: BoxFit.cover))
                                  : const Icon(Icons.person,
                                      color: Colors.white, size: 46),
                            ),
                            Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFF4A024),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 13),
                                )),
                          ]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(u.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(u.email,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('📱 ${u.mobile}',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Text('📍 Belagavi, Karnataka',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 11)),
                              ),
                            ])),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── White bottom with options ──
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('ACCOUNT OPTIONS',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  _ProfileOption(
                    icon: Icons.edit,
                    label: 'Edit Profile',
                    sub: 'Update your name, phone, photo',
                    color: const Color(0xFF1A3A5C),
                    onTap: _editProfile,
                  ),
                  _ProfileOption(
                      icon: Icons.school,
                      label: 'Student Registration',
                      sub: 'Register for student bus pass',
                      color: const Color(0xFF2E7D32),
                      onTap: () =>
                          _showSnack('Student Registration coming soon!')),
                  _ProfileOption(
                      icon: Icons.bookmark,
                      label: 'Edit Saved Routes',
                      sub: 'Manage your saved bus routes',
                      color: const Color(0xFF6A1B9A),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SavedRoutesScreen()))),
                  _ProfileOption(
                      icon: Icons.language,
                      label: AppLang.t('language'),
                      sub: AppLang.t('language_sub'),
                      color: const Color(0xFF7B61FF),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LanguageSelectScreen(
                                  fromSettings: true)))),
                  _ProfileOption(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      sub: 'Manage bus arrival alerts',
                      color: const Color(0xFFF57C00),
                      onTap: () => _showSnack('Notifications coming soon!')),
                  const SizedBox(height: 8),
                  const Text('MORE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  _ProfileOption(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      sub: 'FAQs and contact us',
                      color: Colors.grey,
                      onTap: () => _showSnack('Help coming soon!')),
                  _ProfileOption(
                      icon: Icons.logout,
                      label: 'Logout',
                      sub: 'Sign out of your account',
                      color: const Color(0xFFC62828),
                      onTap: _logout),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;

  const _ProfileOption(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E))),
                Text(sub,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ])),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ONBOARDING FLOW  (Phone → OTP → Profile → Location)
// ═══════════════════════════════════════════════════════════════════════════

// ── Design tokens ──
const _obNavy = Color(0xFF0D1F35);
const _obBlue = Color(0xFF1A3A5C);
const _obAccent = Color(0xFFF4A024);
const _obAccentDark = Color(0xFFD98A18);
const _obBg = Color(0xFFF5F7FA);
const _obSurface = Colors.white;
const _obTextMain = Color(0xFF0D1F35);
const _obTextSub = Color(0xFF6B7280);

// ─── 1. PHONE ENTRY ──────────────────────────────────────────────────────────

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});
  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen>
    with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _phoneCtrl.text.trim().length == 10;

  void _onPhoneChanged(String val) {
    setState(() {});
    if (val.trim().length == 10) {
      // Auto-proceed after brief delay (like Rapido)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _phoneCtrl.text.trim().length == 10) {
          _sendOtp();
        }
      });
    }
  }

  Future<void> _sendOtp() async {
    if (!_valid) return;
    setState(() => _loading = true);
    final otp = (100000 + Random().nextInt(900000)).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trackbus_demo_otp', otp);
    await prefs.setString('trackbus_pending_phone', _phoneCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Demo OTP: $otp  (sent to +91 ${_phoneCtrl.text.trim()})'),
      backgroundColor: _obBlue,
      duration: const Duration(seconds: 6),
    ));
    Navigator.push(
        context, _obSlideRoute(OtpScreen(phone: _phoneCtrl.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _obBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero ──
            Container(
              width: double.infinity,
              height: 270,
              decoration: const BoxDecoration(
                color: _obNavy,
              ),
              child: Stack(children: [
                // Creative background: route stops pattern
                // Subtle grid dots
                ...[
                  [30.0, 40.0],
                  [90.0, 40.0],
                  [150.0, 40.0],
                  [210.0, 40.0],
                  [270.0, 40.0],
                  [330.0, 40.0],
                  [30.0, 90.0],
                  [90.0, 90.0],
                  [150.0, 90.0],
                  [210.0, 90.0],
                  [270.0, 90.0],
                  [330.0, 90.0],
                  [30.0, 140.0],
                  [90.0, 140.0],
                  [150.0, 140.0],
                  [210.0, 140.0],
                  [270.0, 140.0],
                  [330.0, 140.0],
                  [30.0, 190.0],
                  [90.0, 190.0],
                  [150.0, 190.0],
                  [210.0, 190.0],
                  [270.0, 190.0],
                  [330.0, 190.0],
                ].map((p) => Positioned(
                      left: p[0],
                      top: p[1],
                      child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              shape: BoxShape.circle)),
                    )),
                // Horizontal route line
                Positioned(
                  top: 165,
                  left: 24,
                  right: 24,
                  child: Container(
                      height: 2, color: Colors.white.withOpacity(0.12)),
                ),
                // Stop dots on route
                ...[
                  [24.0, 159.0],
                  [110.0, 159.0],
                  [220.0, 159.0],
                  [330.0, 159.0]
                ].map((p) => Positioned(
                      left: p[0],
                      top: p[1],
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _obNavy,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _obAccent.withOpacity(0.7), width: 2),
                        ),
                      ),
                    )),
                // Glowing accent circle top-right
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _obAccent.withOpacity(0.08),
                    ),
                  ),
                ),
                // Moving bus animation
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: MovingBusWidget(
                    height: 120,
                    busColor: _obAccent,
                    roadColor: _obAccent,
                  ),
                ),
                // logo with styled text
                Positioned(
                  top: 22,
                  left: 22,
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: _obAccent,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.directions_bus,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const TrackBusLogoText(fontSize: 24),
                  ]),
                ),
              ]),
            ),
            // ── Form ──
            Expanded(
              child: FadeTransition(
                opacity: _fade,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enter your\nphone number',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _obTextMain,
                              height: 1.2)),
                      const SizedBox(height: 8),
                      const Text(
                          "We'll send a one-time password to verify it's you.",
                          style: TextStyle(color: _obTextSub, fontSize: 14)),
                      const SizedBox(height: 28),
                      // phone field
                      Container(
                        decoration: BoxDecoration(
                          color: _obSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            width: 78,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(children: const [
                              Text('🇮🇳', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 4),
                              Text('+91',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: _obTextMain)),
                            ]),
                          ),
                          Container(
                              width: 1,
                              height: 32,
                              color: const Color(0xFFE5E7EB)),
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              onChanged: _onPhoneChanged,
                              autofocus: true,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2),
                              decoration: const InputDecoration(
                                hintText: '0000000000',
                                hintStyle: TextStyle(
                                    color: Color(0xFFD1D5DB),
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w400),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 18),
                                counterText: '',
                              ),
                            ),
                          ),
                          if (_valid)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                          'By continuing you agree to our Terms & Privacy Policy.',
                          style: TextStyle(fontSize: 11, color: _obTextSub)),
                      const SizedBox(height: 30),
                      _ObButton(
                        label: 'Send OTP',
                        enabled: _valid && !_loading,
                        loading: _loading,
                        onTap: _sendOtp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 2. OTP SCREEN ───────────────────────────────────────────────────────────

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = 30;
  Timer? _timer;
  bool _loading = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _ctrls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();
  bool get _filled => _otp.length == 6;

  void _onBoxChanged(int idx, String val) {
    if (val.length >= 6) {
      for (int i = 0; i < 6 && i < val.length; i++) {
        _ctrls[i].text = val[i];
      }
      _nodes[5].requestFocus();
      setState(() {});
      _verify();
      return;
    } else if (val.length == 1 && idx < 5) {
      _nodes[idx + 1].requestFocus();
    } else if (val.isEmpty && idx > 0) {
      _nodes[idx - 1].requestFocus();
    }
    setState(() {});
    // Auto-verify when last box filled
    if (_filled) {
      Future.delayed(const Duration(milliseconds: 100), _verify);
    }
  }

  Future<void> _verify() async {
    if (!_filled) return;
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('trackbus_demo_otp') ?? '';
    if (_otp != stored) {
      if (!mounted) return;
      setState(() => _loading = false);
      _shakeCtrl.forward(from: 0);
      for (final c in _ctrls) c.clear();
      _nodes[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incorrect OTP. Please try again.'),
          backgroundColor: Colors.red));
      return;
    }
    await prefs.remove('trackbus_demo_otp');
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushReplacement(
        context, _obSlideRoute(ProfileSetupScreen(phone: widget.phone)));
  }

  Future<void> _resend() async {
    final newOtp = (100000 + Random().nextInt(900000)).toString();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trackbus_demo_otp', newOtp);
    _startTimer();
    for (final c in _ctrls) c.clear();
    _nodes[0].requestFocus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('New Demo OTP: $newOtp'),
      backgroundColor: _obBlue,
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _obBg,
      appBar: AppBar(
        backgroundColor: _obBg,
        elevation: 0,
        foregroundColor: _obTextMain,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Verify OTP',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _obTextMain)),
              const SizedBox(height: 8),
              RichText(
                  text: TextSpan(
                style: const TextStyle(color: _obTextSub, fontSize: 14),
                children: [
                  const TextSpan(text: 'Code sent to '),
                  TextSpan(
                      text: '+91 ${widget.phone}',
                      style: const TextStyle(
                          color: _obTextMain, fontWeight: FontWeight.w700)),
                ],
              )),
              const SizedBox(height: 36),
              // OTP boxes with shake
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                      sin(_shakeAnim.value * pi * 6) *
                          8 *
                          (1 - _shakeAnim.value),
                      0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, _buildBox),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: _secondsLeft > 0
                    ? RichText(
                        text: TextSpan(
                            style: const TextStyle(
                                color: _obTextSub, fontSize: 14),
                            children: [
                            const TextSpan(text: 'Resend OTP in '),
                            TextSpan(
                                text: '${_secondsLeft}s',
                                style: const TextStyle(
                                    color: _obAccent,
                                    fontWeight: FontWeight.w700)),
                          ]))
                    : GestureDetector(
                        onTap: _resend,
                        child: const Text('Resend OTP',
                            style: TextStyle(
                                color: _obAccent,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline)),
                      ),
              ),
              const Spacer(),
              _ObButton(
                label: 'Verify & Continue',
                enabled: _filled && !_loading,
                loading: _loading,
                onTap: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBox(int i) {
    final isFilled = _ctrls[i].text.isNotEmpty;
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: _obTextMain),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: isFilled ? _obAccent.withOpacity(0.12) : _obSurface,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: isFilled ? _obAccent : const Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _obAccent, width: 2)),
        ),
        onChanged: (v) => _onBoxChanged(i, v),
      ),
    );
  }
}

// ─── 3. PROFILE SETUP ────────────────────────────────────────────────────────

class ProfileSetupScreen extends StatefulWidget {
  final String phone;
  const ProfileSetupScreen({super.key, required this.phone});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _gender;
  bool _saving = false;

  late AnimationController _avatarCtrl;
  late Animation<double> _avatarScale;

  final _genders = ['Male', 'Female', 'Other'];
  final _gEmoji = ['👨', '👩', '🧑'];

  @override
  void initState() {
    super.initState();
    _avatarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _avatarScale =
        CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut);
    _avatarCtrl.forward();
  }

  @override
  void dispose() {
    _avatarCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed => _nameCtrl.text.trim().length >= 2;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final email = _emailCtrl.text.trim().isNotEmpty
        ? _emailCtrl.text.trim()
        : '${widget.phone}@trackbus.app';

    final user = AuthUser(
      name: name,
      mobile: widget.phone,
      email: email,
      password: widget.phone,
    );
    await AuthService.register(user);
    await AuthService.login(email, widget.phone);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacement(
        context, _obSlideRoute(const LocationPermissionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _obBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 20, 0),
            child: Row(children: [
              BackButton(
                  onPressed: () => Navigator.pop(context), color: _obTextMain),
              const Expanded(
                child: Text('Your Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _obTextMain)),
              ),
              const SizedBox(width: 40),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Center(
                    child: ScaleTransition(
                      scale: _avatarScale,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              colors: [_obBlue, _obNavy],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          boxShadow: [
                            BoxShadow(
                                color: _obBlue.withOpacity(0.3),
                                blurRadius: 18,
                                spreadRadius: 2)
                          ],
                        ),
                        child: Center(
                            child: Text(
                          _gender == 'Female'
                              ? '👩'
                              : _gender == 'Other'
                                  ? '🧑'
                                  : '👨',
                          style: const TextStyle(fontSize: 42),
                        )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                      child: Text('+91 ${widget.phone}',
                          style: const TextStyle(
                              color: _obTextSub,
                              fontSize: 13,
                              fontWeight: FontWeight.w500))),
                  const SizedBox(height: 28),
                  // Name
                  const _ObLabel('Full Name *'),
                  const SizedBox(height: 8),
                  _ObField(
                      controller: _nameCtrl,
                      hint: 'Your full name',
                      icon: Icons.person_outline,
                      onChanged: (_) => setState(() {})),
                  const SizedBox(height: 20),
                  // Gender
                  const _ObLabel('Gender'),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_genders.length, (i) {
                      final g = _genders[i];
                      final sel = _gender == g;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _gender = g),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _obAccent.withOpacity(0.12)
                                  : _obSurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color:
                                      sel ? _obAccent : const Color(0xFFE5E7EB),
                                  width: sel ? 2 : 1),
                            ),
                            child: Column(children: [
                              Text(_gEmoji[i],
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text(g,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sel ? _obAccentDark : _obTextSub)),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // Email optional
                  Row(children: [
                    const _ObLabel('Email ID'),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Optional',
                          style: TextStyle(
                              fontSize: 10,
                              color: _obTextSub,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _ObField(
                      controller: _emailCtrl,
                      hint: 'you@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 36),
                  _ObButton(
                    label: "Let's Go  →",
                    enabled: _canProceed && !_saving,
                    loading: _saving,
                    onTap: _save,
                  ),
                  const SizedBox(height: 12),
                  Center(
                      child: Text('You can update these anytime from Profile',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500))),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── 4. LOCATION PERMISSION ──────────────────────────────────────────────────

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});
  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _pingCtrl;
  late Animation<double> _pingAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
        lowerBound: 0.95,
        upperBound: 1.05)
      ..repeat(reverse: true);
    _pingCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _pingAnim = CurvedAnimation(parent: _pingCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pingCtrl.dispose();
    super.dispose();
  }

  Future<void> _allow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trackbus_onboarding_done', true);
    if (!mounted) return;
    final lang = prefs.getString(AppLang.prefKey);
    if (lang == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSelectScreen()),
      );
      return;
    }
    _goHome();
  }

  void _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('trackbus_onboarding_done', true);
    if (!mounted) return;
    final lang = prefs.getString(AppLang.prefKey);
    if (lang == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSelectScreen()),
      );
      return;
    }
    _goHome();
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _obNavy,
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          // ping animation
          SizedBox(
            height: 230,
            width: double.infinity,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _pingAnim,
                builder: (_, __) => Opacity(
                  opacity: (1 - _pingAnim.value).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 + _pingAnim.value * 1.6,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _obAccent.withOpacity(0.6), width: 2)),
                    ),
                  ),
                ),
              ),
              ScaleTransition(
                scale: _pulseCtrl,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _obAccent.withOpacity(0.15)),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _obAccent,
                    boxShadow: [
                      BoxShadow(
                          color: _obAccent.withOpacity(0.5),
                          blurRadius: 24,
                          spreadRadius: 4)
                    ]),
                child: const Icon(Icons.my_location,
                    color: Colors.white, size: 34),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text('Enable Location\nfor Better Experience',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.25)),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
                'TrackBus uses your location to show nearby buses, '
                'estimate arrival times, and make your commute smoother.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white60, fontSize: 14, height: 1.6)),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ObChip(icon: Icons.directions_bus, label: 'Nearest Buses'),
              _ObChip(icon: Icons.access_time, label: 'Live ETAs'),
              _ObChip(icon: Icons.route, label: 'Nearby Stops'),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              _ObButton(
                label: 'Turn On Location',
                enabled: true,
                loading: false,
                onTap: _allow,
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _skip,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Skip for now',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}

// ─── SHARED ONBOARDING WIDGETS ───────────────────────────────────────────────

class _ObButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _ObButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _obAccent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                        color: _obAccent.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6))
                  ]
                : [],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
          ),
        ),
      ),
    );
  }
}

class _ObField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _ObField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _obSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: _obTextMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFFD1D5DB), fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, color: _obBlue, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

class _ObLabel extends StatelessWidget {
  final String text;
  const _ObLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _obTextMain,
          letterSpacing: 0.2));
}

class _ObChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ObChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _obAccent, size: 15),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _ObBusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        width: 120,
        height: 58,
        decoration: BoxDecoration(
          color: _obAccent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: _obAccent.withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Stack(children: [
          Positioned(
            top: 10,
            left: 10,
            child: Row(
              children: List.generate(
                  3,
                  (i) => Container(
                        width: 22,
                        height: 18,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(4)),
                      )),
            ),
          ),
          Positioned(
            right: 8,
            top: 18,
            child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
          ),
        ]),
      ),
      Positioned(bottom: -4, left: 14, child: _ObWheel()),
      Positioned(bottom: -4, right: 14, child: _ObWheel()),
    ]);
  }
}

class _ObWheel extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
            color: _obNavy,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 3)),
      );
}

PageRouteBuilder _obSlideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 320),
  );
}

// ─── TRACKBUS BRAND TEXT ─────────────────────────────────────────────────────
class TrackBusLogoText extends StatelessWidget {
  final double fontSize;
  final Color trackColor;
  final Color busColor;

  const TrackBusLogoText({
    super.key,
    this.fontSize = 22,
    this.trackColor = Colors.white,
    this.busColor = const Color(0xFFF4A024),
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'TRACK',
            style: TextStyle(
              color: trackColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
              letterSpacing: 0.3,
              fontStyle: FontStyle.normal,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          TextSpan(
            text: 'BUS',
            style: TextStyle(
              color: busColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
              letterSpacing: 0.3,
              fontStyle: FontStyle.normal,
              shadows: [
                Shadow(
                  color: busColor.withOpacity(0.4),
                  offset: const Offset(1, 1),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ANIMATED MOVING BUS WIDGET (uses original _ObBusWidget style, slow loop) ──
class MovingBusWidget extends StatefulWidget {
  final double height;

  const MovingBusWidget({
    super.key,
    this.height = 90,
    // ignore unused named params for backward compat
    Color busColor = const Color(0xFFF4A024),
    Color roadColor = const Color(0xFFF4A024),
  });

  @override
  State<MovingBusWidget> createState() => _MovingBusWidgetState();
}

class _MovingBusWidgetState extends State<MovingBusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pos;

  @override
  void initState() {
    super.initState();
    // 8 seconds for a slow, relaxed crossing
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _pos = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          const busWidth = 128.0; // _ObBusWidget width + wheels
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Road line
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  color: _obAccent.withOpacity(0.45),
                ),
              ),
              // Road dashes
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  children: List.generate(
                    16,
                    (i) => Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ),
                ),
              ),
              // Animated original-style bus
              AnimatedBuilder(
                animation: _pos,
                builder: (_, __) {
                  final left = _pos.value * (totalWidth + busWidth) - busWidth;
                  return Positioned(
                    bottom: 18,
                    left: left,
                    child: _ObBusWidget(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
