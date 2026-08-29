/// XATO JURNALI EKRANI (xodimlar uchun diagnostika).
///
/// ── NIMA UCHUN BU EKRAN BOR ──
///
/// `CrashReporter` (`lib/core/telemetry/crash_reporter.dart`) tutilmagan
/// xatolarni `public.client_error_logs` ga yozadi, lekin uni O'QIYDIGAN
/// birorta ham yo'l ilovada YO'Q edi: yozuvlarni ko'rish uchun Supabase
/// Studio'ga kirish kerak bo'lardi. Ya'ni release'dagi crash haqida ma'lumot
/// bor, lekin u xodimga YETIB BORMAYDI.
///
/// ── XAVFSIZLIK CHEGARASI (§14: haqiqat manbasi — server) ──
///
/// Bu ekranning ko'rinishi (`profile_tab_page.dart` dagi rol tekshiruvi)
/// FAQAT UX. Haqiqiy chegara SERVERDA:
///   * `client_error_logs` SELECT policy — `public.is_admin_or_moderator()`,
///     ya'ni xodim bo'lmagan chaqiruvchi APK'ni o'zgartirib bu ekranni
///     zo'rlab ochsa ham BO'SH ro'yxat oladi (INSERT policy o'qishga huquq
///     bermaydi);
///   * `purge_client_error_logs()` — `is_admin_or_moderator()` bo'lmasa
///     42501 "Bu amal uchun ruxsat yo'q.".
///
/// O'LCHANGAN (2026-08-30, `20260830050000_purge_logs_guard_fix.sql` qo'llash
/// paytidagi C1): tozalash funksiyasining gvardi O'LIK edi — u
/// `is_privileged_db_role()` ga qarardi, `SECURITY DEFINER` ichida esa u
/// HAR DOIM TRUE. Ya'ni bu ekran yozilishidan OLDIN har qanday tizimga
/// kirgan foydalanuvchi audit izini o'chira olardi. Tuzatilgandan keyin ayni
/// chaqiruv 42501 oladi (migratsiya ichida isbotlangan).
///
/// ── HALOLLIK CHEGARALARI (§20) ──
///
/// 1. TO'QIMA YOZUV YO'Q. Jurnal bo'sh bo'lsa `crashLogEmpty` chiqadi.
/// 2. TOZALASH SONI SERVERDAN keladi (`RETURNS INTEGER`) — klient "muvaffaqiyat"
///    deb o'zidan son yozmaydi.
/// 3. XATO YASHIRILMAYDI: o'qish yiqilsa sabab `ErrorHandler` orqali
///    matnga aylanadi va ekranda turadi, bo'sh ro'yxat KO'RSATILMAYDI.
/// 4. PII MINIMIZATSIYASI: `user_id` EKRANDA KO'RSATILMAYDI. Ekranning
///    maqsadi — crash'ni tuzatish, foydalanuvchini kuzatish emas. `stack`
///    yig'ilgan holatda turadi (ochiq ekranda tasodifiy ko'rinmasligi uchun).
///
/// ── ARXITEKTURA QARORI ──
///
/// BLoC/UseCase/Repository qatlamlari ATAYLAB QO'SHILMADI: bu yerda domen
/// mantiqi yo'q (bitta `SELECT` + bitta RPC), yagona iste'molchi shu ekran.
/// Bir joyda ishlatiladigan abstraksiya qo'shish kodni ko'paytirib, hech
/// narsani himoya qilmasdi (§16: eng kam kod). Ma'lumot yo'li baribir
/// loyihaning qoidasidan o'tadi: `db()` — `from()` EMAS (retry qulfi).
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serverdan o'qilgan bitta yozuv.
///
/// `message` va `created_at` SHARTLI EMAS — jadvalda ikkisi ham `NOT NULL`.
/// Ular yo'q bo'lsa bu kutilmagan holat va u YUTILMAYDI: `FormatException`
/// xato holatiga chiqadi (bo'sh qiymat ko'rsatish jim yolg'on bo'lardi).
class _LogRow {
  final DateTime createdAt;
  final String kind;
  final String message;
  final String? stack;
  final String? context;
  final String? platform;
  final String? buildMode;

