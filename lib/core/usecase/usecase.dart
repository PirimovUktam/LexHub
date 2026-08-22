import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failures.dart';

/// Base UseCase interface for all asynchronous operations
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Base Synchronous UseCase interface
abstract class SyncUseCase<T, Params> {
  Either<Failure, T> call(Params params);
}

/// Base Stream UseCase interface for reactive data
abstract class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}

/// Class for use cases that require no parameters
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
