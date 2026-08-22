import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/network/api_client.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';

class CapturingApiClient extends ApiClient {
  Map<String, dynamic>? lastPostData;
  String? lastPostPath;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastPostPath = path;
    if (data is Map<String, dynamic>) {
      lastPostData = data;
    }
    // Return mock 200 response
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {
        'id': 'resp_test_1',
        'query_id': 'q_test_1',
        'relatable_summary': 'Tahlil yakunlandi.',
        'actionable_steps': ['Qadam 1'],
        'legal_basis': [
          {
            'law_name': 'Mehnat kodeksi',
            'article_number': '161-modda',
            'article_title': 'Mehnat shartnomasi',
            'article_text': 'Qonuniy qoida',
            'lex_url': 'https://lex.uz',
          }
        ],
        'risk_assessment': {
          'level': 'low',
          'summary': 'Xavf past',
        },
        'created_at': DateTime.now().toIso8601String(),
      } as T,
    );
  }
}

void main() {
  late CapturingApiClient apiClient;
  late LegalAssistantRemoteDataSourceImpl dataSource;

  setUp(() {
    apiClient = CapturingApiClient();
    dataSource = LegalAssistantRemoteDataSourceImpl(apiClient: apiClient);
  });

  test('ensures outbound AI query payload has ALL PII sanitized and no raw leak', () async {
    const rawSensitiveQuery =
        "Mening telefonim +998901234567, pasportim AA 7654321, kartam 8600 1234 5678 9012. Boshlig'im ishdan bo'shatmoqchi.";

    final query = LegalQuery(
      id: 'query_p0_test',
      queryText: rawSensitiveQuery,
      category: 'Mehnat huquqi',
      createdAt: DateTime.now(),
    );

    final response = await dataSource.getLegalAdvice(query);

    expect(response, isNotNull);
    expect(apiClient.lastPostData, isNotNull);

    final payload = apiClient.lastPostData!;
    final queryTextInPayload = payload['query_text'] as String;

    // Assert that raw PII was stripped from outbound payload
    expect(queryTextInPayload, isNot(contains('+998901234567')));
    expect(queryTextInPayload, isNot(contains('AA 7654321')));
    expect(queryTextInPayload, isNot(contains('8600 1234 5678 9012')));

    // Assert that safe placeholder masks were placed
    expect(queryTextInPayload, contains('[Telefon yashirildi]'));
    expect(queryTextInPayload, contains('[Pasport yashirildi]'));
    expect(queryTextInPayload, contains('[Karta raqami yashirildi]'));
  });
}
