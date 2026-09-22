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
import 'package:lexhub/features/legal_experts/domain/entities/advocate_profile.dart';
import 'package:lexhub/features/legal_experts/domain/repositories/advocate_profile_repository.dart';

String _status(BuildContext context, String status) => switch (status) {
      'pending' => context.l10n.advocateRequestPending,
      'accepted' => context.l10n.advocateRequestAccepted,
      'declined' => context.l10n.advocateRequestDeclined,
      'cancelled' => context.l10n.advocateRequestCancelled,
      'completed' => context.l10n.advocateRequestCompleted,
      _ => context.l10n.advocateRequestClosed,
    };

class AdvocateInboxPage extends StatefulWidget {
  const AdvocateInboxPage({super.key, this.repository});
  final AdvocateProfileRepository? repository;

  @override
  State<AdvocateInboxPage> createState() => _AdvocateInboxPageState();
}

class _AdvocateInboxPageState extends State<AdvocateInboxPage> {
  late final AdvocateProfileRepository _repository = widget.repository ?? sl();
  List<AdvocateRequest> _requests = [];
  String? _ownExpertId;
  bool _identityLoaded = false;
  bool _loading = true;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final requests = await _repository.getRequests();
      if (!mounted) return;
      requests.fold((f) => _failure = f, (v) => _requests = v);
      if (requests.isRight()) {
        final own = await _repository.getMyProfile();
        if (!mounted) return;
        own.fold((_) => _identityLoaded = false, (p) {
          _identityLoaded = true;
          _ownExpertId = p?.id;
        });
      }
    } catch (_) {
      _failure = const ServerFailure(message: '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failure = _failure;
    return Scaffold(
      appBar: AppBar(title: Text(l.advocateInbox), actions: [
        IconButton(
            onPressed: _loading ? null : _load,
            tooltip: l.advocateRefresh,
            icon: const Icon(Icons.refresh)),
      ]),
      body: AppPageBody(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : failure != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(failureMessageFor(l, failure.code)),
                            const SizedBox(height: AppSpacing.md),
                            if (failure.code == FailureCode.unauthorized)
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
                  : _requests.isEmpty
                      ? Center(child: Text(l.advocateEmpty))
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final request = _requests[index];
                            return Card(
                                child: ListTile(
                              contentPadding:
                                  const EdgeInsets.all(AppSpacing.lg),
                              title: Text(request.serviceTitle ??
                                  (request.kind == 'message'
                                      ? l.advocateMessage
                                      : l.advocateConsult)),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(request.message,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                        '${_status(context, request.status)} · ${DateFormat.yMMMd(l.localeName).format(request.createdAt)}'),
                                  ]),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            AdvocateConversationPage(
                                              repository: _repository,
                                              request: request,
                                              isAdvocate: _identityLoaded
                                                  ? _ownExpertId ==
                                                      request.expertId
                                                  : null,
                                            )));
                                if (mounted) await _load();
                              },
                            ));
                          },
                        )),
    );
  }
}

class AdvocateConversationPage extends StatefulWidget {
  const AdvocateConversationPage(
      {super.key,
      required this.repository,
      required this.request,
      required this.isAdvocate});
  final AdvocateProfileRepository repository;
  final AdvocateRequest request;

  /// Null means owner identity could not be loaded; role-specific controls
  /// stay unavailable rather than guessing. RLS remains authoritative.
  final bool? isAdvocate;

  @override
  State<AdvocateConversationPage> createState() =>
      _AdvocateConversationPageState();
}

class _AdvocateConversationPageState extends State<AdvocateConversationPage> {
  final _message = TextEditingController();
  final _form = GlobalKey<FormState>();
  late AdvocateRequest _request = widget.request;
  List<AdvocateMessage> _messages = [];
  bool _loading = true;
  bool _busy = false;
  bool _requestAvailable = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
      _requestAvailable = false;
    });
    try {
      final current = await widget.repository.getRequest(_request.id);
      if (!mounted) return;
      current.fold((f) => _failure = f, (r) {
        _request = r;
        _requestAvailable = true;
      });
      if (current.isLeft()) return;
      final result = await widget.repository.getMessages(_request.id);
      if (!mounted) return;
      result.fold((f) => _failure = f, (v) => _messages = v);
    } catch (_) {
      _failure = const ServerFailure(message: '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _form.currentState?.validate() != true) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final result = await widget.repository
          .sendMessage(_request.id, _message.text.trim());
      if (!mounted) return;
      result.fold((f) => _failure = f, (_) => _message.clear());
      if (result.isRight()) await _load();
    } catch (_) {
      _failure = const ServerFailure(message: '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final result =
          await widget.repository.updateRequestStatus(_request.id, status);
      if (!mounted) return;
      result.fold((f) => _failure = f, (v) => _request = v);
    } catch (_) {
      _failure = const ServerFailure(message: '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failure = _failure;
    final pending = _requestAvailable && _request.status == 'pending';
    final accepted = _requestAvailable && _request.status == 'accepted';
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: Text(l.advocateThread), actions: [
            IconButton(
                onPressed: _loading || _busy ? null : _load,
                tooltip: l.advocateRefresh,
                icon: const Icon(Icons.refresh)),
          ]),
          body: AppPageBody(
              child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                Text(
                    _request.serviceTitle ??
                        (_request.kind == 'message'
                            ? l.advocateMessage
                            : l.advocateConsult),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(_status(context, _request.status)),
                const SizedBox(height: AppSpacing.md),
                Text(l.advocateRequestPrivacy),
                const SizedBox(height: AppSpacing.lg),
                if (widget.isAdvocate == true && pending) ...[
                  FilledButton(
                      onPressed: _busy ? null : () => _changeStatus('accepted'),
                      child: Text(l.advocateAccept)),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                      onPressed: _busy ? null : () => _changeStatus('declined'),
                      child: Text(l.advocateDecline)),
                ],
                if (widget.isAdvocate == false && (pending || accepted)) ...[
                  if (accepted)
                    FilledButton(
                        onPressed:
                            _busy ? null : () => _changeStatus('completed'),
                        child: Text(l.advocateComplete)),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                      onPressed:
                          _busy ? null : () => _changeStatus('cancelled'),
                      child: Text(l.advocateCancelRequest)),
                ],
                const SizedBox(height: AppSpacing.lg),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(_request.message))),
                if (_loading) const Center(child: CircularProgressIndicator()),
                for (final message in _messages)
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message.body),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                              DateFormat.yMMMd(l.localeName)
                                  .add_Hm()
                                  .format(message.createdAt.toLocal()),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  )),
                if (failure != null)
                  Text(failureMessageFor(l, failure.code),
                      key: const ValueKey('advocate_message_error'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (pending || accepted)
                  Form(
                      key: _form,
                      child: Column(children: [
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                            key: const ValueKey('advocate_reply'),
                            controller: _message,
                            enabled: !_busy,
                            minLines: 2,
                            maxLines: 5,
                            maxLength: 2000,
                            decoration: InputDecoration(
                                labelText: l.advocateRequestMessage),
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? l.advocateRequired
                                : null),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                key: const ValueKey('advocate_send_reply'),
                                onPressed: _busy || _loading ? null : _send,
                                icon: const Icon(Icons.send_outlined),
                                label: Text(l.advocateSend))),
                      ])),
                const SizedBox(height: AppSpacing.bottomSafe),
              ])),
        ));
  }
}
