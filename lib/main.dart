import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'config/env.dart';
import 'di/locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');

  // Firebase es opcional: solo se inicializa si está habilitado y configurado.
  if (Env.fcmEnabled) {
    try {
      await Firebase.initializeApp();
    } catch (_) {/* sin google-services.json: la app sigue sin push */}
  }

  configurarDependencias();
  runApp(const MotoYaConductorApp());
}
