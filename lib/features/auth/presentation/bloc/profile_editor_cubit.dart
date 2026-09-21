import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/auth/data/repositories/profile_avatar_repository.dart';
import 'package:lexhub/features/auth/domain/entities/user_profile_entity.dart';
import 'package:lexhub/features/auth/domain/repositories/auth_repository.dart';

class ProfileEditorState {
  const ProfileEditorState(
      {this.saving = false,
      this.saved,
      this.error,
      this.cleanupFailed = false});
  final bool saving;
  final UserProfileEntity? saved;
  final FailureCode? error;
  final bool cleanupFailed;
}

class ProfileEditorCubit extends Cubit<ProfileEditorState> {
  ProfileEditorCubit(this.repository, this.avatars)
      : super(const ProfileEditorState());
  final AuthRepository repository;
  final ProfileAvatarRepository avatars;

  Future<void> save(UserProfileEntity draft, {Uint8List? image}) async {
    if (state.saving) return;
    emit(const ProfileEditorState(saving: true));
    String? uploaded;
    try {
      if (image != null) uploaded = await avatars.upload(draft.id, image);
      final result = await repository.updateUserProfile(
          uploaded == null ? draft : draft.copyWith(avatarPath: uploaded));
      await result.fold((failure) async {
        // A timeout can occur after the DB commits. Never delete a referenced
        // avatar on an ambiguous failure; confirm the persisted pointer first.
        var cleanupFailed = false;
        if (uploaded != null) {
          final current = await repository.getUserProfile(draft.id);
          await current.fold((_) async {
            cleanupFailed = true;
          }, (profile) async {
            if (profile.avatarPath != uploaded) {
              try {
                await avatars.remove(draft.id, uploaded ?? '');
              } catch (_) {
                cleanupFailed = true;
              }
            }
          });
        }
        if (!isClosed) {
          emit(ProfileEditorState(
              error: failure.code, cleanupFailed: cleanupFailed));
        }
      }, (saved) async {
        var cleanupFailed = false;
        final oldPath = draft.avatarPath;
        if (uploaded != null && oldPath != null && oldPath != uploaded) {
          try {
            await avatars.remove(draft.id, oldPath);
          } catch (_) {
            cleanupFailed = true;
          }
        }
        if (!isClosed) {
          emit(ProfileEditorState(saved: saved, cleanupFailed: cleanupFailed));
        }
      });
    } catch (error) {
      if (!isClosed) {
        emit(ProfileEditorState(error: ErrorHandler.handle(error).code));
      }
    }
  }
}
