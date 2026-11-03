import '../../core/network/api_exception.dart';

Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  throw const ApiException('Dữ liệu máy chủ không đúng định dạng.');
}

dynamic responseData(Object? response) => asJsonMap(response)['data'];

List<dynamic> responseList(Object? response) {
  final data = responseData(response);
  if (data is List<dynamic>) return data;
  throw const ApiException('Danh sách trả về không đúng định dạng.');
}
