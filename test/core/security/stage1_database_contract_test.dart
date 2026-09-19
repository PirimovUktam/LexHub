// P1-06/P1-07/P1-09 and P1-01 SQL artifact contracts, measured 2026-09-19.
// These checks do NOT prove deployment. Real local SQL/RLS regression cases:
// node tool/database/verify_stage1_db.mjs (isolated PostgreSQL/PGlite only).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';

String code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('--'))
    .join('\n');

void main() {
  const candidate =
      'supabase/migrations/20260919001000_stage1_authorization_and_booking.sql';
  const legal =
      'supabase/migrations/20260919002000_reviewed_legal_excerpts_and_deadlines.sql';

  test('stage 1 migrations have explicit transaction boundaries', () {
    for (final path in [candidate, legal]) {
      final sql = code(path);
      expect(sql.trimLeft(), startsWith('BEGIN;'));
      expect(sql.trimRight(), endsWith('COMMIT;'));
    }
  });

  test('answer/expert guards inspect the invoking role on INSERT and UPDATE',
      () {
    final sql = code(candidate);
    expect(RegExp('LANGUAGE plpgsql SECURITY INVOKER').allMatches(sql).length, 2);
    expect(sql, contains('BEFORE INSERT OR UPDATE ON public.answers'));
    expect(sql, contains('BEFORE INSERT OR UPDATE ON public.expert_profiles'));
    expect(sql, isNot(contains('session_user')));
    expect(sql, contains('NEW.user_id IS DISTINCT FROM v_actor'));
    expect(sql, contains('NEW.verified_at IS NOT NULL'));
    expect(sql, contains('NEW.rating IS NOT NULL'));
    expect(sql, contains('NEW.reviews_count IS DISTINCT FROM 0'));
    expect(sql, contains("USING ERRCODE = '42501'"));
  });

  test('legacy permissive policies are intersected; acceptance stays available',
      () {
    final sql = code(candidate);
    expect(RegExp('AS RESTRICTIVE').allMatches(sql).length, 2);
    expect(sql, contains("ARRAY['is_accepted', 'updated_at']"));
    expect(sql, contains('NEW.question_id IS DISTINCT FROM OLD.question_id'));
    expect(sql, contains('auth.uid() IS DISTINCT FROM v_question_owner'));
    expect(sql, contains('UPDATE public.answers SET is_accepted = false'));
    expect(sql, contains("SET status = 'answered'"));
  });

  test('booking requires approved profile and records the actual mandatory fee',
      () {
    final sql = code(candidate);
    expect(sql, contains('ep.rejected_at IS NULL AND p.is_verified = TRUE'));
    expect(sql, contains("p.role::text IN ('verified_expert', 'lawyer',"));
    expect(sql, contains('v_price_uzs := v_expert_record.consultation_fee'));
    expect(sql,
        contains(RegExp(r'duration_minutes,\s+fee,\s+price_amount_tiyin')));
    expect(
        sql, contains(RegExp(r'v_duration,\s+v_price_uzs,\s+v_price_tiyin')));
    expect(sql, isNot(contains('150000')));
    expect(sql, contains('FROM PUBLIC, anon, authenticated'));
  });

  test('canonical empty bootstrap includes every migration in sorted order',
      () {
    final names = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .map((file) => file.uri.pathSegments.last)
        .toList()
      ..sort();
    expect(names.length, greaterThanOrEqualTo(36));
    final bootstrap = File('supabase/bootstrap/rebuild.sql').readAsStringSync();
    final includes = RegExp(r'^\\ir ../migrations/([^\r\n]+)', multiLine: true)
        .allMatches(bootstrap)
        .map((match) => match.group(1))
        .toList();
    expect(includes, names);
    expect(bootstrap, contains('inet_server_addr()'));
    expect(
        bootstrap, contains('Bootstrap requires an empty application schema'));
    expect(bootstrap, contains('\\ir replay_prerequisites.sql'));
    final prerequisites = code('supabase/bootstrap/replay_prerequisites.sql');
    expect(prerequisites, contains('CREATE TABLE public.categories'));
    expect(prerequisites, contains('CREATE TABLE public.official_sources'));
    expect(prerequisites, contains('ADD COLUMN specialization TEXT'));
    expect(prerequisites, contains('ALTER COLUMN category_id TYPE UUID'));
  });

  test('historical INSERT policy assertion uses WITH CHECK during bootstrap',
      () {
    final sql = code(
      'supabase/migrations/20260830100000_rls_never_enabled_tables.sql',
    );
    expect(sql,
        contains("CASE WHEN cmd = 'INSERT' THEN with_check ELSE qual END"));
  });

  test('reviewed server text matches all four corrected client excerpts', () {
    final sql = code(legal);
    final chunks = UzbekLegalKnowledgeBase.verifiedLawChunks.where((chunk) => [
          'const_art_27',
          'const_art_28',
          'const_art_29',
          'labor_art_560'
        ].contains(chunk.chunkId));
    expect(chunks.length, 4);
    for (final chunk in chunks) {
      expect(sql, contains(chunk.content.replaceAll("'", "''")));
      expect(sql, contains(chunk.lexUrl));
    }
    expect(sql, contains('Unexpected legal excerpt drift'));
    expect(sql, contains('INTO STRICT v_service'));
    expect(sql, contains('INTO STRICT v_step'));
    expect(sql, contains('THEN NULL ELSE embedding END'));
    expect(sql, isNot(contains('last_verified_at =')));
  });
}
