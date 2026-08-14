/// Marcas y modelos de moto que se ven en Córdoba.
///
/// Es una **lista fija en la app**, no un catálogo administrable. Montar tabla,
/// endpoints y pantalla en el panel para un dato que cambia una vez al año, y
/// que además ya tiene salida de escape ("Otra"), es infraestructura que hay que
/// mantener a cambio de nada.
///
/// **El orden no es alfabético a propósito.** Las tres primeras son las que de
/// verdad conduce la gente aquí; obligar a bajar hasta la V para encontrar una
/// Victory es el mismo trabajo que este desplegable venía a quitar.
///
/// El backend no se entera de nada de esto: la app compone `"<marca> <modelo>"`
/// y lo manda en el mismo campo `vehiculo` de siempre.
library;

/// Lo que se elige cuando la moto no está en la lista. Se compara por identidad
/// de texto, así que no puede coincidir con ninguna marca ni modelo real.
const String kOtro = 'Otra…';

/// Marcas con sus modelos comunes, en orden de uso real en la zona.
const Map<String, List<String>> catalogoMotos = {
  // Las tres primeras son las populares confirmadas en el municipio.
  'Bajaj': [
    'Boxer CT 100',
    'Boxer 150',
    'Pulsar NS 125',
    'Pulsar NS 160',
    'Pulsar 180',
    'Discover 125',
    'Platina 100',
  ],
  'TVS': [
    'Sport 100',
    'Apache RTR 160',
    'Apache RTR 180',
    'Raider 125',
    'Neo NX 110',
    'Stryker 125',
  ],
  'Victory': [
    'One 100',
    'Bomber 125',
    'Advance 110',
    'Switch 150',
    'MRX 125',
  ],
  'AKT': [
    'NKD 125',
    'Flex 125',
    'Special 110',
    'TT 125',
    'Dynamic 125',
    'Evo 125',
  ],
  'Yamaha': [
    'Crypton 110',
    'YBR 125',
    'FZ 150',
    'FZ 250',
    'XTZ 125',
    'NMAX 155',
  ],
  'Honda': [
    'CB 110',
    'CB 125F',
    'XR 150',
    'Navi 110',
    'Eco Deluxe 100',
    'CB 190R',
  ],
  'Suzuki': [
    'Best 125',
    'GN 125',
    'GSX 125',
    'V-Strom 250',
    'Address 110',
  ],
  'Hero': [
    'Eco Deluxe 100',
    'Hunk 150',
    'Ignitor 125',
    'Dash 110',
    'Xpulse 200',
  ],
  'Kymco': [
    'Agility 125',
    'Twist 125',
    'Like 150',
  ],
  'KTM': [
    'Duke 200',
    'Duke 250',
    'Adventure 250',
  ],
};

/// Marcas para el desplegable, con "Otra…" siempre al final.
List<String> get marcasMoto => [...catalogoMotos.keys, kOtro];

/// Modelos de una marca, con "Otra…" al final. Vacío si aún no hay marca.
List<String> modelosDe(String? marca) {
  if (marca == null || marca == kOtro) return const [];
  final modelos = catalogoMotos[marca];
  if (modelos == null) return const [];
  return [...modelos, kOtro];
}

/// Compone el `vehiculo` que espera el backend a partir de lo elegido.
///
/// Devuelve `null` si falta alguna de las dos partes: enviar media moto sería
/// guardar un dato que no dice nada, y el alta ya exige el campo.
String? componerVehiculo(String? marca, String? modelo) {
  final m = marca?.trim();
  final mo = modelo?.trim();
  if (m == null || m.isEmpty || mo == null || mo.isEmpty) return null;
  // Si el modelo ya empieza por la marca (alguien escribe "Bajaj Boxer" en el
  // campo libre), no se repite: "Bajaj Bajaj Boxer" es lo que verá el cliente.
  if (mo.toLowerCase().startsWith(m.toLowerCase())) return mo;
  return '$m $mo';
}
