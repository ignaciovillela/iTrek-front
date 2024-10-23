import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:itrek/config.dart';
import 'package:itrek/db.dart';

const GET = 'GET';
const POST = 'POST';
const PATCH = 'PATCH';
const DELETE = 'DELETE';

Future<http.Response> makeRequest({
  required String method, // GET, POST, PATCH, DELETE
  String? baseUrl,
  required String url,
  Map<String, dynamic>? body, // Cuerpo opcional para POST y PATCH
  bool useToken = true, // Determina si se usa el token
}) async {
  final token = useToken ? await db.get(db.token) : null;

  final headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    if (useToken && token != null) 'Authorization': 'Token $token',
  };
  baseUrl = baseUrl ?? BASE_URL;
  Uri uri = Uri.parse('$baseUrl/$url');

  http.Response response;

  try {
    switch (method.toUpperCase()) {
      case GET:
        response = await http.get(uri, headers: headers);
        break;
      case POST:
        response = await http.post(uri, headers: headers, body: jsonEncode(body));
        break;
      case PATCH:
        response = await http.patch(uri, headers: headers, body: jsonEncode(body));
        break;
      case DELETE:
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Invalid HTTP method: $method');
    }

    // Decodificar el cuerpo de la respuesta con utf8
    response = http.Response(utf8.decode(response.bodyBytes), response.statusCode,
        headers: response.headers);

    return response; // Devolver la respuesta decodificada
  } catch (e) {
    // En caso de error en la solicitud (conexión u otro), retornar una respuesta simulada con código 500
    return http.Response(utf8.encode('{"error": "Error de conexión: $e"}') as String, 500);
  }
}
