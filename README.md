### Flutter Camera & geolocator
Cumpliendo con el requisito de que el mapa sea 100% gratuito (sin necesidad de API Keys de Google Cloud ni tarjetas de crédito), utilizaremos **OpenStreetMap** mediante el paquete **flutter_map**. Para el rastreo en tiempo real usaremos geolocator y para la cámara camera.
# Dependencias necesarias
dependencies:
  flutter:
    sdk: flutter
  flutter_map: ^7.0.2          # Mapas gratuitos (OpenStreetMap)
  latlong2: ^0.9.1             # Manejo de coordenadas (LatLng)
  geolocator: ^13.0.1          # GPS y seguimiento en tiempo real
  camera: ^0.11.0+2            # Acceso nativo a la cámara
  permission_handler: ^11.3.1  # Gestión sencilla de permisos
