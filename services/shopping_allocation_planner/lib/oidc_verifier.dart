import 'dart:convert';

import 'package:http/http.dart' as http;

abstract interface class OidcVerifier {
  Future<void> verify(String authorizationHeader);
}

final class OidcVerificationException implements Exception {
  const OidcVerificationException();
}

final class GoogleOidcVerifier implements OidcVerifier {
  GoogleOidcVerifier({
    required this.audience,
    required this.callerServiceAccount,
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory GoogleOidcVerifier.fromEnvironment(Map<String, String> environment) {
    final audience = environment['PLANNER_AUDIENCE'];
    final callerServiceAccount = environment['PLANNER_CALLER_SERVICE_ACCOUNT'];
    if (audience == null ||
        audience.isEmpty ||
        callerServiceAccount == null ||
        callerServiceAccount.isEmpty) {
      throw StateError(
        'PLANNER_AUDIENCE and PLANNER_CALLER_SERVICE_ACCOUNT are required',
      );
    }
    return GoogleOidcVerifier(
      audience: audience,
      callerServiceAccount: callerServiceAccount,
    );
  }

  final String audience;
  final String callerServiceAccount;
  final http.Client _client;

  @override
  Future<void> verify(String authorizationHeader) async {
    final token = _bearerToken(authorizationHeader);
    final response = await _client.get(
      Uri.https('oauth2.googleapis.com', '/tokeninfo', {'id_token': token}),
    );
    if (response.statusCode != 200) throw const OidcVerificationException();
    final claims = _claims(jsonDecode(response.body));
    final issuer = claims['iss'];
    final verified = claims['email_verified'];
    if (claims['aud'] != audience ||
        (issuer != 'https://accounts.google.com' &&
            issuer != 'accounts.google.com') ||
        claims['email'] != callerServiceAccount ||
        verified != 'true') {
      throw const OidcVerificationException();
    }
  }
}

final class LocalIntegrationOidcVerifier implements OidcVerifier {
  const LocalIntegrationOidcVerifier(this.token);

  factory LocalIntegrationOidcVerifier.fromEnvironment(
    Map<String, String> environment,
  ) {
    final enabled = environment['LOCAL_PLANNER_INTEGRATION_TEST'];
    final token = environment['LOCAL_PLANNER_OIDC_TOKEN'];
    if (enabled != 'true' ||
        environment['FUNCTIONS_EMULATOR'] != 'true' ||
        token == null ||
        token.isEmpty) {
      throw StateError('Local planner integration identity is required');
    }
    return LocalIntegrationOidcVerifier(token);
  }

  final String token;

  @override
  Future<void> verify(String authorizationHeader) async {
    if (_bearerToken(authorizationHeader) != token) {
      throw const OidcVerificationException();
    }
  }
}

String _bearerToken(String value) {
  const prefix = 'Bearer ';
  if (!value.startsWith(prefix) || value.length == prefix.length) {
    throw const OidcVerificationException();
  }
  return value.substring(prefix.length);
}

Map<String, Object?> _claims(Object? value) {
  if (value is! Map) throw const OidcVerificationException();
  return Map<String, Object?>.from(value);
}
