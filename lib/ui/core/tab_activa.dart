import 'package:flutter/foundation.dart';

/// Índice del tab visible del shell (0 Inicio · 1 Billetera · 2 Historial ·
/// 3 Perfil). El StatefulShellRoute preserva los tabs en un IndexedStack, así
/// que no se reconstruyen al cambiar: los ViewModels escuchan este notifier
/// para refrescar sus cifras en silencio cuando su tab vuelve a ser visible
/// (p. ej. tras entregar un pedido).
class TabActiva extends ChangeNotifier {
  static const int inicio = 0;
  static const int billetera = 1;
  static const int historial = 2;
  static const int perfil = 3;

  int _indice = inicio;
  int get indice => _indice;

  void cambiar(int nuevo) {
    if (nuevo == _indice) return;
    _indice = nuevo;
    notifyListeners();
  }
}
