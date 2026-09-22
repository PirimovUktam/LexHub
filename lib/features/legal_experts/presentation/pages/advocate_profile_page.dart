import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/app_page_body.dart';
import 'package:lexhub/features/auth/presentation/pages/login_page.dart';
import 'package:lexhub/features/consultations/presentation/pages/book_consultation_page.dart';
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/advocate_profile_repository.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/advocate_inbox_page.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/advocate_profile_editor_page.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/advocate_avatar.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/advocate_profile_actions.dart';
import 'package:url_launcher/url_launcher.dart';

/// One professional profile, rendered for the visitor or its server-confirmed
/// owner. Private account profile fields are never used as public fallbacks.
class AdvocateProfilePage extends StatefulWidget {
  const AdvocateProfilePage(
      {super.key, this.expertId, this.repository, this.bookingExpert});
  final String? expertId;
  final AdvocateProfileRepository? repository;
  final LegalExpert? bookingExpert;

  @override
  State<AdvocateProfilePage> createState() => _AdvocateProfilePageState();
}

class _AdvocateProfilePageState extends State<AdvocateProfilePage> {
  late final AdvocateProfileRepository _repository = widget.repository ?? sl();
  AdvocateProfile? _profile;
  Failure? _failure;
  bool _loading = true;
  bool _busy = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _failure = null;
      });
    }
    try {
      final id = widget.expertId;
      final Either<Failure, AdvocateProfile?> result = id == null
          ? await _repository.getMyProfile()
          : await _repository.getProfile(id);
      if (!mounted) return;
      result.fold((f) => _failure = f, (p) => _profile = p);
    } catch (_) {
      _failure = const ServerFailure(message: '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.of(context).push<AdvocateProfile>(
      MaterialPageRoute(
          builder: (_) => AdvocateProfileEditorPage(
              repository: _repository, profile: _profile)),
    );
    if (!mounted || saved == null) return;
    _notify(context.l10n.advocateSaved);
    await _load();
  }

  Future<void> _edit(Future<bool> Function() operation,
      {bool request = false}) async {
    if (_busy) return;
    final saved = await operation();
    if (!mounted || !saved) return;
    _notify(request ? context.l10n.advocateSent : context.l10n.advocateSaved);
    await _load();
  }

  Future<void> _delete<T>(
      Future<Either<Failure, T>> Function() operation) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(l.advocateDeleteConfirm),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.profileCancel)),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.advocateDelete)),
              ],
            ));
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      final result = await operation();
      if (!mounted) return;
      result.fold((f) => _notify(failureMessageFor(l, f.code)),
          (_) => _notify(l.advocateDeleted));
      if (result.isRight()) await _load();
    } catch (_) {
      _notify(l.errorServer);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(AdvocateDocument document) async {
    final result = await _repository.getSignedUrl(document.objectPath);
    if (!mounted) return;
    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      _notify(failureMessageFor(context.l10n, failure.code));
      return;
    }
    final url = result.fold<String?>((_) => null, (u) => u);
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      _notify(context.l10n.errorValidation);
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        _notify(context.l10n.errorUnexpected);
      }
    } catch (_) {
      if (mounted) _notify(context.l10n.errorUnexpected);
    }
  }

  Widget _section(String title, List<Widget> children, {VoidCallback? add}) =>
      Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleMedium)),
                  if (add != null)
                    IconButton(
                        onPressed: _busy ? null : add,
                        tooltip: context.l10n.advocateAdd,
                        icon: const Icon(Icons.add)),
                ]),
                const SizedBox(height: AppSpacing.md),
                if (children.isEmpty)
                  Text(context.l10n.advocateEmpty)
                else
                  ...children,
              ],
            )),
      );

  Widget _entry(
          {required String title,
          String? subtitle,
          VoidCallback? edit,
          VoidCallback? delete,
          Widget? footer}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child:
                    Text(title, style: Theme.of(context).textTheme.titleSmall)),
            if (edit != null)
              IconButton(
                  onPressed: _busy ? null : edit,
                  tooltip: context.l10n.advocateEdit,
                  icon: const Icon(Icons.edit_outlined)),
            if (delete != null)
              IconButton(
                  onPressed: _busy ? null : delete,
                  tooltip: context.l10n.advocateDelete,
                  icon: const Icon(Icons.delete_outline)),
          ]),
          if (subtitle != null && subtitle.isNotEmpty) Text(subtitle),
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            footer
          ],
        ]),
      );

  Widget _overview(AdvocateProfile p, AdvocateProfileActions a) {
    final l = context.l10n;
    final date = DateFormat.yMMMd(l.localeName);
    return Column(children: [
      _section(l.profileBio, [if (p.bio.isNotEmpty) Text(p.bio)]),
      _section(l.advocateSpecializations, [
        if (p.specializations.isNotEmpty)
          Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children:
                  p.specializations.map((s) => Chip(label: Text(s))).toList())
      ]),
      _section(l.advocateWorkplace, [
        if (p.workplace.isNotEmpty) _entry(title: p.workplace),
        if (p.address.isNotEmpty)
          _entry(title: l.profileAddress, subtitle: p.address),
        if (p.publicPhone.isNotEmpty)
          _entry(title: l.advocatePublicPhone, subtitle: p.publicPhone),
        if (p.publicEmail.isNotEmpty)
          _entry(title: l.advocatePublicEmail, subtitle: p.publicEmail),
      ]),
      _section(l.advocateLanguages,
          [if (p.languages.isNotEmpty) Text(p.languages.join(' · '))]),
      _section(
          l.advocateExperience,
          [
            for (final e in p.experience)
              _entry(
                  title: e.position,
                  subtitle: [
                    e.organization,
                    '${date.format(e.startDate)} — ${e.endDate == null ? l.advocatePresent : date.format(e.endDate!)}',
                    if (e.description.isNotEmpty) e.description,
                  ].join('\n'),
                  edit: p.isOwner ? () => _edit(() => a.experience(e)) : null,
                  delete: p.isOwner
                      ? () => _delete(() => _repository.deleteExperience(e.id))
                      : null)
          ],
          add: p.isOwner ? () => _edit(a.experience) : null),
      _section(
          l.advocateEducation,
          [
            for (final e in p.education)
              _entry(
                  title: e.institution,
                  subtitle:
                      '${e.qualification}\n${e.startYear} — ${e.endYear?.toString() ?? l.advocatePresent}',
                  edit: p.isOwner ? () => _edit(() => a.education(e)) : null,
                  delete: p.isOwner
                      ? () => _delete(() => _repository.deleteEducation(e.id))
                      : null)
          ],
          add: p.isOwner ? () => _edit(a.education) : null),
      _section(
          l.advocateHours,
          [
            Text(l.advocateTimeZone),
            const SizedBox(height: AppSpacing.md),
            if (p.workingHours.isEmpty) Text(l.advocateEmpty),
            for (final h in p.workingHours)
              _entry(
                  title: advocateWeekdays(context)[h.weekday.toString()] ??
                      l.advocateWeekday,
                  subtitle: h.isClosed
                      ? l.advocateClosed
                      : '${h.opensAt} – ${h.closesAt}',
                  edit: p.isOwner ? () => _edit(() => a.hours(h)) : null,
                  delete: p.isOwner
                      ? () =>
                          _delete(() => _repository.deleteWorkingHours(h.id))
                      : null)
          ],
          add: p.isOwner ? () => _edit(a.hours) : null),
    ]);
  }

  Widget _services(AdvocateProfile p, AdvocateProfileActions a) {
    final l = context.l10n;
    final number = NumberFormat.decimalPattern(l.localeName);
    return _section(
        l.advocateServices,
        [
          for (final s in p.services)
            _entry(
                title: s.title,
                subtitle: [
                  s.description,
                  s.priceUzs == null
                      ? l.advocatePriceDiscuss
                      : l.advocatePriceValue(number.format(s.priceUzs)),
                  advocateDeliveryLabels(context)[s.deliveryMode] ?? '',
                  if (s.durationMinutes case final int minutes)
                    l.advocateDurationValue(minutes),
                  if (!s.isActive) l.advocateInactive
                ].where((s) => s.isNotEmpty).join('\n'),
                edit: p.isOwner ? () => _edit(() => a.service(s)) : null,
                delete: p.isOwner
                    ? () => _delete(() => _repository.deleteService(s.id))
                    : null,
                footer: !p.isOwner && s.isActive
                    ? FilledButton.tonalIcon(
                        onPressed: p.acceptingClients
                            ? () => _edit(() => a.request(service: s),
                                request: true)
                            : null,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(l.advocateConsult))
                    : null)
        ],
        add: p.isOwner ? () => _edit(a.service) : null);
  }

  Widget _reviews(AdvocateProfile p, AdvocateProfileActions a) {
    final l = context.l10n;
    return _section(l.advocateReviews, [
      if (p.reviews.isEmpty) Text(l.advocateNoReviews),
      for (final r in p.reviews)
        _entry(
            title:
                '${r.rating}/5 · ${DateFormat.yMMMd(l.localeName).format(r.createdAt)}',
            subtitle: r.comment),
      if (p.eligibleConsultationIds.isNotEmpty)
        OutlinedButton.icon(
            onPressed: () => _edit(a.review),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(l.advocateReview)),
    ]);
  }

  Widget _documents(AdvocateProfile p, AdvocateProfileActions a) {
    final l = context.l10n;
    return _section(
        l.advocateDocuments,
        [
          Text(l.advocateDocumentDisclosure),
          const SizedBox(height: AppSpacing.md),
          if (p.documents.isEmpty) Text(l.advocateEmpty),
          if (p.licenseNumber case final String license)
            _entry(title: l.advocateLicense, subtitle: license),
          for (final d in p.documents)
            _entry(
                title: d.title,
                subtitle: p.isOwner
                    ? (d.isPublic
                        ? l.advocateDocumentPublic
                        : l.advocateDocumentPrivate)
                    : null,
                edit: p.isOwner ? () => _edit(() => a.editDocument(d)) : null,
                delete: p.isOwner
                    ? () => _delete(() => _repository.deleteDocument(d))
                    : null,
                footer: OutlinedButton.icon(
                    onPressed: () => _open(d),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(l.advocateOpenDocument))),
        ],
        add: p.isOwner ? () => _edit(a.document) : null);
  }

  Widget _hero(AdvocateProfile p, AdvocateProfileActions a) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
            child: AdvocateAvatar(repository: _repository, path: p.avatarPath)),
        const SizedBox(height: AppSpacing.lg),
        Text(p.fullName.isEmpty ? l.expertNameUnknown : p.fullName,
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(p.verified ? Icons.verified_outlined : Icons.pending_outlined,
              size: AppIconSize.sm, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
              child:
                  Text(p.verified ? l.advocateVerified : l.advocateUnverified)),
        ]),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              Chip(label: Text(l.advocateExperienceCount(p.experienceYears))),
              Chip(
                  label:
                      Text(l.advocateConsultationCount(p.consultationsCount))),
              Chip(
                  label: Text(p.rating == null || p.reviewsCount == 0
                      ? l.advocateReviewCount(p.reviewsCount)
                      : '${p.rating?.toStringAsFixed(1)}/5 · ${l.advocateReviewCount(p.reviewsCount)}')),
            ]),
        const SizedBox(height: AppSpacing.md),
        Text(p.acceptingClients ? l.advocateAccepting : l.advocateUnavailable,
            textAlign: TextAlign.center),
        if (p.isOwner && !p.isPublished) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l.advocateDraft, textAlign: TextAlign.center)
        ],
        const SizedBox(height: AppSpacing.lg),
        if (p.isOwner)
          FilledButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.profileEditDetails))
        else ...[
          FilledButton.icon(
              onPressed: p.acceptingClients
                  ? () => _edit(() => a.request(), request: true)
                  : null,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(l.advocateConsult)),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
              onPressed: p.acceptingClients
                  ? () => _edit(() => a.request(message: true), request: true)
                  : null,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(l.advocateMessage)),
          if (widget.bookingExpert case final LegalExpert expert) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
                onPressed: () => BookConsultationPage.show(context, expert),
                icon: const Icon(Icons.event_available_outlined),
                label: Text(l.expertBookConsultation)),
          ],
        ],
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = _profile;
    final f = _failure;
    return Scaffold(
      appBar: AppBar(title: Text(l.advocateProfile), actions: [
        IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AdvocateInboxPage(repository: _repository))),
            tooltip: l.advocateInbox,
            icon: const Icon(Icons.forum_outlined)),
        IconButton(
            onPressed: _loading ? null : _load,
            tooltip: l.advocateRefresh,
            icon: const Icon(Icons.refresh)),
      ]),
      body: AppPageBody(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : f != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(failureMessageFor(l, f.code),
                                textAlign: TextAlign.center),
                            const SizedBox(height: AppSpacing.md),
                            if (f.code == FailureCode.unauthorized)
                              FilledButton(
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => const LoginPage()));
                                    if (mounted) await _load();
                                  },
                                  child: Text(l.authGoToLogin))
                            else
                              OutlinedButton(
                                  onPressed: _load,
                                  child: Text(l.advocateRefresh)),
                          ])))
                  : p == null
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_circle_outlined,
                                        size: AppIconSize.empty),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(l.advocateCreateHint),
                                    const SizedBox(height: AppSpacing.lg),
                                    FilledButton(
                                        onPressed: _editProfile,
                                        child: Text(l.advocateCreate)),
                                  ])))
                      : Builder(builder: (context) {
                          final actions =
                              AdvocateProfileActions(context, _repository, p);
                          final tabs = [
                            l.advocateOverview,
                            l.advocateServices,
                            l.advocateReviews,
                            l.advocateDocuments
                          ];
                          return ListView(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              children: [
                                _hero(p, actions),
                                const SizedBox(height: AppSpacing.lg),
                                SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(children: [
                                      for (var i = 0; i < tabs.length; i++)
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                right: AppSpacing.sm),
                                            child: ChoiceChip(
                                                key:
                                                    ValueKey('advocate_tab_$i'),
                                                label: Text(tabs[i]),
                                                selected: _tab == i,
                                                onSelected: (_) =>
                                                    setState(() => _tab = i))),
                                    ])),
                                const SizedBox(height: AppSpacing.lg),
                                switch (_tab) {
                                  1 => _services(p, actions),
                                  2 => _reviews(p, actions),
                                  3 => _documents(p, actions),
                                  _ => _overview(p, actions)
                                },
                                const SizedBox(height: AppSpacing.bottomSafe),
                              ]);
                        })),
    );
  }
}
