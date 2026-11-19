import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GPS y Cámara Gratis',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Mapa en Tiempo Real' : 'Cámara'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          MapTab(),
          CameraTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Geolocalización',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Cámara',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PESTAÑA 1: MAPA GRATUITO (OPENSTREETMAP) + RASTREO EN TIEMPO REAL
// ============================================================================
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentPosition;
  String _statusMessage = 'Iniciando ubicación...';
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }

  Future<void> _initLocationTracking() async {
    try {
      setState(() => _statusMessage = 'Verificando permisos de ubicación...');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _statusMessage = 'Permiso de ubicación denegado.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _statusMessage =
            'Permiso bloqueado. Haz clic en el ícono junto a la URL en Chrome y permite la Ubicación.');
        return;
      }

      setState(() => _statusMessage = 'Obteniendo coordenadas...');

      // 1. Obtener posición inicial rápida (evita bloqueo en PC/Web)
      final initialPos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(initialPos.latitude, initialPos.longitude);
      });

      // 2. Iniciar escucha de movimiento continuo
      final streamSettings = LocationSettings(
        accuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        distanceFilter: kIsWeb ? 0 : 2,
      );

      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(locationSettings: streamSettings)
          .listen((Position position) {
        if (!mounted) return;
        final newLatLng = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentPosition = newLatLng;
        });

        if (_followUser) {
          _mapController.move(newLatLng, 17.0);
        }
      }, onError: (e) {
        debugPrint('Error en stream GPS: $e');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage =
          'No se pudo obtener ubicación ($e).\nVerifica que la ubicación esté activa en Windows y Chrome.');
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_statusMessage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initLocationTracking,
                child: const Text('Reintentar'),
              )
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition!,
            initialZoom: 17.0,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && _followUser) {
                setState(() => _followUser = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ejemplo.mi_app_gps_camara',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition!,
                  width: 50,
                  height: 50,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blueAccent,
                    size: 36,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)} | '
                'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: () {
              setState(() => _followUser = true);
              _mapController.move(_currentPosition!, 17.0);
            },
            backgroundColor: _followUser ? Colors.teal : Colors.grey[300],
            child: Icon(
              Icons.gps_fixed,
              color: _followUser ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PESTAÑA 2: ACTIVACIÓN Y CAMBIO DE CÁMARA
// ============================================================================
class CameraTab extends StatefulWidget {
  const CameraTab({super.key});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  String _statusMessage = 'Presiona el botón para activar la cámara';

  Future<void> _initCameraController(int cameraIndex) async {
    // Liberamos el controlador anterior antes de iniciar el nuevo
    final previousController = _controller;
    setState(() {
      _isCameraInitialized = false;
      _controller = null;
    });
    await previousController?.dispose();

    final newController = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await newController.initialize();
      if (!mounted) {
        await newController.dispose();
        return;
      }
      setState(() {
        _controller = newController;
        _selectedCameraIndex = cameraIndex;
        _isCameraInitialized = true;
      });
    } catch (e) {
      setState(() => _statusMessage = 'Error al iniciar cámara: $e');
    }
  }

  Future<void> _startCamera() async {
    try {

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _statusMessage = 'No se encontraron cámaras en este dispositivo.');
        return;
      }

      await _initCameraController(_selectedCameraIndex);
    } catch (e) {
      setState(() => _statusMessage = 'Error al obtener cámaras: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo hay una cámara disponible en este dispositivo')),
      );
      return;
    }

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCameraController(nextIndex);
  }

  Future<void> _stopCamera() async {
    await _controller?.dispose();
    setState(() {
      _controller = null;
      _isCameraInitialized = false;
      _statusMessage = 'Cámara apagada';
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_statusMessage, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _startCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Activar Cámara'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CameraPreview(_controller!),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton.icon(
                onPressed: _stopCamera,
                icon: const Icon(Icons.stop),
                label: const Text('Apagar'),
              ),
              if (_cameras.length > 1)
                FilledButton.tonalIcon(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.cameraswitch),
                  label: const Text('Cambiar'),
                ),
              FilledButton.icon(
                onPressed: () async {
                  final image = await _controller!.takePicture();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Foto guardada en: ${image.path}')),
                  );
                },
                icon: const Icon(Icons.camera),
                label: const Text('Capturar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}