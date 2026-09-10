import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session_service.dart';

final sessionServiceProvider = Provider<SessionService>((ref) => SessionService());
