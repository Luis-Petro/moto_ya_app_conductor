/// Compara dos versiones por componentes numéricos: `1.10.0` es mayor que
/// `1.9.3`, que es justo lo que una comparación alfabética se equivoca.
///
/// Devuelve <0 si [a] es menor, 0 si son equivalentes y >0 si es mayor. Los
/// sufijos no numéricos (`1.2.0-beta`) se ignoran: solo cuentan los números.
int compararVersiones(String a, String b) {
  final na = _numeros(a);
  final nb = _numeros(b);
  final largo = na.length > nb.length ? na.length : nb.length;
  for (var i = 0; i < largo; i++) {
    final va = i < na.length ? na[i] : 0;
    final vb = i < nb.length ? nb[i] : 0;
    if (va != vb) return va < vb ? -1 : 1;
  }
  return 0;
}

List<int> _numeros(String version) {
  return RegExp(r'\d+')
      .allMatches(version)
      .map((m) => int.tryParse(m.group(0)!) ?? 0)
      .toList();
}
