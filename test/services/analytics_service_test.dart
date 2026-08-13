import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voikerchat/services/analytics_service.dart';

/// SupabaseClient自体のモックはAnalyticsService内部で使わない
/// (insertRow/currentUserIdの差し替え口で完結する)。コンストラクタが
/// 要求する型を満たすためだけにダミーを渡す。
class DummySupabaseClient extends Mock implements SupabaseClient {}

void main() {
  // LocaleService.resolveLocaleCodeForLogging()がWidgetsBinding.instanceを
  // 参照するため、プレーンなtest()でもバインディング初期化が必要。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService.logEvent', () {
    late DummySupabaseClient dummyClient;

    setUp(() {
      dummyClient = DummySupabaseClient();
    });

    test('insertが失敗しても例外が外に漏れない(fire-and-forget)', () async {
      var insertCalled = false;
      final service = AnalyticsService(
        dummyClient,
        currentUserId: () => 'test-user-id',
        insertRow: (row) async {
          insertCalled = true;
          throw Exception('insert failed');
        },
      );

      // logEvent自体が同期的に例外を投げないこと。
      expect(
        () => service.logEvent(
          event: AnalyticsEvent.sessionStart,
          isPremium: false,
        ),
        returnsNormally,
      );

      // fire-and-forgetの内部Futureが実行される時間を与える(未捕捉例外が
      // あればここでテストランナーがフレームワークエラーとして検出する)。
      await Future<void>.delayed(Duration.zero);
      expect(insertCalled, isTrue);
    });

    test('未認証(currentUserIdがnull)の場合はinsertを呼ばずに静かに終わる', () async {
      var insertCalled = false;
      final service = AnalyticsService(
        dummyClient,
        currentUserId: () => null,
        insertRow: (row) async => insertCalled = true,
      );

      expect(
        () => service.logEvent(
          event: AnalyticsEvent.upsellShown,
          isPremium: false,
          metadata: const {'source': 'quota_limit'},
        ),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);

      expect(insertCalled, isFalse);
    });

    test('insert成功時、event/session_id/is_premium/metadataが正しく渡る', () async {
      Map<String, dynamic>? capturedRow;
      final service = AnalyticsService(
        dummyClient,
        currentUserId: () => 'test-user-id',
        insertRow: (row) async => capturedRow = row,
      );

      service.logEvent(
        event: AnalyticsEvent.upsellClicked,
        sessionId: 'session-123',
        isPremium: true,
        metadata: const {'source': 'locked_scene', 'scene': '9', 'retry': true},
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedRow, isNotNull);
      expect(capturedRow!['user_id'], 'test-user-id');
      expect(capturedRow!['event'], AnalyticsEvent.upsellClicked);
      expect(capturedRow!['session_id'], 'session-123');
      expect(capturedRow!['is_premium'], true);
      expect(capturedRow!['metadata'], {
        'source': 'locked_scene',
        'scene': '9',
        'retry': true,
      });
      expect(capturedRow!.containsKey('scene_id'), isFalse);
    });
  });
}
