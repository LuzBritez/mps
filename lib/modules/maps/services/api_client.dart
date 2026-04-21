import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente HTTP para PostgREST (reemplaza SupabaseClient).
///
/// PostgREST expone la base de datos PostgreSQL como una API REST.
/// URL por defecto: http://10.0.2.2:3000 (emulador Android → host)
/// Para dispositivo físico: usar la IP de la máquina en la red local.
class ApiClient {
  final String baseUrl;
  final Map<String, String> _headers;

  ApiClient({
    String? baseUrl,
    String? jwtToken,
  })  : baseUrl = baseUrl ?? const String.fromEnvironment(
          'API_URL',
          defaultValue: 'http://10.0.2.2:3000',
        ),
        _headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (jwtToken != null) 'Authorization': 'Bearer $jwtToken',
          // Retornar la fila insertada/actualizada
          'Prefer': 'return=representation',
        };

  // ── SELECT ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, String>? filters,
    String? order,
    int? limit,
  }) async {
    final uri = _buildUri(table, filters: filters, order: order, limit: limit);
    final response = await http.get(uri, headers: _headers);
    _checkStatus(response);
    return List<Map<String, dynamic>>.from(jsonDecode(response.body) as List);
  }

  // ── INSERT ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final uri = Uri.parse('$baseUrl/$table');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkStatus(response);
    final list = jsonDecode(response.body) as List;
    return list.first as Map<String, dynamic>;
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, String> filters,
  }) async {
    final uri = _buildUri(table, filters: filters);
    final response = await http.patch(
      uri,
      headers: _headers,
      body: jsonEncode(data),
    );
    _checkStatus(response);
    final list = jsonDecode(response.body) as List;
    if (list.isEmpty) throw ApiException('No rows updated in $table');
    return list.first as Map<String, dynamic>;
  }

  // ── UPSERT ────────────────────────────────────────────────────────────────

  Future<void> upsert(String table, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/$table');
    final response = await http.post(
      uri,
      headers: {..._headers, 'Prefer': 'resolution=merge-duplicates,return=minimal'},
      body: jsonEncode(data),
    );
    _checkStatus(response);
  }

  // ── RPC ───────────────────────────────────────────────────────────────────

  Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    final uri = Uri.parse('$baseUrl/rpc/$fn');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(params ?? {}),
    );
    _checkStatus(response);
    return jsonDecode(response.body);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _buildUri(
    String table, {
    Map<String, String>? filters,
    String? order,
    int? limit,
  }) {
    final params = <String, String>{};
    if (filters != null) params.addAll(filters);
    if (order != null) params['order'] = order;
    if (limit != null) params['limit'] = limit.toString();
    return Uri.parse('$baseUrl/$table').replace(queryParameters: params.isEmpty ? null : params);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(
        'HTTP ${response.statusCode} on ${response.request?.url}: ${response.body}',
      );
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

/// Instancia global del cliente API.
/// Inicializar en main() con la URL correcta.
ApiClient apiClient = ApiClient();