  _LogRow.fromMap(Map<String, dynamic> map)
      : createdAt = DateTime.parse(map['created_at'] as String),
        kind = (map['kind'] as String?) ?? 'unknown',
        message = map['message'] as String,
        stack = map['stack'] as String?,
        context = map['context'] as String?,
        platform = map['platform'] as String?,
        buildMode = map['build_mode'] as String?;
}

class CrashLogPage extends StatefulWidget {
  const CrashLogPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        builder: (_) => const CrashLogPage(),
      );

  @override
  State<CrashLogPage> createState() => _CrashLogPageState();
}

class _CrashLogPageState extends State<CrashLogPage> {
  /// Eng yangi N yozuv. Cheksiz ro'yxat kerak emas: jurnal 30 kundan keyin
  /// tozalanadi va diagnostika uchun oxirgi kesim yetarli.
  static const int _limit = 100;

  late Future<List<_LogRow>> _future;
  bool _purging = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_LogRow>> _load() async {
    final rows = await sl<SupabaseClient>()
        .db('client_error_logs')
        .select('created_at, kind, message, stack, context, platform, '
            'build_mode')
        .order('created_at', ascending: false)
        .limit(_limit);
    return rows.map(_LogRow.fromMap).toList();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _purge() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.crashLogPurgeAction),
        content: Text(l10n.crashLogPurgeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _purging = true);
    try {
      // Son SERVERDAN qaytadi. `p_days` klientda QAT'IY 30 — bu ekranda
      // ixtiyoriy muddat tanlash YO'Q (so'ralmagan imkoniyat qo'shilmaydi).
      final deleted = await sl<SupabaseClient>()
          .rpc<dynamic>('purge_client_error_logs', params: {'p_days': 30});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.crashLogPurgeDone(deleted is int ? deleted : 0)),
      ));
      _reload();
    } catch (error) {
      // JIM YUTISH YO'Q: sabab foydalanuvchiga aytiladi. Ruxsat yo'q bo'lsa
      // server 42501 beradi va u `FailureCode.forbidden` ga tushadi.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(failureText(l10n, ErrorHandler.handle(error))),
      ));
    } finally {
      if (mounted) setState(() => _purging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.crashLogTitle),
        actions: [
          if (_purging)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: l10n.crashLogPurgeAction,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _purge,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<List<_LogRow>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorBody(
                message: failureText(l10n, ErrorHandler.handle(snapshot.error)),
                onRetry: _reload,
              );
            }
            final rows = snapshot.data ?? const <_LogRow>[];
            if (rows.isEmpty) {
              return ListView(
                children: [
                  const Gap(AppSpacing.xl),
                  Center(child: Text(l10n.crashLogEmpty)),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) => _LogTile(row: rows[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Icon(Icons.error_outline,
            color: AppTone.warning.on(isDark), size: 32),
        const Gap(AppSpacing.md),
        Text(message, textAlign: TextAlign.center),
        const Gap(AppSpacing.md),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: Text(context.l10n.actionRetry),
          ),
        ),
      ],
    );
  }
}

/// Bitta yozuv. `stack` YIG'ILGAN holatda: u uzun va ekranda tasodifiy
/// ko'rinishi kerak emas.
class _LogTile extends StatelessWidget {
  final _LogRow row;

  const _LogTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stack = row.stack;
    // `kind`, `platform`, `build_mode` — SERVER MA'LUMOTI, tarjima
    // QILINMAYDI (§16: backend qiymatlari kontrakt).
    final meta = [
      _formatTime(row.createdAt),
      row.kind,
      if (row.platform != null) row.platform!,
      if (row.buildMode != null) row.buildMode!,
    ].join(' • ');

    return ExpansionTile(
      title: Text(
        row.message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(meta, style: const TextStyle(fontSize: 11)),
      childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      children: [
        if (row.context != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(row.context!, style: const TextStyle(fontSize: 12)),
          ),
        if (stack != null) ...[
          const Gap(AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.crashLogStackLabel,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const Gap(AppSpacing.xs),
          SelectableText(
            stack,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ],
    );
  }

  /// Lokaldan mustaqil qisqa sana+vaqt: kerak bo'lgani xatoning YOSHI.
  static String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:'
        '${two(local.minute)}';
  }
}
