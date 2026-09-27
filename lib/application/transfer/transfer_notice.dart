import 'package:flutter/foundation.dart';

/// Kind of a transfer status message (maps 1:1 to the UI toast kinds and to
/// the old `AppStatusBannerKind`).
enum TransferNoticeKind { running, success, warning, error }

/// A status message produced by the transfer services; pages show it as a
/// toast.
@immutable
class TransferNotice {
  const TransferNotice(this.kind, this.title, {this.message});

  const TransferNotice.running(this.title, {this.message})
    : kind = TransferNoticeKind.running;
  const TransferNotice.success(this.title, {this.message})
    : kind = TransferNoticeKind.success;
  const TransferNotice.warning(this.title, {this.message})
    : kind = TransferNoticeKind.warning;
  const TransferNotice.error(this.title, {this.message})
    : kind = TransferNoticeKind.error;

  final TransferNoticeKind kind;
  final String title;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is TransferNotice &&
      other.kind == kind &&
      other.title == title &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, title, message);

  @override
  String toString() => 'TransferNotice($kind, $title, $message)';
}
