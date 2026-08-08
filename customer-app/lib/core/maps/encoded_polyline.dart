List<({double latitude, double longitude})> decodePolyline(String encoded) {
  final points = <({double latitude, double longitude})>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  while (index < encoded.length) {
    final lat = _decodeCoordinate(encoded, index);
    index = lat.nextIndex;
    latitude += lat.delta;
    if (index >= encoded.length) break;
    final lon = _decodeCoordinate(encoded, index);
    index = lon.nextIndex;
    longitude += lon.delta;
    points.add((latitude: latitude / 1e5, longitude: longitude / 1e5));
  }
  return points;
}

({int delta, int nextIndex}) _decodeCoordinate(String encoded, int start) {
  var result = 0;
  var shift = 0;
  var index = start;
  int byte;
  do {
    if (index >= encoded.length) return (delta: 0, nextIndex: index);
    byte = encoded.codeUnitAt(index++) - 63;
    result |= (byte & 0x1f) << shift;
    shift += 5;
  } while (byte >= 0x20);
  return (
    delta: (result & 1) == 1 ? ~(result >> 1) : result >> 1,
    nextIndex: index,
  );
}
