import 'package:freezed_annotation/freezed_annotation.dart';

part 'line_item.freezed.dart';
part 'line_item.g.dart';

@freezed
class LineItem with _$LineItem {
  const factory LineItem({
    required String id,
    required String description,
    String? itemDetails,
    required double quantity,
    required double unitPrice,
    required double total,
    String? serviceId,
  }) = _LineItem;

  factory LineItem.fromJson(Map<String, dynamic> json) =>
      _$LineItemFromJson(json);
}
