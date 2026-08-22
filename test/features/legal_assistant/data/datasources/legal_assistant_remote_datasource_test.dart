import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/network/api_client.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';

class CapturingApiClient extends ApiClient {
  CapturingApiClient({super.customDio});

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
    // Backend yo'li ATAYLAB sozlanadi: shundagina datasource HTTP'ga chiqadi
    // (P0 gate — `ApiClient.hasBaseUrl`). Sozlanmagan holat pastdagi alohida
    // testda tekshiriladi, ya'ni gate ikki tomondan ham isbotlanadi.
    apiClient = CapturingApiClient(
      customDio: Dio(BaseOptions(baseUrl: 'https://backend.test.invalid/v1')),
    );
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

  test('P0: backend manzili sozlanmasa yuridik so\'rov TASHQARIGA CHIQMAYDI',
      () async {
    // Regressiya himoyasi. Ilgari `ApiEndpoints.baseUrl` kodga
    // `https://api.lexhub.uz/v1` deb yozilgan edi, `lexhub.uz` esa DNS'da
    // MAVJUD EMAS. Ya'ni release APK ichida "dangling" host qolgan: domenni
    // istalgan uchinchi shaxs ro'yxatdan o'tkazsa, foydalanuvchining maxfiy
    // yuridik matni (`query_text`) unga POST qilinardi va xato `catch (_) {}`
    // bilan yutilar edi. Endi manzil ataylab berilmasa — chaqiruv YO'Q.
    final unconfigured = CapturingApiClient();
    final ds = LegalAssistantRemoteDataSourceImpl(apiClient: unconfigured);

    final response = await ds.getLegalAdvice(LegalQuery(
      id: 'query_gate_test',
      queryText: "Boshlig'im ishdan bo'shatmoqchi, maoshimni ham bermadi.",
      category: 'Mehnat huquqi',
      createdAt: DateTime.now(),
    ));

    expect(unconfigured.hasBaseUrl, isFalse,
        reason: 'Sozlanmagan client `baseUrl` bo\'sh bo\'lishi kerak');
    expect(unconfigured.lastPostData, isNull,
        reason: 'Sozlanmagan backend\'ga HECH QANDAY so\'rov ketmasligi kerak');
    expect(unconfigured.lastPostPath, isNull);

    // Ayni paytda foydalanuvchi javobsiz QOLMAYDI: 5c grounded engine ishlaydi.
    // Bu mock emas — mahalliy tasdiqlangan qonun bazasidan quriladi (§6).
    expect(response, isNotNull);
    expect(response.relatableSummary, isNotEmpty);
    expect(response.actionableSteps, isNotEmpty);
  });
}
