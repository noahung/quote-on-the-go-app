import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/team_service.dart';

final teamServiceProvider = Provider<TeamService>((ref) {
  return TeamService();
});
