import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vyuh_node_flow/vyuh_node_flow.dart';

import 'package:audioplayers/audioplayers.dart'
    show AudioPlayer, BytesSource, ReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';

// Marcador 5

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nombre de usuario y volumen guardados en el dispositivo.
  await AjustesApp.instance.cargar();

  // El ejecutor global corre el sistema sin importar la pantalla.
  EjecutorGlobal.instance.inicializar();

  // Hace sonar los Buzzer cuando están en ON.
  BuzzerManager.instance.inicializar();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const AutomatizacionApp());
}


// ==========================================================
// DATOS DE LOS 4 MÓDULOS
// ==========================================================

class ModuloPin {

  final int numero;

  bool conectado;

  String tipo;

  int cantidadPines;

  List<double> valores;

  ModuloPin({
    required this.numero,
    this.conectado = false,
    this.tipo = 'NONE',
    this.cantidadPines = 0,
    List<double>? valores,
  }) : valores = valores ?? [];

  // Los módulos DO tuvieron problemas: solo funcionan los
  // puertos 1 y 4. Los puertos 2 y 3 quedan deshabilitados
  // (no se pueden manipular ni usar en otras pantallas).
  static const Set<int> puertosDOHabilitados = {1, 4};

  bool puertoHabilitado(int puerto) {

    if (tipo == 'DO') {
      return puertosDOHabilitados.contains(puerto);
    }

    return true;
  }

  String get tipoTexto {

    switch (tipo) {

      case 'DI':
        return 'Entrada digital';

      case 'DO':
        return 'Salida digital';

      case 'AI':
        return 'Entrada analógica';

      default:
        return 'Sin módulo';
    }
  }
}


// ============================================================
// MODELOS DE COMPONENTES PARA DISEÑO Y CONEXIONES
// ============================================================

enum PinType {
  digitalInput,
  digitalOutput,
  analogInput,
  analogOutput,
}

class PinModel {
  final String id;
  final String label;
  final PinType type;

  // Cantidad máxima de conexiones que puede tener este pin.
  final int maxConnections;

  // Tipos de pin que pueden conectarse a esta entrada.
  final Set<PinType> conexionesPermitidas;

  const PinModel({
    required this.id,
    required this.label,
    required this.type,
    this.maxConnections = 1,
    this.conexionesPermitidas = const {},
  });

  String get tipoTexto {
    switch (type) {
      case PinType.digitalInput:
        return 'Entrada digital';

      case PinType.digitalOutput:
        return 'Salida digital';

      case PinType.analogInput:
        return 'Entrada analógica';

      case PinType.analogOutput:
        return 'Salida analógica';
    }
  }
}


// ============================================================
// SENSOR DE PRESIÓN (Festo 572745)
//
// El voltaje que muestra la app (entrada analógica) se convierte
// a presión en bares con:
//
//     presión [bar] = 1.5353 * voltaje + 0.05
// ============================================================

const String kIdSensorPresion = 'festo_572745';

// Parámetros de fábrica (se pueden cambiar con el botón Calibrar).
const double kCalibAFabrica = 1.5353;
const double kCalibBFabrica = 0.05;

double presionEnBares(double voltaje) {
  return kCalibAFabrica * voltaje + kCalibBFabrica;
}


// ============================================================
// REGISTRO DE COMPONENTES
// ============================================================

// Registro de los datos de los componentes.

// Simplemente agrega la imagen con el nombre donde vaya

final Map<String, ComponentModel> componentRegistry = {

  // ==========================================================
  // ACTUADORES
  // ==========================================================

  'FESTO_152887': ComponentModel(
    id: 'festo_152887', // Se utiliza el código FESTO
    name: 'Cilindro neumático de simple efecto',
    category: 'Actuadores',

    qrUrl: 'https://mi-app.com/qr/festo_152887',

    manufacturerUrl:
    'https://www.festo.com/',

    description:
    'Cilindro neumático de simple efecto Festo, '
        'referencia 152887.',

    inputs: const [
      PinModel(
        id: 'di_1',
        label: 'DI 1',
        type: PinType.digitalInput,
        maxConnections: 1,
        conexionesPermitidas: {
          PinType.digitalOutput,
        },
      ),
    ],

    outputs: const [],

    imageAsset:
    'assets/components/actuators/festo_152887.png',

    imageOnAsset:
    'assets/components/actuators/festo_152887_on.png',
  ),


  'FESTO_152888': ComponentModel(
    id: 'festo_152888',
    name: 'Cilindro neumático de doble efecto',
    category: 'Actuadores',

    qrUrl: 'https://mi-app.com/qr/festo_152888',

    manufacturerUrl:
    'https://www.festo.com/',

    description:
    'Cilindro neumático de doble efecto Festo, '
        'referencia 152888.',

    inputs: const [
      PinModel(
        id: 'di_1',
        label: 'DI 1',
        type: PinType.digitalInput,
        maxConnections: 1,
        conexionesPermitidas: {
          PinType.digitalOutput,
        },
      ),

      PinModel(
        id: 'di_2',
        label: 'DI 2',
        type: PinType.digitalInput,
        maxConnections: 1,
        conexionesPermitidas: {
          PinType.digitalOutput,
        },
      ),
    ],

    outputs: const [],

    imageAsset:
    'assets/components/actuators/festo_152888.png',

    imageOnAsset:
    'assets/components/actuators/festo_152888_on.png',
  ),


  // ==========================================================
  // SENSORES
  // ==========================================================

  'FESTO_183322': ComponentModel(
    id: 'festo_183322',
    name: 'Sensor de final de carrera mecánico',
    category: 'Sensores',

    qrUrl: 'https://mi-app.com/qr/festo_183322',

    manufacturerUrl:
    'https://www.festo.com/',

    description:
    'Final de carrera mecánico Festo, '
        'referencia 183322.',

    inputs: const [],

    outputs: const [
      PinModel(
        id: 'do_1',
        label: 'DO 1',
        type: PinType.digitalOutput,
        maxConnections: 1,
      ),
    ],

    imageAsset:
    'assets/components/sensors/festo_183322.png',

    imageOnAsset:
    'assets/components/sensors/festo_183322_on.png',
  ),


  'FESTO_548643': ComponentModel(
    id: 'festo_548643',
    name: 'Sensor de proximidad inductivo M12',
    category: 'Sensores',

    qrUrl: 'https://mi-app.com/qr/festo_548643',

    manufacturerUrl:
    'https://www.festo.com/',

    description:
    'Sensor de proximidad inductivo M12 Festo, '
        'referencia 548643.',

    inputs: const [],

    outputs: const [
      PinModel(
        id: 'do_1',
        label: 'DO 1',
        type: PinType.digitalOutput,
        maxConnections: 1,
      ),
    ],

    imageAsset:
    'assets/components/sensors/festo_548643.png',

    imageOnAsset:
    'assets/components/sensors/festo_548643_on.png',
  ),


  'FESTO_548645': ComponentModel(
    id: 'festo_548645',
    name: 'Sensor de proximidad inductivo M18',
    category: 'Sensores',

    qrUrl: 'https://mi-app.com/qr/festo_548645',

    manufacturerUrl:
    'https://www.festo.com/',

    description:
    'Sensor de proximidad inductivo M18 Festo, '
        'referencia 548645.',

    inputs: const [],

    outputs: const [
      PinModel(
        id: 'do_1',
        label: 'DO 1',
        type: PinType.digitalOutput,
        maxConnections: 1,
      ),
    ],

    imageAsset:
    'assets/components/sensors/festo_548645.png',

    imageOnAsset:
    'assets/components/sensors/festo_548645_on.png',
  ),


  'FESTO_548651': ComponentModel(
    id: 'festo_548651',
    name: 'Sensor de proximidad capacitivo M12',
    category: 'Sensores',

    qrUrl: 'https://mi-app.com/qr/festo_548651',

    manufacturerUrl:
    'https://www.festo.com/',

    description:
    'Sensor de proximidad capacitivo M12 Festo, '
        'referencia 548651. Salida digital.',

    inputs: const [],

    outputs: const [
      PinModel(
        id: 'do_1',
        label: 'DO 1',
        type: PinType.digitalOutput,
        maxConnections: 1,
      ),
    ],

    imageAsset:
    'assets/components/sensors/festo_548651.png',

    imageOnAsset:
    'assets/components/sensors/festo_548651_on.png',
  ),


  'FESTO_572745': ComponentModel(
    id: 'festo_572745',
    name: 'Sensor de presión neumático',
    category: 'Sensores',

    qrUrl: 'https://mi-app.com/qr/festo_572745',

    manufacturerUrl:
    'https://www.festo.com/',

    description:
    'Sensor de presión neumático Festo, referencia 572745. '
        'Salida analógica: se conecta a una entrada analógica (AI) '
        'y en Monitoreo síncrono se muestra la presión en bares.',

    inputs: const [],

    outputs: const [
      PinModel(
        id: 'ao_1',
        label: 'AO 1',
        type: PinType.analogOutput,
        maxConnections: 1,
      ),
    ],

    imageAsset:
    'assets/components/sensors/festo_572745.png',
  ),


  // ==========================================================
  // OTROS
  // ==========================================================

  'SWITCH': ComponentModel(
    id: 'switch',
    name: 'Switch',
    category: 'Otros',

    qrUrl: 'https://mi-app.com/qr/switch',

    manufacturerUrl: '',

    description:
    'Switch digital para generar una señal ON/OFF.',

    inputs: const [],

    outputs: const [
      PinModel(
        id: 'do_1',
        label: 'DO 1',
        type: PinType.digitalOutput,
        maxConnections: 1,
      ),
    ],

    imageAsset:
    'assets/components/other/switch.png',

    imageOnAsset:
    'assets/components/other/switch_on.png',
  ),


  'BUTTON': ComponentModel(
    id: 'button',
    name: 'Botón',
    category: 'Otros',

    qrUrl: 'https://mi-app.com/qr/button',

    manufacturerUrl: '',

    description:
    'Botón digital para generar una señal ON/OFF.',

    inputs: const [],

    outputs: const [
      PinModel(
        id: 'do_1',
        label: 'DO 1',
        type: PinType.digitalOutput,
        maxConnections: 1,
      ),
    ],

    imageAsset:
    'assets/components/other/button.png',

    imageOnAsset:
    'assets/components/other/button_on.png',
  ),


  'LED': ComponentModel(
    id: 'led',
    name: 'LED',
    category: 'Otros',

    qrUrl: 'https://mi-app.com/qr/led',

    manufacturerUrl: '',

    description:
    'Indicador luminoso controlado mediante una salida digital.',

    inputs: const [
      PinModel(
        id: 'di_1',
        label: 'DI 1',
        type: PinType.digitalInput,
        maxConnections: 1,
        conexionesPermitidas: {
          PinType.digitalOutput,
        },
      ),
    ],

    outputs: const [],

    imageAsset:
    'assets/components/other/led.png',
  ),


  'BUZZER': ComponentModel(
    id: 'buzzer',
    name: 'Buzzer',
    category: 'Otros',

    qrUrl: 'https://mi-app.com/qr/buzzer',

    manufacturerUrl: '',

    description:
    'Zumbador controlado mediante una entrada digital. '
        'Cuando está en ON emite un sonido, que se puede '
        'cambiar en la información del componente.',

    inputs: const [
      PinModel(
        id: 'di_1',
        label: 'DI 1',
        type: PinType.digitalInput,
        maxConnections: 1,
        conexionesPermitidas: {
          PinType.digitalOutput,
        },
      ),
    ],

    outputs: const [],

    imageAsset:
    'assets/components/other/buzzer.png',

    imageOnAsset:
    'assets/components/other/buzzer_on.png',
  ),
};


// ============================================================
// COMPONENTE REGISTRADO
// ============================================================

class ComponentModel {

  final String id;
  final String name;
  final String category;

  final String qrUrl;
  final String manufacturerUrl;

  final String description;

  final List<PinModel> inputs;
  final List<PinModel> outputs;

  final String imageAsset;
  final String? imageOnAsset;

  const ComponentModel({
    required this.id,
    required this.name,
    required this.category,
    required this.qrUrl,
    required this.manufacturerUrl,
    required this.description,
    required this.inputs,
    required this.outputs,
    required this.imageAsset,
    this.imageOnAsset,
  });
}


// ============================================================
// COMPONENTE COLOCADO EN EL ÁREA DE TRABAJO
// ============================================================

// Asignación de un pin del componente a un puerto de un módulo.
// ============================================================
// CATÁLOGO DE COMPONENTES (datos del Excel "Data de los componentes")
//
// Es la información que se muestra al escanear un QR. Cada ficha
// tiene uno o varios códigos FESTO y uno o varios links (por
// ejemplo, el sensor óptico de barrera tiene emisor y receptor:
// dos QR, dos links, la misma información). El link del botón
// "Link para más información" es el del QR que se escaneó.
//
// estado:
//  - disponible : se puede añadir a Diseño y conexiones
//                 (idRegistro = clave en componentRegistry).
//  - noAnadible : válvulas; no están hechas para añadirse.
//  - noDisenado : componente que aún no se ha diseñado.
// ============================================================

enum EstadoDiseno {
  disponible,
  noAnadible,
  noDisenado,
}

class FichaComponente {

  final String nombre;
  final String tipoDispositivo;
  final String tipoSenal;
  final String accionamiento;

  // Códigos FESTO y links, en el mismo orden (codigos[i] <-> links[i]).
  final List<String> codigos;
  final List<String> links;

  final EstadoDiseno estado;

  // Clave del componente en componentRegistry (solo si es "disponible").
  final String? idRegistro;

  const FichaComponente({
    required this.nombre,
    required this.tipoDispositivo,
    required this.tipoSenal,
    required this.accionamiento,
    required this.codigos,
    required this.links,
    required this.estado,
    this.idRegistro,
  });

  String get codigosTexto =>
      codigos.isEmpty ? '-' : codigos.join(' / ');
}

// Resultado de buscar un QR en el catálogo.
class ResultadoQR {

  final FichaComponente ficha;

  // Link que debe abrir el botón (el del QR escaneado).
  final String? link;

  const ResultadoQR(this.ficha, this.link);
}

class CatalogoComponentes {

  CatalogoComponentes._();

  static const List<FichaComponente> fichas = [
    FichaComponente(
      nombre: 'Cilindro hidráulico de doble efecto',
      tipoDispositivo: 'Actuador',
      tipoSenal: '-',
      accionamiento: 'Hidráulico',
      codigos: ['152857'],
      links: [
        'https://www.festo.com/assets/attachment/es/664385/765827',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Electroválvula 5-3 centro flotante',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['544348'],
      links: [
        'https://www.festo.com/assets/attachment/es/664654/766634',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Sensor de presión hidráulico',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Analógico y digital',
      accionamiento: '-',
      codigos: ['548612'],
      links: [
        'https://www.festo.com/assets/attachment/es/664664/766674',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Sensor de velocidad (flujo) acoplado al motor',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Analógico',
      accionamiento: '-',
      codigos: ['567191'],
      links: [
        'https://www.festo.com/assets/attachment/es/664728/766913',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Válvula 4-2 biestable',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['544352'],
      links: [
        'https://www.festo.com/assets/attachment/es/664658/766650',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Válvula 4-2 monoestable',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['544346'],
      links: [
        'https://www.festo.com/assets/attachment/es/664652/766626',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Válvula 5-3 centro cerrado',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['544347'],
      links: [
        'https://www.festo.com/assets/attachment/es/664653/766630',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Cilindro neumático de doble efecto',
      tipoDispositivo: 'Actuador',
      tipoSenal: '-',
      accionamiento: 'Neumático',
      codigos: ['152888'],
      links: [
        'https://www.festo.com/assets/attachment/es/664416/765923',
      ],
      estado: EstadoDiseno.disponible,
      idRegistro: 'FESTO_152888',
    ),
    FichaComponente(
      nombre: 'Cilindro neumático de simple efecto',
      tipoDispositivo: 'Actuador',
      tipoSenal: '-',
      accionamiento: 'Neumático',
      codigos: ['152887'],
      links: [
        'https://www.festo.com/assets/attachment/es/664415/765919',
      ],
      estado: EstadoDiseno.disponible,
      idRegistro: 'FESTO_152887',
    ),
    FichaComponente(
      nombre: 'Sensor de final de carrera (rodillos bidireccionales eléctricos)',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['183322'],
      links: [
        'https://www.festo.com/assets/attachment/es/664511/766161',
      ],
      estado: EstadoDiseno.disponible,
      idRegistro: 'FESTO_183322',
    ),
    FichaComponente(
      nombre: 'Sensor de presión',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Por confirmar',
      accionamiento: '-',
      codigos: ['572745'],
      links: [
        'https://www.festo.com/assets/attachment/es/664783/767124',
      ],
      estado: EstadoDiseno.disponible,
      idRegistro: 'FESTO_572745',
    ),
    FichaComponente(
      nombre: 'Válvula 3-2 bidireccional',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['152866'],
      links: [
        'https://www.festo.com/assets/attachment/es/664395/765867',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Válvula 3-2 contrapresión',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['152868'],
      links: [
        'https://www.festo.com/assets/attachment/es/664397/765875',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Válvula 3-2 unidireccional',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['152867'],
      links: [
        'https://www.festo.com/assets/attachment/es/664396/765871',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Válvula 5-2 monoestable',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['567199'],
      links: [
        'https://www.festo.com/assets/attachment/es/664730/766921',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Válvulas 2 x 3-2 monoestables',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['567198'],
      links: [
        'https://www.festo.com/assets/attachment/es/664729/766917',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Válvulas 2 x 5-2 monoestables y 2 x 5-2 biestables (cable conector, monoestable y biestable)',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['533195', '533342', '533343'],
      links: [
        'https://www.festo.com/us/en/a/download-document/datasheet/533195',
        'https://www.festo.com/us/en/a/download-document/datasheet/533342',
        'https://www.festo.com/us/en/a/download-document/datasheet/533343',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Válvulas 5-2 biestables',
      tipoDispositivo: 'Actuador',
      tipoSenal: 'Digital',
      accionamiento: 'Eléctrico',
      codigos: ['567200'],
      links: [
        'https://www.festo.com/assets/attachment/es/664731/766925',
      ],
      estado: EstadoDiseno.noAnadible,
    ),
    FichaComponente(
      nombre: 'Sensor de proximidad magneto resistivo',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['566199'],
      links: [
        'https://www.festo.com/assets/attachment/es/664715/766861',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Sensor de proximidad retroreflectivo (emisor y rebote)',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['548649', '548650'],
      links: [
        'https://www.festo.com/assets/attachment/es/664682/766741',
        'https://www.festo.com/assets/attachment/es/664683/766745',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Sensor de proximidad difuso con supresión de fondo',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['548656'],
      links: [
        'https://www.festo.com/assets/attachment/es/664686/766757',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Sensor de proximidad difuso',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['572744'],
      links: [
        'https://www.festo.com/assets/attachment/es/664782/767121',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Sensor inductivo de proximidad M18',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['548645'],
      links: [
        'https://www.festo.com/assets/attachment/es/664679/766729',
      ],
      estado: EstadoDiseno.disponible,
      idRegistro: 'FESTO_548645',
    ),
    FichaComponente(
      nombre: 'Sensor inductivo de proximidad M12',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['548643'],
      links: [
        'https://www.festo.com/assets/attachment/es/664677/766721',
      ],
      estado: EstadoDiseno.disponible,
      idRegistro: 'FESTO_548643',
    ),
    FichaComponente(
      nombre: 'Sensor inductivo de proximidad ANALÓGICO M12',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Analógico',
      accionamiento: '-',
      codigos: ['548644'],
      links: [
        'https://www.festo.com/assets/attachment/es/664678/766725',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Sensor capacitivo de proximidad M12',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['548651'],
      links: [
        'https://www.festo.com/assets/attachment/es/664684/766749',
      ],
      estado: EstadoDiseno.disponible,
      idRegistro: 'FESTO_548651',
    ),
    FichaComponente(
      nombre: 'Sensor óptico de barrera (emisor y receptor)',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['548648', '548647'],
      links: [
        'https://www.festo.com/assets/attachment/es/664681/766737',
        'https://www.festo.com/assets/attachment/es/664680/766733',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Sensor de proximidad de fibra óptica (sensor, cabezal y cable)',
      tipoDispositivo: 'Sensor',
      tipoSenal: 'Digital',
      accionamiento: '-',
      codigos: ['548655', '548659', '165358'],
      links: [
        'https://www.festo.com/assets/attachment/es/664685/766753',
        'https://www.festo.com/assets/attachment/es/664688/766761',
        'https://www.festo.com/assets/attachment/en/699348/882402',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
    FichaComponente(
      nombre: 'Botón de emergencia',
      tipoDispositivo: 'Dispositivo de mando',
      tipoSenal: 'Digital',
      accionamiento: 'Manual',
      codigos: ['183347'],
      links: [
        'https://www.festo.com/assets/attachment/es/664513/766169',
      ],
      estado: EstadoDiseno.noDisenado,
    ),
  ];

  static String _normalizar(String texto) {

    var t = texto.trim().toLowerCase();

    while (t.endsWith('/')) {
      t = t.substring(0, t.length - 1);
    }

    return t;
  }

  // Busca el contenido de un QR. Se acepta, en este orden:
  //  1) que el QR sea uno de los links del catálogo,
  //  2) que el QR contenga el código FESTO del componente,
  //  3) que sea el QR antiguo de la app (componentRegistry.qrUrl).
  // Devuelve null si el QR no corresponde a ningún componente.
  static ResultadoQR? buscar(String leido) {

    final n = _normalizar(leido);

    if (n.isEmpty) {
      return null;
    }

    // ---------------- 1) POR LINK ----------------
    for (final f in fichas) {
      for (final link in f.links) {
        final l = _normalizar(link);
        if (n == l || n.startsWith(l)) {
          return ResultadoQR(f, link);
        }
      }
    }

    // ---------------- 2) POR CÓDIGO FESTO ----------------
    for (final f in fichas) {
      for (int i = 0; i < f.codigos.length; i++) {
        final patron = RegExp('(?<![0-9])${f.codigos[i]}(?![0-9])');
        if (patron.hasMatch(n)) {
          final link = f.links.isEmpty
              ? null
              : f.links[i < f.links.length ? i : 0];
          return ResultadoQR(f, link);
        }
      }
    }

    // ---------------- 3) QR ANTIGUO DE LA APP ----------------
    for (final e in componentRegistry.entries) {

      if (_normalizar(e.value.qrUrl) != n) {
        continue;
      }

      for (final f in fichas) {
        if (f.idRegistro == e.key) {
          return ResultadoQR(f, f.links.isEmpty ? null : f.links.first);
        }
      }

      // Componente sin ficha en el Excel (Switch, Botón, LED, Buzzer).
      final url = e.value.manufacturerUrl;

      return ResultadoQR(
        FichaComponente(
          nombre: e.value.name,
          tipoDispositivo: e.value.category,
          tipoSenal: '-',
          accionamiento: '-',
          codigos: const [],
          links: url.isEmpty ? const [] : [url],
          estado: EstadoDiseno.disponible,
          idRegistro: e.key,
        ),
        url.isEmpty ? null : url,
      );
    }

    return null;
  }
}


// ============================================================
// COLORES ISA-101 PARA LOS COMPONENTES
//
// Fondo y bordes en grises de bajo contraste. El color (verde
// apagado) se usa solo para indicar que algo está activo, y
// aparece dentro de la imagen del componente en su estado ON.
// Los colores vivos (rojo, amarillo) quedan reservados para
// alarmas futuras.
// ============================================================
const Color kIsaFondo = Color(0xFFF2F3F4);
const Color kIsaBorde = Color(0xFF6B7278);
const Color kIsaTexto = Color(0xFF2E3338);
const Color kIsaOn = Color(0xFF4E9868);

class AsignacionPin {
  final int modulo;
  final int puerto;

  const AsignacionPin({
    required this.modulo,
    required this.puerto,
  });
}

class PlacedComponent {

  final String instanceId;

  // Asignaciones: id del pin del componente -> módulo/puerto.
  final Map<String, AsignacionPin> asignaciones = {};

  final ComponentModel component;

  // Número de esta instancia del componente.
  // Ejemplo: Switch 1, Switch 2, Switch 3...
  final int instanceNumber;

  final List<PinModel> inputs;

  final List<PinModel> outputs;

  // Sonido del Buzzer (id de BuzzerManager.sonidos).
  String sonido = BuzzerManager.sonidoPorDefecto;

  // Color del LED (posición en kColoresLed).
  int indiceColorLed = 0;

  Color get colorLed => kColoresLed[indiceColorLed].color;

  // Calibración del sensor de presión:
  //   presión (bar) = calibA * voltaje + calibB
  double calibA = kCalibAFabrica;
  double calibB = kCalibBFabrica;

  // Coeficiente de determinación (0 a 1). null = valores de fábrica.
  double? calibR2;

  // Pares [voltaje, presión] con los que se calibró.
  List<List<double>> calibPuntos = [];

  double presionDe(double voltaje) => calibA * voltaje + calibB;

  // Valor final de la medida: presión en bar para el sensor de
  // presión (con su calibración) y voltaje para los demás.
  double convertirMedida(double voltaje) =>
      component.id == kIdSensorPresion ? presionDe(voltaje) : voltaje;

  String get unidadMedida =>
      component.id == kIdSensorPresion ? 'bar' : 'V';

  // ON/OFF calculado a partir del estado real del sistema.
  bool get activo => EjecutorGlobal.instance.estadoComponente(this);

  PlacedComponent({
    required this.instanceId,
    required this.component,
    required this.instanceNumber,
  })  : inputs = List<PinModel>.from(component.inputs),
        outputs = List<PinModel>.from(component.outputs);
}

// ============================================================
// ADMINISTRADOR BLUETOOTH GLOBAL
// ============================================================


class BluetoothManager extends ChangeNotifier {

  BluetoothManager._privateConstructor();

  static final BluetoothManager instance =
  BluetoothManager._privateConstructor();

  // ==========================================================
  // NOMBRE DEL ESP32
  // ==========================================================

  static const String nombreESP32 =
      'ESP32-AUTOMATIZACION2';

  // ==========================================================
  // DISPOSITIVO CONECTADO
  // ==========================================================

  BluetoothDevice? esp32;

  BluetoothConnection? connection;

  // ==========================================================
  // LISTA DE DISPOSITIVOS ENCONTRADOS
  // ==========================================================

  List<BluetoothDevice> dispositivos = [];

  bool buscando = false;

  String errorBusqueda = '';

  // ==========================================================
  // ESTADO DE CONEXIÓN
  // ==========================================================

  StreamSubscription<Uint8List>?
  rxSubscription;

  StreamSubscription<BluetoothDiscoveryResult>?
  discoverySubscription;

  bool conectado = false;

  String estado = 'No conectado';


  // ==========================================================
  // LISTA DE MÓDULOS
  // ==========================================================

  final List<ModuloPin> modulos =
  List.generate(
    4,
        (index) => ModuloPin(
      numero: index + 1,
    ),
  );


  // ==========================================================
  // MÓDULO SELECCIONADO
  // ==========================================================

  int moduloSeleccionado = 1;

  // ==========================================================
  // BUSCAR DISPOSITIVOS
  // ==========================================================

  Future<void> buscarDispositivos() async {

    if (buscando || reconectando) {
      return;
    }

    dispositivos.clear();
    errorBusqueda = '';
    buscando = true;

    estado = 'Buscando dispositivos...';

    notifyListeners();

    try {

      // --------------------------------------------------------
      // PERMISOS BLUETOOTH
      // --------------------------------------------------------

      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      // --------------------------------------------------------
      // OBTENER DISPOSITIVOS EMPAREJADOS
      // --------------------------------------------------------

      final dispositivosEmparejados =
      await FlutterBluetoothSerial.instance
          .getBondedDevices();

      dispositivos = List.from(
        dispositivosEmparejados,
      );

      // --------------------------------------------------------
      // DESCUBRIMIENTO DE DISPOSITIVOS
      // --------------------------------------------------------

      await discoverySubscription?.cancel();

      discoverySubscription =
          FlutterBluetoothSerial.instance
              .startDiscovery()
              .listen(
                (resultado) {

              final dispositivo =
                  resultado.device;

              final existe =
              dispositivos.any(
                    (d) =>
                d.address ==
                    dispositivo.address,
              );

              if (!existe) {

                dispositivos.add(
                  dispositivo,
                );

                notifyListeners();
              }
            },
          );

      // --------------------------------------------------------
      // ESPERAR 6 SEGUNDOS
      // --------------------------------------------------------

      await Future.delayed(
        const Duration(seconds: 6),
      );

      await discoverySubscription?.cancel();

      discoverySubscription = null;

      // --------------------------------------------------------
      // RESULTADO
      // --------------------------------------------------------

      if (dispositivos.isEmpty) {

        estado =
        'No se encontraron dispositivos';

      } else {

        estado = conectado
            ? 'Conectado a ESP32'
            : (reconectando ? estado : 'No conectado');
      }

    } catch (e) {

      errorBusqueda =
      'Error al buscar dispositivos';

      estado = 'No conectado';

      print(
        'ERROR ESCANEO BLUETOOTH CLÁSICO: $e',
      );

    } finally {

      buscando = false;

      notifyListeners();
    }
  }

  // ==========================================================
  // OBTENER NOMBRE DEL DISPOSITIVO
  // ==========================================================

  String obtenerNombre(BluetoothDevice dispositivo) {

    final nombre =
    dispositivo.name?.trim();

    if (nombre != null &&
        nombre.isNotEmpty) {

      return nombre;
    }

    return 'Dispositivo Bluetooth';
  }

  // ==========================================================
  // VERIFICAR SI ES EL ESP32
  // ==========================================================

  bool esESP32(BluetoothDevice dispositivo) {

    final nombre =
    obtenerNombre(dispositivo);

    return nombre == nombreESP32;
  }

  // ==========================================================
  // CONEXIÓN ROBUSTA (RECONEXIÓN AUTOMÁTICA)
  //
  // Si la conexión se corta de forma inesperada (por ejemplo por
  // problemas de alimentación del ESP32), la app intenta
  // reconectar cada medio segundo durante 5 segundos. Si no lo
  // logra, libera por completo la conexión y queda disponible
  // para que otra tablet o teléfono con la app pueda conectarse.
  // ==========================================================

  // Tiempo máximo que se intenta reconectar.
  static const Duration tiempoTotalReconexion = Duration(seconds: 5);

  // Pausa entre un intento fallido y el siguiente.
  static const Duration intervaloReconexion = Duration(milliseconds: 500);

  // "Latido": la app envía PING cada pocos segundos. Sirve para
  // detectar antes una conexión muerta. Si el ESP32 responde PONG
  // (ver el código opcional del ESP32), y deja de llegar cualquier
  // dato durante [tiempoSinRespuesta], se considera perdida la
  // conexión. Si el ESP32 no responde PONG, el latido solo ayuda a
  // detectar errores de envío y no desconecta nunca por silencio.
  static const bool enviarLatido = true;
  static const Duration intervaloLatido = Duration(seconds: 2);
  static const Duration tiempoSinRespuesta = Duration(seconds: 6);

  // true mientras se está intentando reconectar.
  bool reconectando = false;

  // Número del intento actual (1, 2, 3...).
  int intentoReconexion = 0;

  // Cada conexión o desconexión manual aumenta este número y
  // cancela cualquier reconexión que estuviera en curso.
  int _generacion = 0;

  Timer? _timerLatido;

  DateTime _ultimoDatoRecibido = DateTime.now();

  bool _esp32RespondePong = false;

  // Muestra un aviso en la pantalla en la que esté el usuario.
  void _avisar(String texto) {

    final messenger =
        AutomatizacionApp.messengerKey.currentState;

    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            texto,
            textAlign: TextAlign.center,
          ),
        ),
      );
  }

  // ==========================================================
  // PUERTOS HABILITADOS
  //
  // Los módulos DO tuvieron problemas: solo funcionan los
  // puertos 1 y 4 (ver ModuloPin.puertoHabilitado).
  // ==========================================================

  bool puertoHabilitado(int numeroModulo, int puerto) {

    if (numeroModulo < 1 ||
        numeroModulo > modulos.length) {
      return false;
    }

    return modulos[numeroModulo - 1]
        .puertoHabilitado(puerto);
  }

  // ==========================================================
  // CERRAR / LIBERAR CONEXIONES
  // ==========================================================

  Future<void> _cerrarConexion(
      BluetoothConnection? con) async {

    if (con == null) {
      return;
    }

    try {

      await con.close().timeout(
        const Duration(seconds: 1),
      );

    } catch (_) {}
  }

  // Cierra la conexión actual (y su escucha) sin cambiar el
  // estado mostrado en pantalla.
  Future<void> _liberarConexion() async {

    _detenerLatido();

    final suscripcion = rxSubscription;
    final con = connection;

    rxSubscription = null;
    connection = null;

    try {

      await suscripcion?.cancel();

    } catch (_) {}

    await _cerrarConexion(con);
  }

  // ==========================================================
  // CONECTAR A DISPOSITIVO
  // ==========================================================

  Future<String?> conectarDispositivo( BluetoothDevice dispositivo) async {

    // --------------------------------------------------------
    // SI YA ESTÁ CONECTADO
    // --------------------------------------------------------

    if (conectado) {
      return null;
    }

    // --------------------------------------------------------
    // SI SE ESTÁ RECONECTANDO
    // --------------------------------------------------------

    if (reconectando) {

      return 'Reconectando con el ESP32, espere un momento';
    }

    // --------------------------------------------------------
    // VERIFICAR ESP32
    // --------------------------------------------------------

    if (!esESP32(dispositivo)) {

      return 'El dispositivo seleccionado no es un ESP32';
    }

    final generacion = ++_generacion;

    try {

      estado = 'Conectando...';

      errorBusqueda = '';

      notifyListeners();

      // ------------------------------------------------------
      // CERRAR CONEXIÓN ANTERIOR
      // ------------------------------------------------------

      await _liberarConexion();

      // ------------------------------------------------------
      // CONEXIÓN BLUETOOTH CLÁSICO
      // ------------------------------------------------------

      final nueva =
      await BluetoothConnection.toAddress(
        dispositivo.address,
      );

      // Si mientras tanto se pulsó "Desconectar", se cancela.
      if (generacion != _generacion) {

        await _cerrarConexion(nueva);

        return 'Conexión cancelada';
      }

      await _adoptarConexion(
        dispositivo,
        nueva,
      );

      return null;

    } catch (e) {

      conectado = false;

      estado = 'No conectado';

      connection = null;
      esp32 = null;

      errorBusqueda = '';

      print(
        'ERROR BLUETOOTH CLÁSICO: $e',
      );

      notifyListeners();

      return 'Error al conectar con el ESP32';
    }
  }

  // ==========================================================
  // USAR UNA CONEXIÓN NUEVA (conexión normal o reconexión)
  // ==========================================================

  Future<void> _adoptarConexion(
      BluetoothDevice dispositivo,
      BluetoothConnection nueva) async {

    connection = nueva;

    esp32 = dispositivo;

    bufferBluetooth = '';

    conectado = true;

    reconectando = false;

    intentoReconexion = 0;

    estado = 'Conectado a ESP32';

    errorBusqueda = '';

    print(
      'BLUETOOTH CLÁSICO: CONECTADO',
    );

    notifyListeners();

    // ------------------------------------------------------
    // RECIBIR DATOS
    // ------------------------------------------------------

    await rxSubscription?.cancel();

    rxSubscription =
        nueva.input!.listen(
          recibirDatos,
          onDone: () {
            _alCerrarseEntrada(nueva);
          },
          onError: (Object error) {
            print(
              'ERROR EN LA RECEPCIÓN BLUETOOTH: $error',
            );
            _alCerrarseEntrada(nueva);
          },
          cancelOnError: true,
        );

    _iniciarLatido();

    // ------------------------------------------------------
    // SOLICITAR INFORMACIÓN DE MÓDULOS
    // ------------------------------------------------------

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    await solicitarModulos();
  }

  // Se llama cuando la conexión se cierra o falla la recepción.
  void _alCerrarseEntrada(BluetoothConnection origen) {

    // Si ya se reemplazó o cerró esa conexión, se ignora.
    if (!identical(origen, connection)) {
      return;
    }

    _alPerderConexion();
  }

  // ==========================================================
  // CONEXIÓN PERDIDA -> RECONECTAR
  // ==========================================================

  Future<void> _alPerderConexion() async {

    if (reconectando || !conectado) {
      return;
    }

    final dispositivo = esp32;

    final generacion = ++_generacion;

    print(
      'BLUETOOTH CLÁSICO: CONEXIÓN PERDIDA',
    );

    conectado = false;

    reconectando = true;

    intentoReconexion = 0;

    bufferBluetooth = '';

    estado = 'Conexión perdida. Reconectando...';

    // La búsqueda de dispositivos estorba al reconectar.
    await discoverySubscription?.cancel();

    discoverySubscription = null;

    notifyListeners();

    _avisar(
      'Conexión con el ESP32 perdida. Reconectando...',
    );

    await _liberarConexion();

    bool exito = false;

    if (dispositivo != null) {

      exito = await _reconectar(
        dispositivo,
        generacion,
      );
    }

    // Si el usuario pulsó Desconectar o Conectar mientras tanto,
    // ya se encargó de dejar todo en orden.
    if (generacion != _generacion) {
      return;
    }

    if (exito) {

      _avisar(
        'Conexión con el ESP32 recuperada',
      );

      return;
    }

    // --------------------------------------------------------
    // NO SE PUDO RECONECTAR: se libera todo para que otra
    // tablet o teléfono pueda conectarse al ESP32.
    // --------------------------------------------------------

    print(
      'BLUETOOTH CLÁSICO: RECONEXIÓN FALLIDA',
    );

    await _liberarConexion();

    reconectando = false;

    intentoReconexion = 0;

    conectado = false;

    esp32 = null;

    bufferBluetooth = '';

    estado = 'No conectado';

    errorBusqueda =
    'Se perdió la conexión con el ESP32 y no se pudo reconectar.';

    notifyListeners();

    _avisar(
      'No se pudo reconectar con el ESP32. '
          'Conéctese de nuevo desde Bluetooth.',
    );
  }

  // Intenta reconectar durante [tiempoTotalReconexion], con una
  // pausa de [intervaloReconexion] entre un intento y otro.
  Future<bool> _reconectar(
      BluetoothDevice dispositivo,
      int generacion) async {

    final reloj = Stopwatch()..start();

    while (generacion == _generacion) {

      final restante =
          tiempoTotalReconexion - reloj.elapsed;

      if (restante < const Duration(milliseconds: 400)) {
        break;
      }

      intentoReconexion++;

      estado =
      'Reconectando... (intento $intentoReconexion)';

      notifyListeners();

      final nueva = await _abrirConexion(
        dispositivo.address,
        restante,
      );

      // Si se canceló mientras se intentaba, se cierra lo que
      // haya llegado a conectarse.
      if (generacion != _generacion) {

        await _cerrarConexion(nueva);

        return false;
      }

      if (nueva != null) {

        await _adoptarConexion(
          dispositivo,
          nueva,
        );

        return true;
      }

      final faltan =
          tiempoTotalReconexion - reloj.elapsed;

      if (faltan <= Duration.zero) {
        break;
      }

      await Future.delayed(
        faltan < intervaloReconexion
            ? faltan
            : intervaloReconexion,
      );
    }

    return false;
  }

  // Un intento de conexión limitado en el tiempo.
  Future<BluetoothConnection?> _abrirConexion(
      String direccion,
      Duration limite) async {

    final futuro =
    BluetoothConnection.toAddress(
      direccion,
    );

    try {

      return await futuro.timeout(limite);

    } on TimeoutException {

      // Si más tarde llegara a conectarse, se cierra para no
      // dejar el ESP32 ocupado.
      futuro
          .then((c) => _cerrarConexion(c))
          .catchError((Object _) {});

      return null;

    } catch (e) {

      print(
        'INTENTO DE RECONEXIÓN FALLIDO: $e',
      );

      return null;
    }
  }

  // ==========================================================
  // LATIDO (PING / PONG)
  // ==========================================================

  void _iniciarLatido() {

    _timerLatido?.cancel();

    _timerLatido = null;

    if (!enviarLatido) {
      return;
    }

    _ultimoDatoRecibido = DateTime.now();

    _esp32RespondePong = false;

    _timerLatido = Timer.periodic(
      intervaloLatido,
          (_) => _latido(),
    );
  }

  void _detenerLatido() {

    _timerLatido?.cancel();

    _timerLatido = null;
  }

  void _latido() {

    if (!conectado || connection == null) {
      return;
    }

    // Si el ESP32 ya demostró que responde PONG y ahora hay
    // silencio total, la conexión está muerta.
    if (_esp32RespondePong &&
        DateTime.now().difference(_ultimoDatoRecibido) >
            tiempoSinRespuesta) {

      print(
        'BLUETOOTH CLÁSICO: SIN RESPUESTA DEL ESP32',
      );

      _alPerderConexion();

      return;
    }

    unawaited(
      enviarComando('PING\n'),
    );
  }

  // ==========================================================
  // RECIBIR DATOS DEL ESP32
  // ==========================================================

  String bufferBluetooth = '';

  void recibirDatos(Uint8List data) {

    _ultimoDatoRecibido = DateTime.now();

    final texto =
    String.fromCharCodes(data);

    bufferBluetooth += texto;

    while (bufferBluetooth.contains('\n')) {

      final indice =
      bufferBluetooth.indexOf('\n');

      final mensaje =
      bufferBluetooth
          .substring(0, indice)
          .trim();

      bufferBluetooth =
          bufferBluetooth.substring(
            indice + 1,
          );

      if (mensaje.isNotEmpty) {

        procesarMensajeBluetooth(
          mensaje,
        );
      }
    }
  }

  // ==========================================================
  // PROCESAR MENSAJE RECIBIDO DEL ESP32
  // ==========================================================

  void procesarMensajeBluetooth(String mensaje) {

    print(
      'ESP32 → $mensaje',
    );

    // Respuesta al latido (PING). Solo la envía un ESP32 con el
    // código opcional de latido.
    if (mensaje == 'PONG') {

      _esp32RespondePong = true;

      return;
    }

    // ========================================================
    // ESTADO DE MÓDULO
    //
    // MODULE:1:DI:4
    // MODULE:2:DO:4
    // MODULE:3:AI:2
    // MODULE:4:OFF
    // ========================================================

    if (mensaje.startsWith('MODULE:')) {

      final partes =
      mensaje.split(':');

      if (partes.length >= 3) {

        final numero =
        int.tryParse(partes[1]);

        if (numero == null ||
            numero < 1 ||
            numero > 4) {
          return;
        }

        final modulo =
        modulos[numero - 1];

        if (partes[2] == 'OFF') {

          modulo.conectado = false;
          modulo.tipo = 'NONE';
          modulo.cantidadPines = 0;
          modulo.valores = [];

        } else if (partes.length >= 4) {

          modulo.conectado = true;

          modulo.tipo =
          partes[2];

          modulo.cantidadPines =
              int.tryParse(partes[3]) ?? 0;

          modulo.valores =
              List.filled(
                modulo.cantidadPines,
                0.0,
              );
        }

        notifyListeners();
      }

      return;
    }

    // ========================================================
    // ESTADO DE PIN
    //
    // PIN:1:1:1
    // PIN:2:3:0
    // PIN:3:1:2.45
    // ========================================================

    if (mensaje.startsWith('PIN:')) {

      final partes =
      mensaje.split(':');

      if (partes.length >= 4) {

        final numeroModulo =
        int.tryParse(partes[1]);

        final numeroPin =
        int.tryParse(partes[2]);

        final valor =
        double.tryParse(partes[3]);

        if (numeroModulo == null ||
            numeroPin == null ||
            valor == null) {
          return;
        }

        if (numeroModulo < 1 ||
            numeroModulo > 4) {
          return;
        }

        final modulo =
        modulos[numeroModulo - 1];

        if (numeroPin < 1 ||
            numeroPin > modulo.cantidadPines) {
          return;
        }

        modulo.valores[numeroPin - 1] =
            valor;

        notifyListeners();
      }

      return;
    }

  }

  // ==========================================================
  // ENVIAR COMANDO
  // ==========================================================

  Future<void> enviarComando(String comando) async {

    final con = connection;

    if (!conectado ||
        con == null) {

      return;
    }

    if (!comando.endsWith('\n')) {

      comando += '\n';
    }

    try {

      con.output.add(
        Uint8List.fromList(
          comando.codeUnits,
        ),
      );

      await con.output.allSent;

    } catch (e) {

      // Un error al enviar indica que la conexión se cortó.
      print(
        'ERROR AL ENVIAR POR BLUETOOTH: $e',
      );

      _alPerderConexion();
    }
  }

  // ==========================================================
// SOLICITAR INFORMACIÓN DE LOS MÓDULOS
// ==========================================================

  Future<void> solicitarModulos() async {

    await enviarComando(
      'GET_MODULES\n',
    );
  }


  // ==========================================================
  // CAMBIAR ESTADO DE UNA SALIDA DIGITAL
  // ==========================================================

  Future<void> cambiarPinDigital(
      int modulo,
      int pin,
      bool encender) async {

    // Los puertos deshabilitados (2 y 3 de los módulos DO) nunca
    // reciben órdenes.
    if (!puertoHabilitado(modulo, pin)) {
      return;
    }

    // El ESP32 traduce el modulo (1..4) a su direccion I2C
    // (0x08..0x0B) y el pin (1..4) a un bit de la salida.
    // Luego confirma con "PIN:modulo:pin:valor", que es lo que
    // actualiza el estado mostrado en pantalla.
    await enviarComando(
      'SET:$modulo:$pin:${encender ? 1 : 0}\n',
    );
  }

  // ==========================================================
  // DESCONECTAR (manual)
  // ==========================================================

  Future<void> desconectar() async {

    // Cancela cualquier reconexión que estuviera en curso.
    _generacion++;

    reconectando = false;

    intentoReconexion = 0;

    await discoverySubscription?.cancel();

    discoverySubscription = null;

    esp32 = null;

    conectado = false;

    bufferBluetooth = '';

    estado = 'No conectado';

    notifyListeners();

    await _liberarConexion();
  }
}

// ============================================================
// NAVEGACIÓN ENTRE PANTALLAS
//
// - Inicio -> herramienta: se abre encima del inicio.
// - Herramienta -> herramienta: se reemplaza (nunca se apilan),
//   así "volver" siempre regresa a la pantalla de inicio.
// - Se bloquean los toques repetidos mientras dura la
//   transición, y nunca existen dos pantallas de Diseño o de
//   Programación al mismo tiempo (eso causaba el error rojo
//   "_elements.contains(element)").
// ============================================================
class AppNav {
  AppNav._();

  // Cantidad de pantallas de Diseño/Programación que existen
  // ahora mismo (las que comparten un controlador NodeFlow).
  static int herramientasVivas = 0;

  static bool _ocupado = false;

  static void _bloquear([int milisegundos = 450]) {
    _ocupado = true;
    Future.delayed(Duration(milliseconds: milisegundos), () {
      _ocupado = false;
    });
  }

  static Route<void> _rutaInstantanea(Widget pantalla) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => pantalla,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  // Abre una pantalla desde el inicio.
  static void abrir(BuildContext context, Widget pantalla) {
    if (_ocupado || herramientasVivas > 0) {
      return;
    }
    _bloquear();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => pantalla),
    );
  }

  // Vuelve a la pantalla de inicio desde cualquier herramienta.
  static void irAInicio(BuildContext context) {
    if (_ocupado) {
      return;
    }
    _bloquear();
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
  }

  // Cambia de una herramienta a otra (Diseño, Programación por
  // bloques, Monitoreo) dejando solamente el inicio debajo.
  static Future<void> cambiarA(
      BuildContext context,
      Widget pantalla,
      ) async {
    if (_ocupado) {
      return;
    }
    _ocupado = true;
    final navigator = Navigator.of(context);
    try {
      // 1) Se elimina la pantalla actual y queda una en blanco.
      navigator.pushAndRemoveUntil(
        _rutaInstantanea(const _PantallaEnBlanco()),
            (ruta) => ruta.isFirst,
      );
      // 2) Se espera a que la pantalla anterior se destruya por
      //    completo antes de crear la nueva.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // 3) Se abre la nueva pantalla.
      navigator.pushReplacement(_rutaInstantanea(pantalla));
    } finally {
      _bloquear(250);
    }
  }
}

// ============================================================
// CÍRCULO DE ESTADO DE CONEXIÓN (verde = conectado, rojo = no)
// ============================================================
class PuntoEstado extends StatelessWidget {
  final bool conectado;
  final double tamano;

  // true mientras se intenta reconectar (se muestra en naranja).
  final bool reconectando;

  const PuntoEstado({
    super.key,
    required this.conectado,
    this.tamano = 16,
    this.reconectando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: conectado
            ? Colors.green
            : (reconectando ? Colors.orange : Colors.red),
      ),
    );
  }
}

class _PantallaEnBlanco extends StatelessWidget {
  const _PantallaEnBlanco();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.white);
  }
}

// ============================================================
// EJECUTOR GLOBAL
//
// Es quien "corre" el sistema (cables de Diseño y Conexiones y
// programa por bloques) y envía las órdenes al ESP32 por
// Bluetooth. Vive fuera de las pantallas, por lo que sigue
// funcionando sin importar la pantalla en la que esté el
// usuario.
//
//  - Comenzar / Parar: botón de Diseño y Conexiones.
//  - Las órdenes se envían en una cola (una cada 40 ms) para no
//    saturar al ESP32 cuando hay muchas salidas o muchos bloques.
//  - Si una orden no se confirma, se reenvía automáticamente.
// ============================================================
class _OrdenEnviada {
  final bool valor;
  final DateTime enviadaEn;
  const _OrdenEnviada(this.valor, this.enviadaEn);
}

// Estado de ejecución de un TON o TOF. Se conserva por separado
// para cada instancia de bloque.
class _EstadoTemporizador {
  Stopwatch? relojConteo;
  bool? entradaAnterior;
  int transcurridoMs = 0;
  bool salida = false;
  int ultimaDecimaNotificada = -1;
  bool? ultimaSalidaNotificada;
}

// Fotografía de las conexiones del programa por bloques, para
// evaluar rápido aunque haya muchos bloques.
class _GrafoPrograma {
  final Map<String, ProgramBlockInstance> bloques = {};
  final Map<String, String> _origenes = {};

  _GrafoPrograma() {
    for (final b in _ProgrammingScreenState._bloquesColocados) {
      bloques[b.id] = b;
    }
    for (final c in _ProgrammingScreenState._flowController.connections) {
      if (!bloques.containsKey(c.sourceNodeId) ||
          !bloques.containsKey(c.targetNodeId)) {
        continue;
      }
      _origenes['${c.targetNodeId}|${c.targetPortId}'] = c.sourceNodeId;
    }
  }

  // Bloque que alimenta una entrada (null = sin cable).
  ProgramBlockInstance? origenDeEntrada(
      ProgramBlockInstance b,
      String puertoId,
      ) {
    final id = _origenes['${b.id}|$puertoId'];
    return id == null ? null : bloques[id];
  }
}

class EjecutorGlobal extends ChangeNotifier {
  EjecutorGlobal._();

  static final EjecutorGlobal instance = EjecutorGlobal._();

  final BluetoothManager bluetooth = BluetoothManager.instance;

  // Estado de los Switch/Botones virtuales (clave -> ON/OFF).
  final Map<String, bool> entradasVirtuales = {};

  // Estado independiente de cada instancia TON/TOF.
  final Map<String, _EstadoTemporizador> _estadosTemporizadores = {};

  // true = el sistema está en marcha (botón Comenzar).
  bool corriendo = false;

  bool _inicializado = false;
  Timer? _timerEvaluacion;
  Timer? _timerCola;

  // Órdenes pendientes ('modulo|puerto' -> valor deseado).
  final Map<String, bool> _cola = {};

  // Última orden enviada a cada salida.
  final Map<String, _OrdenEnviada> _ultimoEnviado = {};

  // Salidas que ha manejado el sistema (se apagan al parar).
  final Set<String> _salidasControladas = {};

  static const Duration _intervaloEvaluacion =
  Duration(milliseconds: 250);
  static const Duration _intervaloEnvio =
  Duration(milliseconds: 40);
  static const Duration _tiempoReintento =
  Duration(milliseconds: 800);

  // Texto mostrado encima del bloque TON/TOF.
  String textoCuentaTemporizador(String bloqueId) {
    final estado = _estadosTemporizadores[bloqueId];
    final segundos = (estado?.transcurridoMs ?? 0) / 1000.0;
    return segundos.toStringAsFixed(1);
  }

  // Reinicia un temporizador cuando se cambia su tiempo configurado.
  void reiniciarTemporizador(String bloqueId) {
    _estadosTemporizadores.remove(bloqueId)?.relojConteo?.stop();
    _notificarBloqueTemporizador(bloqueId);
  }

  // Detener el programa deja todos los temporizadores en cero.
  void _reiniciarTemporizadores() {
    if (_estadosTemporizadores.isEmpty) return;
    final ids = _estadosTemporizadores.keys.toList();
    for (final id in ids) {
      _estadosTemporizadores.remove(id)?.relojConteo?.stop();
      _notificarBloqueTemporizador(id);
    }
  }

  // Solicita al NodeFlow reconstruir únicamente el bloque indicado.
  void _notificarBloqueTemporizador(String bloqueId) {
    try {
      _ProgrammingScreenState._flowController.notifyNodeDataChanged(bloqueId);
    } catch (_) {
      // Puede ocurrir si el bloque se acaba de eliminar o la pantalla
      // todavía no ha terminado de inicializar su controlador.
    }
  }

  // Evalúa la temporización y devuelve el estado de su salida digital.
  bool _evaluarTemporizador(ProgramBlockInstance bloque, bool entrada) {
    final estado = _estadosTemporizadores.putIfAbsent(
      bloque.id,
          () => _EstadoTemporizador(),
    );

    final tiempoConfigurado = bloque.tiempoSegundos;
    if (tiempoConfigurado == null ||
        !tiempoConfigurado.isFinite ||
        tiempoConfigurado < 1 ||
        tiempoConfigurado > 20) {
      final cambio = estado.transcurridoMs != 0 || estado.salida;
      estado.relojConteo?.stop();
      estado
        ..relojConteo = null
        ..entradaAnterior = entrada
        ..transcurridoMs = 0
        ..salida = false;
      if (cambio) _notificarBloqueTemporizador(bloque.id);
      return false;
    }

    final limiteMs = (tiempoConfigurado * 1000).round();
    final entradaAnterior = estado.entradaAnterior;

    if (bloque.definition.id == 'TON') {
      // TON: cuenta mientras la entrada permanezca en ON. Al pasar
      // a OFF, reinicia inmediatamente el tiempo y la salida.
      if (!entrada) {
        estado.relojConteo?.stop();
        estado
          ..relojConteo = null
          ..transcurridoMs = 0
          ..salida = false;
      } else {
        estado.relojConteo ??= Stopwatch()..start();
        if (!estado.relojConteo!.isRunning &&
            estado.transcurridoMs < limiteMs) {
          estado.relojConteo!.start();
        }
        estado.transcurridoMs = estado.relojConteo!
            .elapsedMilliseconds
            .clamp(0, limiteMs)
            .toInt();
        estado.salida = estado.transcurridoMs >= limiteMs;
        if (estado.salida) estado.relojConteo!.stop();
      }
    } else {
      // TOF: la salida se activa inmediatamente con la entrada ON.
      // Cuando la entrada cae a OFF, mantiene la salida durante PT.
      if (entrada) {
        estado.relojConteo?.stop();
        estado
          ..relojConteo = null
          ..transcurridoMs = 0
          ..salida = true;
      } else if (entradaAnterior == true) {
        // Flanco descendente: comienza el retardo a la desconexión.
        estado.relojConteo = Stopwatch()..start();
        estado
          ..transcurridoMs = 0
          ..salida = true;
      } else if (estado.relojConteo != null) {
        final transcurrido = estado.relojConteo!
            .elapsedMilliseconds
            .clamp(0, limiteMs)
            .toInt();
        estado.transcurridoMs = transcurrido;
        estado.salida = transcurrido < limiteMs;
        if (!estado.salida) estado.relojConteo!.stop();
      } else {
        // Si el programa arranca con la entrada en OFF, no se inicia
        // un retardo hasta que exista primero un flanco ON -> OFF.
        estado
          ..transcurridoMs = 0
          ..salida = false;
      }
    }

    estado.entradaAnterior = entrada;

    // La pantalla muestra décimas de segundo. Solo se reconstruye el
    // nodo cuando cambia la cifra mostrada o el estado de su salida.
    final decimaActual = (estado.transcurridoMs / 100).floor();
    if (decimaActual != estado.ultimaDecimaNotificada ||
        estado.salida != estado.ultimaSalidaNotificada) {
      estado
        ..ultimaDecimaNotificada = decimaActual
        ..ultimaSalidaNotificada = estado.salida;
      _notificarBloqueTemporizador(bloque.id);
    }

    return estado.salida;
  }

  // Se llama una sola vez al iniciar la app.
  void inicializar() {
    if (_inicializado) {
      return;
    }
    _inicializado = true;
    bluetooth.addListener(_alCambiarBluetooth);
  }

  void _alCambiarBluetooth() {
    if (corriendo) {
      _evaluar();
    }
    notifyListeners();
  }

  // ==========================================================
  // COMENZAR / PARAR
  // ==========================================================
  // Devuelve un mensaje de error o null si todo salió bien.
  String? iniciar() {
    if (!bluetooth.conectado) {
      return 'Error: El dispositivo no está conectado';
    }
    if (corriendo) {
      return null;
    }
    corriendo = true;
    _reiniciarTemporizadores();
    _cola.clear();
    _ultimoEnviado.clear();
    _salidasControladas.clear();
    _timerEvaluacion?.cancel();
    _timerEvaluacion = Timer.periodic(
      _intervaloEvaluacion,
          (_) => _evaluar(),
    );
    _evaluar();
    notifyListeners();
    return null;
  }

  Future<void> detener() async {
    if (!corriendo) {
      return;
    }
    corriendo = false;
    _timerEvaluacion?.cancel();
    _reiniciarTemporizadores();
    _timerEvaluacion = null;
    _cola.clear();
    _ultimoEnviado.clear();

    // Al parar se apagan las salidas que manejaba el sistema.
    if (bluetooth.conectado) {
      for (final clave in _salidasControladas) {
        final partes = clave.split('|');
        final m = int.tryParse(partes[0]);
        final p = int.tryParse(partes[1]);
        if (m == null || p == null) continue;
        if (m < 1 || m > bluetooth.modulos.length) continue;
        final modulo = bluetooth.modulos[m - 1];
        if (!modulo.conectado || p < 1 || p > modulo.valores.length) {
          continue;
        }
        if (modulo.valores[p - 1] >= 0.5) {
          _cola[clave] = false;
        }
      }
      _arrancarCola();
    }
    _salidasControladas.clear();
    notifyListeners();
  }

  // ==========================================================
  // SWITCH / BOTÓN VIRTUAL
  // ==========================================================
  void cambiarEntradaVirtual(String clave, bool encendido) {
    entradasVirtuales[clave] = encendido;
    if (corriendo) {
      _evaluar();
    }
    notifyListeners();
  }

  // ==========================================================
  // LECTURA DE ESTADOS
  // ==========================================================
  // Valor actual de un puerto de un módulo (null = sin datos).
  double? valorFisico(AsignacionPin a) {
    if (!bluetooth.conectado) return null;
    if (a.modulo < 1 || a.modulo > bluetooth.modulos.length) {
      return null;
    }
    final modulo = bluetooth.modulos[a.modulo - 1];
    if (!modulo.conectado) return null;
    if (a.puerto < 1 || a.puerto > modulo.valores.length) {
      return null;
    }
    return modulo.valores[a.puerto - 1];
  }

  // Texto de la medida analógica de un componente (por ejemplo
  // "1.23 bar"). Devuelve null si el componente no tiene salida
  // analógica, y "--" si todavía no hay dato.
  String? textoMedidaAnalogica(PlacedComponent comp) {
    for (final pin in comp.outputs) {
      if (pin.type != PinType.analogOutput) continue;

      final asignacion = comp.asignaciones[pin.id];
      final voltaje =
      asignacion == null ? null : valorFisico(asignacion);

      if (voltaje == null) return '--';

      if (comp.component.id == kIdSensorPresion) {
        return '${comp.presionDe(voltaje).toStringAsFixed(2)} bar';
      }

      return '${voltaje.toStringAsFixed(2)} V';
    }
    return null;
  }

  // Componente con salida analógica (p. ej. el sensor de presión)
  // asignado a ese puerto, o null si no hay ninguno.
  PlacedComponent? componenteAnalogicoEnPuerto(int modulo, int puerto) {
    for (final comp in _DesignScreenState._componentesPersistentes) {
      for (final pin in comp.outputs) {
        if (pin.type != PinType.analogOutput) continue;
        final a = comp.asignaciones[pin.id];
        if (a != null && a.modulo == modulo && a.puerto == puerto) {
          return comp;
        }
      }
    }
    return null;
  }

  // Unidad del valor final de un puerto: 'bar' si tiene el sensor de
  // presión, 'V' en los demás casos.
  String unidadDePuerto(int modulo, int puerto) {
    return componenteAnalogicoEnPuerto(modulo, puerto)?.unidadMedida ??
        'V';
  }

  // Valor FINAL de un puerto analógico (no el voltaje de la app):
  // si el puerto tiene el sensor de presión, devuelve bares usando su
  // calibración. Devuelve null si no hay lectura.
  double? valorFinalDePuerto(int modulo, int puerto) {
    final voltaje = valorFisico(
      AsignacionPin(modulo: modulo, puerto: puerto),
    );
    if (voltaje == null) return null;

    final comp = componenteAnalogicoEnPuerto(modulo, puerto);
    return comp == null ? voltaje : comp.convertirMedida(voltaje);
  }

  // Estado digital de un pin (físico o virtual).
  bool estadoDigitalDe(PlacedComponent comp, String pinId) {
    final asignacion = comp.asignaciones[pinId];
    if (asignacion != null) {
      return (valorFisico(asignacion) ?? 0) >= 0.5;
    }
    return entradasVirtuales['${comp.instanceId}|$pinId'] ?? false;
  }

  // Estado de un pin virtual de entrada (LED): sigue al bloque V DO
  // del programa o al cable de Diseño y Conexiones.
  bool estadoEntradaVirtual(PlacedComponent comp, PinModel pin) {
    if (!corriendo) return false;
    final clave = '${comp.instanceId}|${pin.id}';
    final grafo = _GrafoPrograma();
    for (final b in grafo.bloques.values) {
      if (b.definition.id == 'V_DO' &&
          b.varClave == clave &&
          grafo.origenDeEntrada(b, 'in_1') != null) {
        return _evaluarBloque(
          grafo,
          b,
          <String, bool>{},
          <String>{},
        );
      }
    }
    for (final c in _DesignScreenState._flowController.connections) {
      if (c.targetNodeId != comp.instanceId ||
          c.targetPortId != pin.id) {
        continue;
      }
      for (final origen in _DesignScreenState._componentesPersistentes) {
        if (origen.instanceId == c.sourceNodeId) {
          return estadoDigitalDe(origen, c.sourcePortId);
        }
      }
    }
    return false;
  }

  bool estadoSalidaVirtual(VariableMonitoreo v) {
    if (v.componente == null || v.pin == null) return false;
    return estadoEntradaVirtual(v.componente!, v.pin!);
  }

  // ON/OFF de un componente colocado en Diseño y Conexiones.
  bool estadoComponente(PlacedComponent comp) {
    final pines = <PinModel>[...comp.inputs, ...comp.outputs];
    for (final pin in pines) {
      if (pin.type != PinType.digitalInput &&
          pin.type != PinType.digitalOutput) {
        continue;
      }
      final asignacion = comp.asignaciones[pin.id];
      if (asignacion != null) {
        if ((valorFisico(asignacion) ?? 0) >= 0.5) return true;
        continue;
      }
      if (comp.component.category != 'Otros') continue;
      if (pin.type == PinType.digitalOutput) {
        // Switch / Botón virtual.
        if (entradasVirtuales['${comp.instanceId}|${pin.id}'] ?? false) {
          return true;
        }
      } else {
        // LED virtual.
        if (estadoEntradaVirtual(comp, pin)) return true;
      }
    }
    return false;
  }

  // ==========================================================
  // EVALUACIÓN DEL PROGRAMA POR BLOQUES
  //
  // Se evalúan DI, V DI, AND, OR, NOT, XOR, NAND, NOR, TON, TOF,
  // DO y V DO. Las comparaciones >= y < leen un bloque AI y usan
  // el valor final, por ejemplo bar.
  // ==========================================================
  bool _entradaBloque(
      _GrafoPrograma g,
      ProgramBlockInstance b,
      String puertoId,
      Map<String, bool> memo,
      Set<String> pila,
      ) {
    final origen = g.origenDeEntrada(b, puertoId);
    if (origen == null) return false;
    return _evaluarBloque(g, origen, memo, pila);
  }

  // Valor de una entrada digital física asignada a un bloque DI.
  bool _leerDIProgramado(ProgramBlockInstance b) {
    if (!bluetooth.conectado || !b.asignado) return false;
    if (b.modulo! < 1 || b.modulo! > bluetooth.modulos.length) {
      return false;
    }
    final modulo = bluetooth.modulos[b.modulo! - 1];
    if (!modulo.conectado || modulo.tipo != 'DI') return false;
    if (b.puerto! < 1 || b.puerto! > modulo.valores.length) {
      return false;
    }
    return modulo.valores[b.puerto! - 1] >= 0.5;
  }

  // Valor final (bar, V...) que entrega un bloque AI asignado.
  double? _valorAnalogicoBloque(ProgramBlockInstance b) {
    if (b.definition.id != 'IN_AI' || !b.asignado) return null;
    if (!bluetooth.conectado) return null;
    if (b.modulo! < 1 || b.modulo! > bluetooth.modulos.length) {
      return null;
    }
    final modulo = bluetooth.modulos[b.modulo! - 1];
    if (!modulo.conectado || modulo.tipo != 'AI') return null;
    if (b.puerto! < 1 || b.puerto! > modulo.valores.length) return null;
    return valorFinalDePuerto(b.modulo!, b.puerto!);
  }

  bool _evaluarBloque(
      _GrafoPrograma g,
      ProgramBlockInstance b,
      Map<String, bool> memo,
      Set<String> pila,
      ) {
    final guardado = memo[b.id];
    if (guardado != null) return guardado;

    // Protección contra lazos (cables en círculo).
    if (pila.contains(b.id)) return false;
    pila.add(b.id);

    final id = b.definition.id;
    bool r = false;

    if (id == 'IN_DI') {
      r = _leerDIProgramado(b);
    } else if (id == 'V_DI') {
      r = b.varClave != null && (entradasVirtuales[b.varClave!] ?? false);
    } else if (id == 'NOT') {
      r = !_entradaBloque(g, b, 'in_1', memo, pila);
    } else if (id == 'OUT_DO' || id == 'V_DO') {
      r = _entradaBloque(g, b, 'in_1', memo, pila);
    } else if (id == 'AND' ||
        id == 'OR' ||
        id == 'XOR' ||
        id == 'NAND' ||
        id == 'NOR') {
      final a = _entradaBloque(g, b, 'in_1', memo, pila);
      final c = _entradaBloque(g, b, 'in_2', memo, pila);
      if (id == 'AND') r = a && c;
      if (id == 'OR') r = a || c;
      if (id == 'XOR') r = a != c;
      if (id == 'NAND') r = !(a && c);
      if (id == 'NOR') r = !(a || c);
    } else if (id == 'MAYOR_IGUAL' || id == 'MENOR') {
      // Comparación con el valor FINAL (por ejemplo bar para el
      // sensor de presión) y el valor configurado en el bloque.
      final origen = g.origenDeEntrada(b, 'in_1');
      final valor = origen == null ? null : _valorAnalogicoBloque(origen);
      if (valor != null && b.umbral != null) {
        r = id == 'MAYOR_IGUAL' ? valor >= b.umbral! : valor < b.umbral!;
      }
    } else if (id == 'TON' || id == 'TOF') {
      final entrada = _entradaBloque(g, b, 'in_1', memo, pila);
      r = _evaluarTemporizador(b, entrada);
    }

    pila.remove(b.id);
    memo[b.id] = r;
    return r;
  }

  // ==========================================================
  // CICLO PRINCIPAL
  // ==========================================================
  void _evaluar() {
    if (!corriendo) return;
    if (!bluetooth.conectado) {
      _cola.clear();
      _ultimoEnviado.clear();
      _reiniciarTemporizadores();
      return;
    }
    try {
      final grafo = _GrafoPrograma();
      final reservadas = _ejecutarPrograma(grafo);
      _sincronizarSalidas(reservadas);
    } catch (e) {
      print('ERROR EJECUTOR: $e');
    }
  }

  // Envía a los módulos DO el resultado de cada bloque DO asignado.
  // Devuelve las salidas que maneja el programa.
  Set<String> _ejecutarPrograma(_GrafoPrograma g) {
    final reservadas = <String>{};
    final memo = <String, bool>{};

    // Elimina estados de temporizadores cuyos bloques ya no existen.
    final temporizadoresPresentes = g.bloques.values
        .where((b) => b.definition.id == 'TON' || b.definition.id == 'TOF')
        .map((b) => b.id)
        .toSet();
    final temporizadoresEliminados = _estadosTemporizadores.keys
        .where((id) => !temporizadoresPresentes.contains(id))
        .toList();
    for (final id in temporizadoresEliminados) {
      _estadosTemporizadores.remove(id)?.relojConteo?.stop();
    }

    // Ejecuta todos los TON/TOF en cada ciclo, incluso si su salida
    // aún no está conectada a un bloque DO.
    for (final bloque in g.bloques.values) {
      if (bloque.definition.id == 'TON' ||
          bloque.definition.id == 'TOF') {
        _evaluarBloque(g, bloque, memo, <String>{});
      }
    }

    // Agrupa los bloques DO que comparten una misma salida física.
    // Si varias instancias DO controlan el mismo puerto, se aplica OR:
    // el puerto queda ON cuando al menos uno de los bloques conectados
    // entrega ON; solo queda OFF cuando todos entregan OFF. Así se evita
    // enviar órdenes opuestas repetidamente al mismo pin.
    final salidasPorPuerto = <String, bool>{};

    for (final b in g.bloques.values) {
      if (b.definition.id != 'OUT_DO' || !b.asignado) continue;

      // Sin cable en su entrada: no se toca la salida desde este bloque.
      if (g.origenDeEntrada(b, 'in_1') == null) continue;

      if (b.modulo! < 1 || b.modulo! > bluetooth.modulos.length) {
        continue;
      }
      final modulo = bluetooth.modulos[b.modulo! - 1];
      if (!modulo.conectado || modulo.tipo != 'DO') continue;
      if (b.puerto! < 1 || b.puerto! > modulo.valores.length) {
        continue;
      }
      if (!modulo.puertoHabilitado(b.puerto!)) continue;

      final clave = '${b.modulo}|${b.puerto}';
      reservadas.add(clave);

      final deseado = _evaluarBloque(g, b, memo, <String>{});
      salidasPorPuerto.update(
        clave,
            (anterior) => anterior || deseado,
        ifAbsent: () => deseado,
      );
    }

    for (final entrada in salidasPorPuerto.entries) {
      final partes = entrada.key.split('|');
      final modulo = int.tryParse(partes[0]);
      final puerto = int.tryParse(partes[1]);
      if (modulo == null || puerto == null) continue;
      _pedirSalida(modulo, puerto, entrada.value);
    }

    return reservadas;
  }

  // Recorre los cables de Diseño y Conexiones. Si el destino es un
  // pin asignado a un puerto de un módulo DO, le envía el estado
  // del origen (Switch/Botón virtual o entrada física).
  void _sincronizarSalidas(Set<String> reservadas) {
    for (final c in _DesignScreenState._flowController.connections) {
      PlacedComponent? origen;
      PlacedComponent? destino;
      for (final comp in _DesignScreenState._componentesPersistentes) {
        if (comp.instanceId == c.sourceNodeId) origen = comp;
        if (comp.instanceId == c.targetNodeId) destino = comp;
      }
      if (origen == null || destino == null) continue;

      final asigDestino = destino.asignaciones[c.targetPortId];
      if (asigDestino == null) continue;

      final asigOrigen = origen.asignaciones[c.sourcePortId];
      if (asigOrigen != null && valorFisico(asigOrigen) == null) {
        // Origen físico sin datos válidos.
        continue;
      }

      if (asigDestino.modulo < 1 ||
          asigDestino.modulo > bluetooth.modulos.length) {
        continue;
      }
      final modulo = bluetooth.modulos[asigDestino.modulo - 1];
      if (!modulo.conectado || modulo.tipo != 'DO') continue;
      if (asigDestino.puerto < 1 ||
          asigDestino.puerto > modulo.valores.length) {
        continue;
      }
      if (!modulo.puertoHabilitado(asigDestino.puerto)) continue;

      final clave = '${asigDestino.modulo}|${asigDestino.puerto}';

      // Si el programa por bloques maneja esa salida, tiene prioridad.
      if (reservadas.contains(clave)) continue;

      final deseado = estadoDigitalDe(origen, c.sourcePortId);
      _pedirSalida(asigDestino.modulo, asigDestino.puerto, deseado);
    }
  }

  // ==========================================================
  // COLA DE ÓRDENES AL ESP32
  // ==========================================================
  void _pedirSalida(int m, int p, bool deseado) {
    final modulo = bluetooth.modulos[m - 1];
    if (!modulo.puertoHabilitado(p)) return;
    final clave = '$m|$p';
    _salidasControladas.add(clave);

    final actual = modulo.valores[p - 1] >= 0.5;
    if (actual == deseado) {
      // Ya está como se desea: no hay nada que enviar.
      _ultimoEnviado.remove(clave);
      _cola.remove(clave);
      return;
    }

    // Se espera la confirmación del ESP32; si no llega, se reenvía.
    final previa = _ultimoEnviado[clave];
    if (previa != null &&
        previa.valor == deseado &&
        DateTime.now().difference(previa.enviadaEn) < _tiempoReintento) {
      return;
    }

    if (_cola[clave] == deseado) return;
    _cola[clave] = deseado;
    _arrancarCola();
  }

  void _arrancarCola() {
    _timerCola ??= Timer.periodic(
      _intervaloEnvio,
          (_) => _enviarSiguiente(),
    );
  }

  void _enviarSiguiente() {
    if (!bluetooth.conectado) {
      _cola.clear();
    }
    if (_cola.isEmpty) {
      _timerCola?.cancel();
      _timerCola = null;
      return;
    }
    final clave = _cola.keys.first;
    final valor = _cola.remove(clave) ?? false;
    final partes = clave.split('|');
    final m = int.tryParse(partes[0]);
    final p = int.tryParse(partes[1]);
    if (m == null || p == null) return;

    _ultimoEnviado[clave] = _OrdenEnviada(valor, DateTime.now());
    bluetooth.cambiarPinDigital(m, p, valor).catchError((Object e) {
      print('ERROR AL ENVIAR ORDEN: $e');
    });
  }
}

// ============================================================
// COMPATIBILIDAD ENTRE DISEÑO Y CONEXIONES Y PROGRAMACIÓN
//
// Una conexión física entre dos puertos (por ejemplo Módulo 1
// Puerto 1 -> Módulo 2 Puerto 2) no puede existir a la vez en
// Diseño y Conexiones y en la Programación por bloques (ni
// directamente ni pasando por bloques como NOT, AND, etc.),
// porque el sistema no funcionaría. La reutilización de un mismo
// DI entre varios bloques DI o de un DO entre varios bloques DO del
// propio programa sí está permitida.
//
// Devuelve un mensaje si hay conflicto, o null si todo está bien.
// Los parámetros opcionales permiten probar una conexión nueva
// antes de crearla.
// ============================================================
String? conflictoDisenoProgramacion({
  PlacedComponent? disenoOrigen,
  String? disenoOrigenPin,
  PlacedComponent? disenoDestino,
  String? disenoDestinoPin,
  ProgramBlockInstance? programaOrigen,
  ProgramBlockInstance? programaDestino,
}) {
  // ---------------- CABLES DE DISEÑO Y CONEXIONES ----------------
  final componentes = <String, PlacedComponent>{
    for (final c in _DesignScreenState._componentesPersistentes)
      c.instanceId: c,
  };
  final paresDiseno = <String, String>{};

  void agregarCable(
      PlacedComponent? o,
      String? po,
      PlacedComponent? d,
      String? pd,
      ) {
    if (o == null || d == null || po == null || pd == null) return;
    final ao = o.asignaciones[po];
    final ad = d.asignaciones[pd];
    if (ao == null || ad == null) return;
    paresDiseno['${ao.modulo}:${ao.puerto}>${ad.modulo}:${ad.puerto}'] =
    'Módulo ${ao.modulo} Puerto ${ao.puerto} → '
        'Módulo ${ad.modulo} Puerto ${ad.puerto}';
  }

  for (final c in _DesignScreenState._flowController.connections) {
    agregarCable(
      componentes[c.sourceNodeId],
      c.sourcePortId,
      componentes[c.targetNodeId],
      c.targetPortId,
    );
  }
  agregarCable(
    disenoOrigen,
    disenoOrigenPin,
    disenoDestino,
    disenoDestinoPin,
  );

  if (paresDiseno.isEmpty) return null;

  // ---------------- CONEXIONES DEL PROGRAMA ----------------
  final bloques = <String, ProgramBlockInstance>{
    for (final b in _ProgrammingScreenState._bloquesColocados)
      if (b.espejoDe == null) b.id: b,
  };
  // destino -> lista de bloques que lo alimentan
  final alimentadores = <String, List<String>>{};

  void agregarEnlace(String origen, String destino) {
    alimentadores.putIfAbsent(destino, () => <String>[]).add(origen);
  }

  for (final c in _ProgrammingScreenState._flowController.connections) {
    if (bloques.containsKey(c.sourceNodeId) &&
        bloques.containsKey(c.targetNodeId)) {
      agregarEnlace(c.sourceNodeId, c.targetNodeId);
    }
  }
  if (programaOrigen != null && programaDestino != null) {
    agregarEnlace(programaOrigen.id, programaDestino.id);
  }

  // Por cada salida DO asignada se buscan (hacia atrás) las
  // entradas DI asignadas que la alimentan.
  for (final salida in bloques.values) {
    if (salida.definition.id != 'OUT_DO' || !salida.asignado) continue;

    final visitados = <String>{};
    final pendientes = <String>[salida.id];
    while (pendientes.isNotEmpty) {
      final id = pendientes.removeLast();
      if (!visitados.add(id)) continue;
      final b = bloques[id];
      if (b == null) continue;

      if (b.definition.id == 'IN_DI' && b.asignado) {
        final clave =
            '${b.modulo}:${b.puerto}>${salida.modulo}:${salida.puerto}';
        final texto = paresDiseno[clave];
        if (texto != null) {
          return 'Conexión incompatible: $texto ya está conectado en '
              'Diseño y Conexiones, por lo que no puede conectarse '
              'también en la programación por bloques.';
        }
      }
      pendientes.addAll(alimentadores[id] ?? const <String>[]);
    }
  }
  return null;
}

class AutomatizacionApp extends StatelessWidget {
  const AutomatizacionApp({super.key});

  // Permite mostrar avisos (por ejemplo "Reconectando...") sin
  // importar en qué pantalla esté el usuario.
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
  GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Automatización',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const HomeScreen(),
    );
  }
}

class Responsive {
  static double width(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  // 2560 px es el ancho de diseño de la tablet
  static double scale(BuildContext context) {
    return width(context) / 2560.0;
  }

  static double w(BuildContext context, double value) {
    return value * scale(context);
  }
}


// ============================================================
// CABECERA DE CADA PÁGINA
// ============================================================

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final bool showSettings;
  final bool showExit;

  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.showSettings = false,
    this.showExit = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Altura proporcional a la pantalla
    final headerHeight = size.height * 0.105;

    // Límites para evitar que sea demasiado grande o pequeña
    final finalHeaderHeight =
    headerHeight.clamp(65.0, 110.0);

    final iconSize =
    (finalHeaderHeight * 0.50).clamp(30.0, 55.0);

    final titleSize =
    (finalHeaderHeight * 0.30).clamp(18.0, 32.0);

    final horizontalPadding =
    (size.width * 0.015).clamp(12.0, 30.0);

    return Container(
      height: finalHeaderHeight,

      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.black,
            width: 1.5,
          ),
        ),
      ),

      child: Row(
        children: [

          // BOTÓN IZQUIERDO
          SizedBox(
            width: (size.width * 0.04).clamp(55.0, 100.0),

            child: Align(
              alignment: Alignment.centerLeft,

              child: IconButton(
                iconSize: iconSize,

                padding: EdgeInsets.only(
                  left: horizontalPadding,
                ),

                icon: Icon(
                  showExit
                      ? Icons.logout
                      : Icons.arrow_back,

                  color: Colors.black,
                ),

                onPressed: onBack ??
                    (showExit
                        ? () {
                      SystemNavigator.pop();
                    }
                        : null),
              ),
            ),
          ),

          // TÍTULO
          Expanded(
            child: Center(
              child: Text(
                title,

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // ESPACIO DERECHO
          SizedBox(
            width: (size.width * 0.04).clamp(55.0, 100.0),

            child: showSettings
                ? Align(
              alignment: Alignment.centerRight,

              child: IconButton(
                iconSize: iconSize,

                padding: EdgeInsets.only(
                  right: horizontalPadding,
                ),

                icon: const Icon(
                  Icons.settings_outlined,
                  color: Colors.black,
                ),

                onPressed: () {
                  AppNav.abrir(
                    context,
                    const AjustesScreen(),
                  );
                },
              ),
            )
                : null,
          ),
        ],
      ),
    );
  }
}


// ============================================================
// PANTALLA DE INICIO V2
// ============================================================


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // CABECERA
            // ==================================================
            AnimatedBuilder(
              animation: AjustesApp.instance,
              builder: (context, _) {
                return AppHeader(
                  title:
                  'Bienvenido, ${AjustesApp.instance.nombreUsuario}',
                  showExit: true,
                  showSettings: true,
                );
              },
            ),

            // ==================================================
            // BOTONES PRINCIPALES
            // ==================================================
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 45),
                    vertical: Responsive.w(context, 35),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ========================================
                      // PRIMERA FILA
                      // ========================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ------------------------------
                          // BLUETOOTH
                          // ------------------------------
                          HomeButton(
                            icon: Icons.bluetooth,
                            label: 'Bluetooth',
                            onPressed: () {
                              AppNav.abrir(
                                context,
                                const BluetoothScreen(),
                              );
                            },
                          ),

                          SizedBox(
                            width: Responsive.w(context, 80),
                          ),

                          // ------------------------------
                          // PRUEBA DE PINES
                          // ------------------------------
                          HomeButton(
                            icon: Icons.settings_input_component,
                            label: 'Prueba de pines',
                            onPressed: () {
                              AppNav.abrir(
                                context,
                                const PinTestScreen(),
                              );
                            },
                          ),

                          SizedBox(
                            width: Responsive.w(context, 80),
                          ),

                          // ------------------------------
                          // ESCANEAR QR
                          // ------------------------------
                          HomeButton(
                            icon: Icons.qr_code_2,
                            label: 'Escanear QR',
                            onPressed: () {
                              AppNav.abrir(
                                context,
                                const QRScannerScreen(),
                              );
                            },
                          ),
                        ],
                      ),

                      SizedBox(
                        height: Responsive.w(context, 55),
                      ),

                      // ========================================
                      // SEGUNDA FILA
                      // ========================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ------------------------------
                          // DISEÑO Y CONEXIONES
                          // ------------------------------
                          HomeButton(
                            icon: Icons.touch_app_outlined,
                            label: 'Diseño y conexiones',
                            onPressed: () {
                              AppNav.abrir(
                                context,
                                const DesignScreen(),
                              );
                            },
                          ),

                          SizedBox(
                            width: Responsive.w(context, 80),
                          ),

                          // ------------------------------
                          // PROGRAMACIÓN POR BLOQUES
                          // ------------------------------
                          HomeButton(
                            icon: Icons.code,
                            label: 'Programación por bloques',
                            onPressed: () {
                              AppNav.abrir(
                                context,
                                const ProgrammingScreen(),
                              );
                            },
                          ),

                          SizedBox(
                            width: Responsive.w(context, 80),
                          ),

                          // ------------------------------
                          // MONITOREO
                          // ------------------------------
                          HomeButton(
                            icon: Icons.monitor_heart_outlined,
                            label: 'Monitoreo síncrono',
                            onPressed: () {
                              AppNav.abrir(
                                context,
                                const MonitoreoScreen(),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// BOTÓN DE LA PANTALLA DE INICIO
// ============================================================


class HomeButton extends StatelessWidget {

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const HomeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {

    final scale = Responsive.scale(context).clamp(0.70, 1.20);

    return SizedBox(
      width: 220 * scale,
      height: 165 * scale,

      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: Colors.black,
            width: 2,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),

          padding: EdgeInsets.all(15 * scale),
        ),

        onPressed: onPressed,

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              icon,
              size: 75 * scale,
              color: Colors.black,
            ),

            SizedBox(
              height: 10 * scale,
            ),

            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16 * scale,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// PANTALLA DE ESCANEO DE QR
// ============================================================


class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() =>
      _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {

  final MobileScannerController scannerController =
  MobileScannerController();

  String qrDetectado = '';
  String estadoQR = 'Apunta la cámara al QR';

  // Información del QR leído.
  String? qrValue;

  // Link que abre el botón "Link para más información": el del QR
  // que se escaneó (un componente con varios QR tiene varios links).
  String? qrUrl;

  // Ficha del componente al que corresponde el QR (null = QR no adecuado).
  FichaComponente? fichaQR;

  // Componente de la app (para añadirlo a Diseño y conexiones).
  ComponentModel? get _modeloQR {
    final id = fichaQR?.idRegistro;
    return id == null ? null : componentRegistry[id];
  }

  // Evita procesar muchas veces el mismo QR.
  bool procesandoQR = false;

  // ==========================================================
  // PROCESAR QR
  // ==========================================================

  void procesarQR(BarcodeCapture capture) {
    if (procesandoQR) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final String? codigo = barcode.rawValue;

      if (codigo == null || codigo.isEmpty) {
        continue;
      }

      print('==============================');
      print('QR DETECTADO: $codigo');
      print('==============================');

      final String? url = _obtenerURL(codigo);

      print('URL OBTENIDA: $url');

      final resultadoQR = CatalogoComponentes.buscar(codigo);
      setState(() {
        procesandoQR = true;
        qrDetectado = codigo;
        qrValue = codigo;
        fichaQR = resultadoQR?.ficha;
        qrUrl = resultadoQR?.link;
        estadoQR = resultadoQR != null
            ? 'QR detectado correctamente'
            : 'QR detectado pero no adecuado';
      });

      Future.delayed(
        const Duration(milliseconds: 1200),
            () {
          if (mounted) {
            setState(() {
              procesandoQR = false;
            });
          }
        },
      );

      break;
    }
  }

  // ==========================================================
  // OBTENER URL DEL QR
  // ==========================================================

  String? _obtenerURL(String valor) {
    final texto = valor.trim();

    final Uri? uri = Uri.tryParse(texto);

    if (uri == null) {
      return null;
    }

    if (uri.hasScheme &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https')) {
      return texto;
    }

    return null;
  }

  // ==========================================================
  // ABRIR INFORMACIÓN DEL QR
  // ==========================================================

  Future<void> abrirInformacion() async {
    print('BOTÓN LINK PRESIONADO');
    print('QR URL: $qrUrl');

    if (qrUrl == null || qrUrl!.isEmpty) {
      print('ERROR: qrUrl está vacío');
      return;
    }

    try {
      final Uri uri = Uri.parse(qrUrl!);

      print('ABRIENDO: $uri');

      var resultado = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      // Si no hay navegador externo disponible, se prueba el modo por defecto.
      if (!resultado) {
        resultado = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }

      print('RESULTADO launchUrl: $resultado');

      if (!resultado && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el enlace'),
          ),
        );
      }
    } catch (e) {
      print('ERROR AL ABRIR URL: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el enlace: $e'),
          ),
        );
      }
    }
  }

  // ==========================================================
  // AÑADIR EL COMPONENTE A DISEÑO Y CONEXIONES
  // ==========================================================

  void _mostrarMensajeQR(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            texto,
            textAlign: TextAlign.center,
          ),
        ),
      );
  }

  void anadirComponente() {
    final ficha = fichaQR;

    if (ficha == null) {
      _mostrarMensajeQR('Primero escanee el QR de un componente.');
      return;
    }

    // Válvulas: no están diseñadas para añadirse.
    if (ficha.estado == EstadoDiseno.noAnadible) {
      _mostrarMensajeQR('Este componente no está diseñado para ser añadido');
      return;
    }

    final modelo = _modeloQR;

    // Componentes que todavía no existen en la app.
    if (ficha.estado == EstadoDiseno.noDisenado || modelo == null) {
      _mostrarMensajeQR('Este componente aún no ha sido diseñado');
      return;
    }

    final nuevo = _DesignScreenState.anadirComponenteDesdeQR(modelo);

    _mostrarMensajeQR(
      '${modelo.name} ${nuevo.instanceNumber} añadido a '
          'Diseño y conexiones.',
    );
  }

  // ==========================================================
  // LIBERAR CÁMARA
  // ==========================================================

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  // ==========================================================
  // ESCALA RESPONSIVA (la misma que usan las demás pantallas)
  // ==========================================================
  double _escala(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return (ancho / 2521.0).clamp(0.55, 1.0);
  }

  // Tamaño relativo a la pantalla (márgenes, separaciones...).
  double _w(BuildContext context, double valor) {
    return valor * _escala(context);
  }

  // Tamaño de letra relativo a la pantalla (con un mínimo legible).
  double _fs(BuildContext context, double valor, {double min = 13.0}) {
    return (valor * _escala(context)).clamp(min, 40.0);
  }

  // Botón de la columna de información.
  Widget _botonInfo(
      BuildContext context,
      String texto,
      VoidCallback? onPressed,
      ) {
    return SizedBox(
      width: double.infinity,
      height: _w(context, 55).clamp(42.0, 60.0),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(
            color: Colors.black,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _fs(context, 18),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // INTERFAZ
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final estiloDato = TextStyle(
      fontSize: _fs(context, 30),
      color: Colors.black,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // CABECERA
            // ==================================================
            AppHeader(
              title: 'Escaneo de QR',
              onBack: () {
                Navigator.pop(context);
              },
            ),

            // ==================================================
            // ESTADO DEL QR (aquí se muestra "Apunta la cámara al QR")
            // ==================================================
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: _w(context, 25),
                vertical: _w(context, 18),
              ),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black,
                    width: 1.5,
                  ),
                ),
              ),
              child: Text(
                estadoQR,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _fs(context, 26),
                  color: Colors.black,
                ),
              ),
            ),

            // ==================================================
            // CONTENIDO
            // ==================================================
            Expanded(
              child: Row(
                children: [
                  // ==========================================
                  // LECTOR QR
                  // ==========================================
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: EdgeInsets.all(_w(context, 20)),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // UN ÚNICO cuadrado que muestra la cámara
                          // (sin marcos ni recuadros adicionales).
                          final lado =
                              constraints.biggest.shortestSide;

                          return Center(
                            child: Container(
                              width: lado,
                              height: lado,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: ClipRect(
                                child: MobileScanner(
                                  key: const ValueKey(
                                    'camara_qr_unica',
                                  ),
                                  controller: scannerController,
                                  fit: BoxFit.cover,
                                  onDetect: procesarQR,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ==========================================
                  // INFORMACIÓN DEL COMPONENTE
                  // ==========================================
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // --------------------------------
                          // NOMBRE
                          // --------------------------------
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(_w(context, 18)),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Text(
                              fichaQR?.nombre ?? 'Nombre del sensor o actuador',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: _fs(
                                  context,
                                  (fichaQR?.nombre.length ?? 0) > 45 ? 22 : 30,
                                  min: 12.0,
                                ),
                                color: Colors.black,
                              ),
                            ),
                          ),

                          // --------------------------------
                          // INFORMACIÓN
                          // --------------------------------
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(_w(context, 25)),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            qrDetectado.isEmpty
                                                ? 'Esperando QR...'
                                                : 'QR leído: $qrDetectado',
                                            style: TextStyle(
                                              fontSize: _fs(context, 24),
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: _w(context, 22)),
                                          Text(
                                            'Tipo de dispositivo: ${fichaQR?.tipoDispositivo ?? 'XX'}',
                                            style: estiloDato,
                                          ),
                                          SizedBox(height: _w(context, 22)),
                                          Text(
                                            'Tipo de señal: ${fichaQR?.tipoSenal ?? 'XX'}',
                                            style: estiloDato,
                                          ),
                                          SizedBox(height: _w(context, 22)),
                                          Text(
                                            'Accionamiento: ${fichaQR?.accionamiento ?? 'XX'}',
                                            style: estiloDato,
                                          ),
                                          SizedBox(height: _w(context, 22)),
                                          Text(
                                            'Código FESTO: ${fichaQR?.codigosTexto ?? 'XX'}',
                                            style: estiloDato,
                                          ),

                                          // Solo los componentes ya diseñados en la app.
                                          if (_modeloQR != null) ...[
                                            SizedBox(height: _w(context, 22)),
                                            Text(
                                              'Número de entradas: ${_modeloQR!.inputs.length}',
                                              style: estiloDato,
                                            ),
                                            SizedBox(height: _w(context, 22)),
                                            Text(
                                              'Número de salidas: ${_modeloQR!.outputs.length}',
                                              style: estiloDato,
                                            ),
                                            SizedBox(height: _w(context, 22)),
                                            Text(
                                              _modeloQR!.description,
                                              style: estiloDato,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: _w(context, 15)),

                                  // ----------------------------
                                  // LINK
                                  // ----------------------------
                                  _botonInfo(
                                    context,
                                    'Link para más información',
                                    qrUrl != null && qrUrl!.isNotEmpty
                                        ? abrirInformacion
                                        : null,
                                  ),

                                  SizedBox(height: _w(context, 15)),

                                  // ----------------------------
                                  // AÑADIR COMPONENTE
                                  // ----------------------------
                                  _botonInfo(
                                    context,
                                    'Añadir componente',
                                    fichaQR != null ? anadirComponente : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// PANTALLA DE CONEXIÓN BLUETOOTH
// ============================================================

class BluetoothScreen extends StatefulWidget {

  const BluetoothScreen({
    super.key,
  });

  @override
  State<BluetoothScreen> createState() =>
      _BluetoothScreenState();
}

class _BluetoothScreenState
    extends State<BluetoothScreen> {

  final BluetoothManager bluetooth =
      BluetoothManager.instance;

  // ==========================================================
  // INICIO
  // ==========================================================

  @override
  void initState() {

    super.initState();

    bluetooth.addListener(
      _actualizarPantalla,
    );
  }

  // ==========================================================
  // ACTUALIZAR PANTALLA
  // ==========================================================

  void _actualizarPantalla() {

    if (mounted) {

      setState(() {});
    }
  }

  // ==========================================================
  // CERRAR PANTALLA
  // ==========================================================

  @override
  void dispose() {

    bluetooth.removeListener(
      _actualizarPantalla,
    );

    // IMPORTANTE:
    // NO DESCONECTAR EL ESP32 AQUÍ.

    super.dispose();
  }

  // ==========================================================
  // MOSTRAR ERROR
  // ==========================================================

  void mostrarError(String mensaje) {

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ==========================================================
  // INTERFAZ
  // ==========================================================

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;

    final ancho = size.width;
    final alto = size.height;

    // ==========================================================
    // ESCALA RELATIVA
    // ==========================================================

    // Tomamos como referencia la proporción de la pantalla
    // del diseño, pero limitamos la escala para evitar
    // elementos excesivamente grandes o pequeños.
    final escalaAncho =
    (ancho / 1869.0).clamp(0.70, 1.15);

    final escalaAlto =
    (alto / 835.0).clamp(0.70, 1.15);

    // ==========================================================
    // MÁRGENES RELATIVOS
    // ==========================================================

    final margenHorizontal =
    (ancho * 0.018).clamp(12.0, 30.0);

    final margenVertical =
    (alto * 0.018).clamp(6.0, 16.0);

    // ==========================================================
    // TAMAÑO DEL CUADRO BLUETOOTH
    // ==========================================================

    // ANTES:
    // alto * 0.28
    //
    // Eso hacía que el cuadro fuera demasiado alto.
    //
    // Ahora utilizamos una dimensión más pequeña y controlada.

    final bluetoothBoxWidth =
    (ancho * 0.105).clamp(120.0, 195.0);

    final bluetoothBoxHeight =
    (alto * 0.20).clamp(105.0, 170.0);

    // ==========================================================
    // ICONO
    // ==========================================================

    final bluetoothIconSize =
    (bluetoothBoxHeight * 0.55)
        .clamp(55.0, 90.0);

    // ==========================================================
    // BOTONES
    // ==========================================================

    final botonWidth =
    (ancho * 0.145).clamp(170.0, 285.0);

    final botonHeight =
    (alto * 0.075).clamp(42.0, 62.0);

    // ==========================================================
    // TEXTOS
    // ==========================================================

    final estadoFontSize =
    (alto * 0.040).clamp(18.0, 30.0);

    final tituloListaFontSize =
    (alto * 0.032).clamp(15.0, 24.0);

    final dispositivoFontSize =
    (alto * 0.030).clamp(15.0, 23.0);

    final botonFontSize =
    (alto * 0.028).clamp(14.0, 21.0);

    return Scaffold(

      backgroundColor: Colors.white,

      body: SafeArea(

        child: Column(

          children: [

            // ==================================================
            // CABECERA
            // ==================================================

            AppHeader(
              title: 'Conexión Bluetooth',

              onBack: () {
                Navigator.pop(context);
              },
            ),

            // ==================================================
            // ESTADO
            // ==================================================

            Container(

              width: double.infinity,

              padding: EdgeInsets.symmetric(
                vertical:
                (alto * 0.018).clamp(7.0, 15.0),
              ),

              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black,
                    width: 1.5,
                  ),
                ),
              ),

              child: RichText(

                textAlign: TextAlign.center,

                text: TextSpan(

                  style: TextStyle(
                    color: Colors.black,
                    fontSize: estadoFontSize,
                  ),

                  children: [

                    const TextSpan(
                      text: 'Estado: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    TextSpan(
                      text: bluetooth.estado,
                    ),

                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: PuntoEstado(
                          conectado: bluetooth.conectado,
                          reconectando: bluetooth.reconectando,
                          tamano: estadoFontSize * 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // CONTENIDO PRINCIPAL
            // ==================================================

            Expanded(

              child: Row(

                crossAxisAlignment:
                CrossAxisAlignment.stretch,

                children: [

                  // =================================================
                  // PANEL IZQUIERDO
                  // =================================================

                  Expanded(

                    flex: 3,

                    child: Padding(

                      padding: EdgeInsets.symmetric(
                        horizontal: margenHorizontal,
                        vertical: margenVertical,
                      ),

                      child: Column(

                        children: [

                          // =========================================
                          // ESPACIO SUPERIOR
                          // =========================================

                          const Spacer(
                            flex: 1,
                          ),

                          // =========================================
                          // CUADRO BLUETOOTH
                          // =========================================

                          SizedBox(

                            width: bluetoothBoxWidth,

                            height: bluetoothBoxHeight,

                            child: Container(

                              decoration: BoxDecoration(

                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),

                                borderRadius:
                                BorderRadius.circular(
                                  15 * escalaAncho,
                                ),
                              ),

                              child: Center(

                                child: Icon(

                                  bluetooth.conectado
                                      ? Icons.bluetooth
                                      : Icons.bluetooth,

                                  size: bluetoothIconSize,

                                  // =================================
                                  // NEGRO = DESCONECTADO
                                  // AZUL = CONECTADO
                                  // =================================

                                  color:
                                  bluetooth.conectado
                                      ? Colors.blue
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),

                          // =========================================
                          // ESPACIO
                          // =========================================

                          const Spacer(
                            flex: 1,
                          ),

                          // =========================================
                          // BOTÓN BUSCAR
                          // =========================================

                          SizedBox(

                            width: botonWidth,

                            height: botonHeight,

                            child: OutlinedButton(

                              onPressed:
                              (bluetooth.buscando || bluetooth.reconectando)
                                  ? null
                                  : () async {

                                await bluetooth
                                    .buscarDispositivos();
                              },

                              style:
                              OutlinedButton.styleFrom(

                                foregroundColor:
                                Colors.black,

                                side:
                                const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),

                                shape:
                                const StadiumBorder(),

                                padding:
                                EdgeInsets.zero,
                              ),

                              child: Text(

                                bluetooth.buscando
                                    ? 'Buscando...'
                                    : 'Buscar',

                                style: TextStyle(
                                  fontSize:
                                  botonFontSize,
                                  color:
                                  Colors.black,
                                ),
                              ),
                            ),
                          ),

                          // =========================================
                          // ESPACIO
                          // =========================================

                          SizedBox(
                            height:
                            (alto * 0.025)
                                .clamp(8.0, 18.0),
                          ),

                          // =========================================
                          // BOTÓN DESCONECTAR
                          // =========================================

                          SizedBox(

                            width: botonWidth,

                            height: botonHeight,

                            child: OutlinedButton(

                              onPressed:
                              (bluetooth.conectado || bluetooth.reconectando)
                                  ? () async {

                                await bluetooth
                                    .desconectar();
                              }
                                  : null,

                              style:
                              OutlinedButton.styleFrom(

                                foregroundColor:
                                Colors.black,

                                side:
                                const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),

                                shape:
                                const StadiumBorder(),

                                padding:
                                EdgeInsets.zero,
                              ),

                              child: Text(

                                'Desconectar',

                                style: TextStyle(
                                  fontSize:
                                  botonFontSize,
                                  color:
                                  Colors.black,
                                ),
                              ),
                            ),
                          ),

                          // =========================================
                          // ESPACIO INFERIOR
                          // =========================================

                          const Spacer(
                            flex: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // =================================================
                  // SEPARADOR
                  // =================================================

                  Container(
                    width: 1.5,
                    color: Colors.black,
                  ),

                  // =================================================
                  // PANEL DERECHO
                  // =================================================

                  Expanded(

                    flex: 7,

                    child: Padding(

                      padding: EdgeInsets.only(
                        left: margenHorizontal,
                        right: margenHorizontal,
                        top: margenVertical,
                        bottom: margenVertical,
                      ),

                      child: Column(

                        children: [

                          // =========================================
                          // TÍTULO
                          // =========================================

                          Container(

                            width: double.infinity,

                            padding:
                            EdgeInsets.symmetric(
                              vertical:
                              (alto * 0.018)
                                  .clamp(8.0, 16.0),
                              horizontal:
                              margenHorizontal,
                            ),

                            decoration:
                            const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                            ),

                            child: Text(

                              'Dispositivos disponibles',

                              style: TextStyle(
                                fontSize:
                                tituloListaFontSize,
                                fontWeight:
                                FontWeight.bold,
                                color:
                                Colors.black,
                              ),
                            ),
                          ),

                          // =========================================
                          // ERROR
                          // =========================================

                          if (bluetooth.errorBusqueda
                              .isNotEmpty)

                            Padding(

                              padding:
                              EdgeInsets.all(
                                margenVertical,
                              ),

                              child: Text(

                                bluetooth.errorBusqueda,

                                textAlign:
                                TextAlign.center,

                                style: TextStyle(
                                  fontSize:
                                  dispositivoFontSize,
                                  color:
                                  Colors.red,
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),

                          // =========================================
                          // LISTA
                          // =========================================

                          Expanded(

                            child:
                            bluetooth.dispositivos.isEmpty

                                ? Center(

                              child: Text(

                                bluetooth.buscando
                                    ? 'Buscando dispositivos...'
                                    : 'Presiona "Buscar" para encontrar dispositivos Bluetooth',

                                textAlign:
                                TextAlign.center,

                                style:
                                TextStyle(
                                  fontSize:
                                  dispositivoFontSize,
                                  color:
                                  Colors.black,
                                ),
                              ),
                            )

                                : Scrollbar(

                              thumbVisibility:
                              true,

                              child:
                              ListView.builder(

                                padding:
                                EdgeInsets.zero,

                                itemCount:
                                bluetooth
                                    .dispositivos
                                    .length,

                                itemBuilder:
                                    (
                                    context,
                                    index,
                                    ) {

                                  final resultado =
                                  bluetooth
                                      .dispositivos[index];

                                  final nombre =
                                  bluetooth
                                      .obtenerNombre(
                                    resultado,
                                  );

                                  final esESP32 =
                                  bluetooth
                                      .esESP32(
                                    resultado,
                                  );

                                  return Container(

                                    decoration:
                                    const BoxDecoration(
                                      border: Border(
                                        bottom:
                                        BorderSide(
                                          color:
                                          Colors.black,
                                          width:
                                          1,
                                        ),
                                      ),
                                    ),

                                    child: ListTile(

                                      dense: true,

                                      contentPadding:
                                      EdgeInsets.symmetric(
                                        horizontal:
                                        margenHorizontal,
                                        vertical:
                                        (alto * 0.005)
                                            .clamp(
                                          2.0,
                                          6.0,
                                        ),
                                      ),

                                      leading: Icon(

                                        Icons
                                            .bluetooth,

                                        size:
                                        (alto * 0.055)
                                            .clamp(
                                          28.0,
                                          48.0,
                                        ),

                                        color:
                                        Colors.black,
                                      ),

                                      title: Text(

                                        nombre,

                                        style:
                                        TextStyle(
                                          fontSize:
                                          dispositivoFontSize,
                                          color:
                                          Colors.black,
                                          fontWeight:
                                          esESP32
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),

                                      subtitle:
                                      esESP32
                                          ? const Text(
                                        'ESP32 NodeMCU 32S',
                                      )
                                          : null,

                                      trailing:
                                      SizedBox(

                                        width:
                                        (ancho * 0.085)
                                            .clamp(
                                          95.0,
                                          150.0,
                                        ),

                                        height:
                                        (alto * 0.055)
                                            .clamp(
                                          38.0,
                                          52.0,
                                        ),

                                        child:
                                        OutlinedButton(

                                          onPressed:
                                          (bluetooth.conectado || bluetooth.reconectando)
                                              ? null
                                              : () async {

                                            final String? error =
                                            await bluetooth.conectarDispositivo(
                                              resultado,
                                            );

                                            if (error != null && mounted) {
                                              mostrarError(error);
                                            }
                                          },

                                          style:
                                          OutlinedButton
                                              .styleFrom(

                                            foregroundColor:
                                            Colors.black,

                                            side:
                                            const BorderSide(
                                              color:
                                              Colors.black,
                                              width:
                                              1.5,
                                            ),

                                            shape:
                                            const StadiumBorder(),

                                            padding:
                                            EdgeInsets.zero,
                                          ),

                                          child:
                                          Text(

                                            'Conectar',

                                            style:
                                            TextStyle(
                                              fontSize:
                                              botonFontSize,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// PANTALLA DE PRUEBA DE PINES
// ============================================================

class PinTestScreen extends StatefulWidget {

  const PinTestScreen({
    super.key,
  });

  @override
  State<PinTestScreen> createState() =>
      _PinTestScreenState();
}


class _PinTestScreenState
    extends State<PinTestScreen> {

  final BluetoothManager bluetooth =
      BluetoothManager.instance;


  // ==========================================================
  // INICIO
  // ==========================================================

  @override
  void initState() {

    super.initState();

    bluetooth.addListener(
      _actualizarPantalla,
    );

    // Si ya existe conexión Bluetooth,
    // solicitamos inmediatamente los módulos.

    if (bluetooth.conectado) {

      bluetooth.solicitarModulos();
    }
  }


  // ==========================================================
  // ACTUALIZAR
  // ==========================================================

  void _actualizarPantalla() {

    if (mounted) {

      setState(() {});
    }
  }


  // ==========================================================
  // CERRAR
  // ==========================================================

  @override
  void dispose() {

    bluetooth.removeListener(
      _actualizarPantalla,
    );

    // NO desconectar Bluetooth.

    super.dispose();
  }


  // ==========================================================
  // ESCALA
  // ==========================================================

  double escala(BuildContext context) {

    final size =
        MediaQuery.of(context).size;

    return (size.width / 1698.0)
        .clamp(0.55, 1.20);
  }


  double w(
      BuildContext context,
      double valor) {

    return valor *
        escala(context);
  }



  // ==========================================================
  // CONSTRUIR ESTADO DEL PIN
  // ==========================================================

  Widget construirEstadoPin(
      BuildContext context,
      ModuloPin modulo,
      int indice) {

    final valor =
    modulo.valores[indice];


    // ========================================================
    // ENTRADA DIGITAL
    // ========================================================

    if (modulo.tipo == 'DI') {

      final activo =
          valor == 1;

      return Center(

        child: Text(
          activo ? 'ON' : 'OFF',

          style: TextStyle(
            fontSize:
            w(context, 28),

            fontWeight:
            FontWeight.w500,
          ),
        ),
      );
    }


    // ========================================================
    // SALIDA DIGITAL
    // ========================================================

    if (modulo.tipo == 'DO') {

      // Puertos deshabilitados (2 y 3): no se pueden manipular.
      if (!modulo.puertoHabilitado(indice + 1)) {

        return Container(

          color: Colors.grey.shade200,

          alignment: Alignment.center,

          child: Text(
            'Deshabilitado',

            style: TextStyle(
              fontSize: w(context, 22),
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      final encendido =
          valor == 1;

      return Center(

        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [

            SizedBox(
              width: w(context, 95),
              height: w(context, 48),

              child: ElevatedButton(

                onPressed:
                bluetooth.conectado

                    ? () {

                  bluetooth
                      .cambiarPinDigital(
                    modulo.numero,
                    indice + 1,
                    true,
                  );

                }
                    : null,

                style:
                ElevatedButton.styleFrom(

                  backgroundColor:
                  encendido
                      ? Colors.black
                      : Colors.white,

                  foregroundColor:
                  encendido
                      ? Colors.white
                      : Colors.black,

                  side:
                  const BorderSide(
                    color: Colors.black,
                    width: 2,
                  ),

                  shape:
                  const RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.zero,
                  ),

                  padding:
                  EdgeInsets.zero,
                ),

                child: Text(
                  'ON',

                  style: TextStyle(
                    fontSize:
                    w(context, 18),
                  ),
                ),
              ),
            ),

            SizedBox(
              width: w(context, 10),
            ),

            SizedBox(
              width: w(context, 95),
              height: w(context, 48),

              child: ElevatedButton(

                onPressed:
                bluetooth.conectado

                    ? () {

                  bluetooth
                      .cambiarPinDigital(
                    modulo.numero,
                    indice + 1,
                    false,
                  );

                }
                    : null,

                style:
                ElevatedButton.styleFrom(

                  backgroundColor:
                  !encendido
                      ? Colors.black
                      : Colors.white,

                  foregroundColor:
                  !encendido
                      ? Colors.white
                      : Colors.black,

                  side:
                  const BorderSide(
                    color: Colors.black,
                    width: 2,
                  ),

                  shape:
                  const RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.zero,
                  ),

                  padding:
                  EdgeInsets.zero,
                ),

                child: Text(
                  'OFF',

                  style: TextStyle(
                    fontSize:
                    w(context, 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }


    // ========================================================
    // ENTRADA ANALÓGICA
    // ========================================================

    if (modulo.tipo == 'AI') {

      return Center(

        child: Text(
          '${valor.toStringAsFixed(2)} V',

          style: TextStyle(
            fontSize:
            w(context, 28),

            fontWeight:
            FontWeight.w500,
          ),
        ),
      );
    }


    return const SizedBox();
  }


  // ==========================================================
  // INTERFAZ
  // ==========================================================

  @override
  Widget build(BuildContext context) {

    final size =
        MediaQuery.of(context).size;

    final alto =
        size.height;


    final headerHeight =
    (alto * 0.105)
        .clamp(65.0, 110.0);


    return Scaffold(

      backgroundColor:
      Colors.white,

      body: SafeArea(

        child: Column(

          children: [

            // ==================================================
            // CABECERA
            // ==================================================

            AppHeader(

              title:
              'Prueba de Pines',

              onBack: () {

                Navigator.pop(context);
              },
            ),


            // ==================================================
            // ESTADO DEL ESP32
            // ==================================================

            Container(

              width:
              double.infinity,

              height:
              (alto * 0.085)
                  .clamp(55.0, 85.0),

              decoration:
              const BoxDecoration(

                border: Border(
                  bottom:
                  BorderSide(
                    color:
                    Colors.black,
                    width:
                    1.5,
                  ),
                ),
              ),

              child:
              Center(

                child:
                RichText(

                  textAlign:
                  TextAlign.center,

                  text:
                  TextSpan(

                    style:
                    TextStyle(
                      color:
                      Colors.black,

                      fontSize:
                      (alto * 0.032)
                          .clamp(
                          18.0,
                          28.0),
                    ),

                    children: [

                      const TextSpan(
                        text:
                        'Estado: ',

                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      TextSpan(
                        text:
                        bluetooth.conectado
                            ? 'ESP32 conectado'
                            : (bluetooth.reconectando
                            ? 'Reconectando...'
                            : 'No conectado'),
                      ),

                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: PuntoEstado(
                            conectado: bluetooth.conectado,
                            reconectando: bluetooth.reconectando,
                            tamano: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),


            // ==================================================
            // TABLA
            // ==================================================

            Expanded(

              child:
              Padding(

                padding:
                EdgeInsets.all(
                  w(context, 25),
                ),

                child:
                Row(

                  crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,

                  children: [

                    // ==========================================
                    // COLUMNA DE MÓDULOS
                    // ==========================================

                    SizedBox(

                      width:
                      w(context, 205),

                      child:
                      Column(

                        children: [

                          // CABECERA

                          Container(

                            height:
                            w(context, 72),

                            decoration:
                            BoxDecoration(

                              border:
                              Border.all(
                                color:
                                Colors.black,
                                width:
                                1.5,
                              ),
                            ),

                            child:
                            Center(

                              child:
                              Text(
                                'Módulos',

                                style:
                                TextStyle(
                                  fontSize:
                                  w(context, 24),

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                            ),
                          ),


                          // MÓDULOS 1-4

                          ...List.generate(
                            4,
                                (index) {

                              final numero =
                                  index + 1;

                              final modulo =
                              bluetooth.modulos[
                              index];

                              final seleccionado =
                                  bluetooth
                                      .moduloSeleccionado
                                      ==
                                      numero;

                              return Expanded(

                                child:
                                GestureDetector(

                                  onTap: () {

                                    setState(() {

                                      bluetooth
                                          .moduloSeleccionado =
                                          numero;
                                    });

                                  },

                                  child:
                                  Container(

                                    width:
                                    double.infinity,

                                    decoration:
                                    BoxDecoration(

                                      color:
                                      seleccionado
                                          ? Colors.black
                                          : Colors.white,

                                      border:
                                      const Border(
                                        left:
                                        BorderSide(
                                          color:
                                          Colors.black,
                                          width:
                                          1.5,
                                        ),

                                        right:
                                        BorderSide(
                                          color:
                                          Colors.black,
                                          width:
                                          1.5,
                                        ),

                                        bottom:
                                        BorderSide(
                                          color:
                                          Colors.black,
                                          width:
                                          1.5,
                                        ),
                                      ),
                                    ),

                                    child:
                                    Center(

                                      child:
                                      Column(

                                        mainAxisAlignment:
                                        MainAxisAlignment.center,

                                        children: [

                                          Text(

                                            'Módulo $numero',

                                            style:
                                            TextStyle(

                                              color:
                                              seleccionado
                                                  ? Colors.white
                                                  : Colors.black,

                                              fontSize:
                                              w(context, 22),

                                              fontWeight:
                                              seleccionado
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),

                                          SizedBox(
                                            height:
                                            w(context, 5),
                                          ),

                                          Text(

                                            modulo.conectado
                                                ? modulo.tipo
                                                : 'No conectado',

                                            style:
                                            TextStyle(

                                              color:
                                              seleccionado
                                                  ? Colors.white
                                                  : Colors.black,

                                              fontSize:
                                              w(context, 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),


                    // ==========================================
                    // ESPACIO ENTRE COLUMNAS
                    // ==========================================

                    SizedBox(
                      width:
                      w(context, 2),
                    ),


                    // ==========================================
                    // PINES
                    // ==========================================

                    Expanded(

                      flex: 2,

                      child:
                      _construirColumnaPines(
                        context,
                      ),
                    ),


                    // ==========================================
                    // ESTADO
                    // ==========================================

                    Expanded(

                      flex: 4,

                      child:
                      _construirColumnaEstado(
                        context,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ==========================================================
  // COLUMNA PINES
  // ==========================================================

  Widget _construirColumnaPines(
      BuildContext context) {

    final modulo =
    bluetooth.modulos[
    bluetooth.moduloSeleccionado - 1];


    return Column(

      children: [

        Container(

          height:
          w(context, 72),

          decoration:
          BoxDecoration(

            border:
            Border.all(
              color:
              Colors.black,
              width:
              1.5,
            ),
          ),

          child:
          Center(

            child:
            Text(
              'Pines',

              style:
              TextStyle(
                fontSize:
                w(context, 24),

                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ),


        Expanded(

          child:
          !modulo.conectado

              ? Container(

            width:
            double.infinity,

            decoration:
            const BoxDecoration(

              border: Border(
                left:
                BorderSide(
                  color:
                  Colors.black,
                  width:
                  1.5,
                ),

                bottom:
                BorderSide(
                  color:
                  Colors.black,
                  width:
                  1.5,
                ),
              ),
            ),

            child:
            Center(

              child:
              Text(
                '—',

                style:
                TextStyle(
                  fontSize:
                  w(context, 30),
                ),
              ),
            ),
          )

              : Column(

            children:
            List.generate(
              modulo.cantidadPines,
                  (index) {

                return Expanded(

                  child:
                  Container(

                    decoration:
                    const BoxDecoration(

                      border: Border(
                        left:
                        BorderSide(
                          color:
                          Colors.black,
                          width:
                          1.5,
                        ),

                        bottom:
                        BorderSide(
                          color:
                          Colors.black,
                          width:
                          1.5,
                        ),
                      ),
                    ),

                    child:
                    Center(

                      child:
                      Text(
                        'Puerto ${index + 1}',

                        style:
                        TextStyle(
                          fontSize:
                          w(context, 21),

                          color:
                          modulo.puertoHabilitado(index + 1)
                              ? Colors.black
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }


  // ==========================================================
  // COLUMNA ESTADO
  // ==========================================================

  // Aviso que se abre al tocar el símbolo de advertencia.
  void _mostrarAdvertenciaVoltaje(BuildContext context) {

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
            size: 40,
          ),
          title: const Text('Voltaje referencial'),
          content: const Text(
            'El voltaje que se muestra es solo referencial y no '
                'refleja el verdadero valor de un sensor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Widget _construirColumnaEstado(
      BuildContext context) {

    final modulo =
    bluetooth.modulos[
    bluetooth.moduloSeleccionado - 1];


    return Column(

      children: [

        Container(

          height:
          w(context, 72),

          decoration:
          BoxDecoration(

            border:
            Border.all(
              color:
              Colors.black,
              width:
              1.5,
            ),
          ),

          child:
          Center(

            child:
            Row(

              mainAxisSize:
              MainAxisSize.min,

              children: [

                Text(
                  'Estado de los pines',

                  style:
                  TextStyle(
                    fontSize:
                    w(context, 24),

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                // Advertencia: solo en módulos de entrada analógica.
                if (modulo.conectado && modulo.tipo == 'AI')
                  Padding(

                    padding:
                    const EdgeInsets.only(left: 10),

                    child:
                    Tooltip(

                      message:
                      'El voltaje observado es referencial y no '
                          'refleja el verdadero valor de un sensor.',

                      triggerMode:
                      TooltipTriggerMode.tap,

                      showDuration:
                      const Duration(seconds: 4),

                      child:
                      GestureDetector(

                        onTap: () {
                          _mostrarAdvertenciaVoltaje(context);
                        },

                        child:
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                          size: w(context, 30),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),


        Expanded(

          child:
          !modulo.conectado

              ? Container(

            width:
            double.infinity,

            decoration:
            const BoxDecoration(

              border: Border(
                right:
                BorderSide(
                  color:
                  Colors.black,
                  width:
                  1.5,
                ),

                bottom:
                BorderSide(
                  color:
                  Colors.black,
                  width:
                  1.5,
                ),
              ),
            ),

            child:
            Center(

              child:
              Text(
                bluetooth.conectado
                    ? 'Error: El módulo no está conectado'
                    : 'Error: El dispositivo no está conectado',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  fontSize:
                  w(context, 22),

                  color:
                  Colors.red,

                  fontWeight:
                  FontWeight.w500,
                ),
              ),
            ),
          )

              : Column(

            children:
            List.generate(
              modulo.cantidadPines,
                  (index) {

                return Expanded(

                  child:
                  Container(

                    decoration:
                    const BoxDecoration(

                      border: Border(
                        right:
                        BorderSide(
                          color:
                          Colors.black,
                          width:
                          1.5,
                        ),

                        bottom:
                        BorderSide(
                          color:
                          Colors.black,
                          width:
                          1.5,
                        ),
                      ),
                    ),

                    child:
                    construirEstadoPin(
                      context,
                      modulo,
                      index,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}


// ============================================================
// PANTALLA DE DISEÑO Y CONEXIONES
// ============================================================

class DesignScreen extends StatefulWidget {

  const DesignScreen({
    super.key,
  });

  @override
  State<DesignScreen> createState() =>
      _DesignScreenState();
}


class _DesignScreenState extends State<DesignScreen> {

  // ==========================================================
  // ESTADO PERSISTENTE DE LA INTERFAZ
  // ==========================================================

  static final List<PlacedComponent> _componentesPersistentes = [];

  static bool _mostrarComponentesPersistente = false;

  static String _tipoSeleccionadoPersistente = 'Sensores';

  static PlacedComponent? _componenteSeleccionadoPersistente;

  bool get mostrarComponentes => _mostrarComponentesPersistente;

  set mostrarComponentes(bool valor) {_mostrarComponentesPersistente = valor;}

  String get tipoSeleccionado => _tipoSeleccionadoPersistente;

  set tipoSeleccionado(String valor) {_tipoSeleccionadoPersistente = valor;}

  PlacedComponent? get componenteSeleccionado => _componenteSeleccionadoPersistente;

  set componenteSeleccionado(PlacedComponent? valor) {_componenteSeleccionadoPersistente = valor;}

  List<PlacedComponent> get componentesColocados => _componentesPersistentes;

  // Instancia activa de la pantalla. El NodeFlowEditor usa un controlador
  // estático que puede conservar los eventos de una instancia vieja ya
  // destruida; por eso los eventos llaman siempre a la instancia activa.
  static _DesignScreenState? _activo;

  @override
  void initState() {
    super.initState();
    _activo = this;
    AppNav.herramientasVivas++;

    // Fuerza un segundo build justo después del primero para que el
    // editor tome los eventos de ESTA instancia (así no hay que cerrar y
    // abrir la pestaña de información para que funcione).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _mostrarComponentesPersistente =
        mostrarComponentes;

    _tipoSeleccionadoPersistente =
        tipoSeleccionado;

    _componenteSeleccionadoPersistente =
        componenteSeleccionado;

    AppNav.herramientasVivas--;
    if (_activo == this) {
      _activo = null;
    }

    super.dispose();
  }

  // ----------------------------------------------------------
  // Manejadores de eventos del editor (llamados por la instancia activa)
  // ----------------------------------------------------------
  Future<void> _dobleToqueNodo(Node<PlacedComponent> node) async {
    setState(() {
      componenteSeleccionado = node.data;
    });

    if (node.data.component.category == 'Otros') {
      await mostrarDialogoAgregarPines(node);
    }
  }

  void _alCrearConexion() {
    if (mounted) {
      setState(() {});
    }
  }

  // Tocar un cable (solo con el botón Cable activo) ofrece eliminarlo.
  void _tocarCable(Connection conexion) {
    if (_modoCable) {
      _confirmarEliminarCable(conexion);
    }
  }

  void _tocarCanvas() {
    // Modo mover: mover el componente elegido al lugar tocado.
    if (_modoMover && _nodoAMoverId != null) {
      _moverNodoA(
        _nodoAMoverId!,
        _ultimoToqueGlobal,
      );
      setState(() {
        _nodoAMoverId = null;
      });
      _mensaje('Componente movido.');
      return;
    }

    setState(() {
      componenteSeleccionado = null;
    });
  }

  // ----------------------------------------------------------
  // COMENZAR / PARAR el sistema (ejecutor global)
  // ----------------------------------------------------------
  void _alternarEjecucion() {
    final ejecutor = EjecutorGlobal.instance;

    if (ejecutor.corriendo) {
      ejecutor.detener();
      _mensaje('Sistema detenido. Se apagaron las salidas controladas.');
      return;
    }

    final error = ejecutor.iniciar();
    if (error != null) {
      _mensaje(error);
      return;
    }
    _mensaje('Sistema en marcha: enviando órdenes al ESP32.');
  }

  // ==========================================================
  // MOTOR NODE FLOW
  // ==========================================================

  // Tamaño (en unidades del gráfico) del cuadrado de cada componente.
  static const double _nodoAncho = 260;
  static const double _nodoAlto = 260;

  // Diámetro de los puertos DI/DO (antes 9 px por defecto, ahora ~5 veces más).
  static const double _puertoTam = 46;

  // Estilo del nombre dentro del puerto (DI 1, DO 1...).
  static const TextStyle _estiloEtiquetaPuerto = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // ZOOM: minZoom más bajo permite alejar más el espacio de trabajo,
  // y el zoom inicial ya arranca alejado.
  static final NodeFlowController<PlacedComponent, dynamic>
  _flowController = NodeFlowController<PlacedComponent, dynamic>(
    config: NodeFlowConfig(
      minZoom: 0.2,
      maxZoom: 2.0,
    ),
    initialViewport: GraphViewport(x: 0, y: 0, zoom: 0.6),
  );

  // ==========================================================
  // ASIGNAR PIN DEL COMPONENTE A UN PUERTO DE UN MÓDULO
  // ==========================================================

  // Tipo de módulo que hace falta para cada tipo de pin:
  //  - Entrada del componente (actuador) -> salida DO del módulo
  //  - Salida del componente (sensor)    -> entrada DI del módulo
  //  - Salida analógica del componente   -> entrada AI del módulo
  String? _tipoModuloRequerido(PinModel pin) {
    switch (pin.type) {
      case PinType.digitalInput:
        return 'DO';
      case PinType.digitalOutput:
        return 'DI';
      case PinType.analogOutput:
        return 'AI';
      case PinType.analogInput:
        return null;
    }
  }

  String _textoAsignacion(PlacedComponent comp, PinModel pin) {
    final a = comp.asignaciones[pin.id];
    if (a == null) return '  →  sin asignar';
    return '  →  Módulo ${a.modulo}, Puerto ${a.puerto}';
  }

  // Devuelve el nombre del componente que ya usa ese puerto (o null).
  String? _ocupadoPor(
      PlacedComponent actual, String pinId, int modulo, int puerto) {
    for (final c in componentesColocados) {
      for (final e in c.asignaciones.entries) {
        final esMismo = c.instanceId == actual.instanceId && e.key == pinId;
        if (!esMismo &&
            e.value.modulo == modulo &&
            e.value.puerto == puerto) {
          return '${c.component.name} ${c.instanceNumber} (${e.key})';
        }
      }
    }
    return null;
  }

  Future<void> _asignarPin() async {
    final comp = componenteSeleccionado;
    if (comp == null) return;

    final pines = <PinModel>[...comp.inputs, ...comp.outputs];

    if (pines.isEmpty) {
      _mensaje('Este componente no tiene pines para asignar.');
      return;
    }

    // ---------------- PASO 1: ELEGIR PIN DEL COMPONENTE ----------------
    PinModel? pin;

    if (pines.length == 1) {
      pin = pines.first;
    } else {
      pin = await showDialog<PinModel>(
        context: context,
        builder: (dialogContext) {
          return SimpleDialog(
            title: const Text('¿Qué pin desea asignar?'),
            children: [
              for (final p in pines)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, p),
                  child: Text(
                    '${p.label} (${p.tipoTexto})'
                        '${_textoAsignacion(comp, p)}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
            ],
          );
        },
      );
    }

    if (pin == null || !mounted) return;

    final tipoNecesario = _tipoModuloRequerido(pin);

    if (tipoNecesario == null) {
      _mensaje('Las entradas analógicas aún no se pueden asignar a un módulo.');
      return;
    }

    // ---------------- PASO 2: ELEGIR MÓDULO ----------------
    final modulos = BluetoothManager.instance.modulos;

    final moduloElegido = await showDialog<ModuloPin>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text('${pin!.label}: elija un módulo'),
          children: [
            for (final m in modulos)
              Builder(builder: (_) {
                final compatible = m.conectado && m.tipo == tipoNecesario;

                String detalle;
                if (!m.conectado) {
                  detalle = 'No conectado';
                } else if (m.tipo != tipoNecesario) {
                  detalle = '${m.tipoTexto} (no compatible, se necesita '
                      '${tipoNecesario == 'DO' ? 'salida' : tipoNecesario == 'DI' ? 'entrada digital' : 'entrada analógica'})';
                } else {
                  detalle = '${m.tipoTexto}, ${m.cantidadPines} puertos';
                }

                return SimpleDialogOption(
                  onPressed: compatible
                      ? () => Navigator.pop(dialogContext, m)
                      : null,
                  child: Opacity(
                    opacity: compatible ? 1.0 : 0.4,
                    child: Text(
                      'Módulo ${m.numero}: $detalle',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }),
            if (pin.id.isNotEmpty && comp.asignaciones.containsKey(pin.id))
              SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  ModuloPin(numero: -1),
                ),
                child: const Text(
                  'Quitar asignación actual',
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              ),
          ],
        );
      },
    );

    if (moduloElegido == null || !mounted) return;

    if (moduloElegido.numero == -1) {
      setState(() {
        comp.asignaciones.remove(pin!.id);
      });
      _mensaje('Asignación de ${pin.label} eliminada.');
      return;
    }

    // ---------------- PASO 3: ELEGIR PUERTO ----------------
    final puerto = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text('Módulo ${moduloElegido.numero}: elija un puerto'),
          children: [
            for (int i = 1; i <= moduloElegido.cantidadPines; i++)
              Builder(builder: (_) {
                final ocupado =
                _ocupadoPor(comp, pin!.id, moduloElegido.numero, i);

                // Los puertos 2 y 3 de los módulos DO están
                // deshabilitados.
                final habilitado = moduloElegido.puertoHabilitado(i);

                final disponible = ocupado == null && habilitado;

                return SimpleDialogOption(
                  onPressed:
                  disponible ? () => Navigator.pop(dialogContext, i) : null,
                  child: Opacity(
                    opacity: disponible ? 1.0 : 0.4,
                    child: Text(
                      !habilitado
                          ? 'Puerto $i (deshabilitado)'
                          : (ocupado == null
                          ? 'Puerto $i'
                          : 'Puerto $i (ocupado por $ocupado)'),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );

    if (puerto == null || !mounted) return;

    final asignacionPrevia = comp.asignaciones[pin.id];

    comp.asignaciones[pin.id] = AsignacionPin(
      modulo: moduloElegido.numero,
      puerto: puerto,
    );

    // Una conexión no puede existir a la vez en Diseño y Conexiones y
    // en la programación por bloques.
    final conflicto = conflictoDisenoProgramacion();
    if (conflicto != null) {
      if (asignacionPrevia == null) {
        comp.asignaciones.remove(pin.id);
      } else {
        comp.asignaciones[pin.id] = asignacionPrevia;
      }
      _mensaje(conflicto);
      return;
    }

    setState(() {});

    _mensaje('${pin.label} asignado a Módulo ${moduloElegido.numero}, '
        'Puerto $puerto.');
  }

  bool _modoCable = false;

  // ==========================================================
  // MODO MOVER / MODO CABLE POR TOQUES (alternativa al arrastre)
  // ==========================================================

  bool _modoMover = false;

  // Modo eliminar: toque un componente para eliminarlo.
  bool _modoEliminar = false;

  // Componente que se va a mover (ya tocado, falta tocar el destino).
  String? _nodoAMoverId;

  // Origen del cable (componente + puerto DO ya elegidos).
  String? _cableOrigenNodoId;
  PinModel? _cableOrigenPin;

  // Última posición tocada en pantalla (coordenadas globales).
  Offset _ultimoToqueGlobal = Offset.zero;

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(texto),
        ),
      );
  }

  String get _textoModoActivo {
    if (_modoEliminar) {
      return 'ELIMINAR: toque el componente que quiere eliminar';
    }
    if (_modoMover) {
      return _nodoAMoverId == null
          ? 'MOVER: toque el componente que quiere mover'
          : 'MOVER: ahora toque el lugar vacío de destino';
    }
    if (_modoCable) {
      return _cableOrigenPin == null
          ? 'CABLE: toque el componente de ORIGEN (salida DO)'
          : 'CABLE: toque el componente de DESTINO (entrada DI)';
    }
    return '';
  }

  void _alternarModoMover() {
    setState(() {
      _modoMover = !_modoMover;
      _nodoAMoverId = null;
      if (_modoMover) {
        _modoCable = false;
        _modoEliminar = false;
        _cableOrigenNodoId = null;
        _cableOrigenPin = null;
      }
    });
    _mensaje(_modoMover
        ? 'Mover activado: toque un componente y luego el lugar de destino.'
        : 'Mover desactivado.');
  }

  void _alternarModoCable() {
    setState(() {
      _modoCable = !_modoCable;
      _cableOrigenNodoId = null;
      _cableOrigenPin = null;
      if (_modoCable) {
        _modoMover = false;
        _modoEliminar = false;
        _nodoAMoverId = null;
      }
    });
    _mensaje(_modoCable
        ? 'Cable activado: toque el componente de origen, elija el puerto, '
        'y luego toque el componente de destino. '
        'Toque un cable para eliminarlo.'
        : 'Cable desactivado.');
  }

  void _alternarModoEliminar() {
    setState(() {
      _modoEliminar = !_modoEliminar;
      if (_modoEliminar) {
        _modoCable = false;
        _modoMover = false;
        _nodoAMoverId = null;
        _cableOrigenNodoId = null;
        _cableOrigenPin = null;
      }
    });
    _mensaje(_modoEliminar
        ? 'Eliminar activado: toque un componente para eliminarlo.'
        : 'Eliminar desactivado.');
  }

  // Coloca el centro del componente donde se tocó.
  void _moverNodoA(String nodeId, Offset posicionGlobal) {
    final destino = _flowController
        .globalToGraph(ScreenPosition(posicionGlobal))
        .offset;

    _flowController.setNodePosition(
      nodeId,
      Offset(destino.dx - 130, destino.dy - 130),
    );
  }

  Future<PinModel?> _elegirPin(String titulo, List<PinModel> pines) {
    return showDialog<PinModel>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(titulo),
          children: [
            for (final p in pines)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, p),
                child: Text(
                  p.label,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
          ],
        );
      },
    );
  }

  String? _validarConexionManual(
      PlacedComponent origen,
      PinModel pinO,
      PlacedComponent destino,
      PinModel pinD) {

    if (origen.instanceId == destino.instanceId) {
      return 'No se puede conectar un componente consigo mismo.';
    }
    if (pinO.type != PinType.digitalOutput) {
      return 'El origen debe ser una salida digital DO.';
    }
    if (pinD.type != PinType.digitalInput) {
      return 'El destino debe ser una entrada digital DI.';
    }
    if (!pinD.conexionesPermitidas.contains(pinO.type)) {
      return 'Este tipo de entrada no acepta este tipo de salida.';
    }

    int enOrigen = 0;
    int enDestino = 0;

    for (final c in _flowController.connections) {
      if (c.sourceNodeId == origen.instanceId && c.sourcePortId == pinO.id) {
        enOrigen++;
      }
      if (c.targetNodeId == destino.instanceId && c.targetPortId == pinD.id) {
        enDestino++;
      }
    }

    if (pinO.maxConnections > 0 && enOrigen >= pinO.maxConnections) {
      return '${pinO.label} ya tiene una conexión.';
    }
    if (pinD.maxConnections > 0 && enDestino >= pinD.maxConnections) {
      return '${pinD.label} ya tiene una conexión.';
    }
    final conflicto = conflictoDisenoProgramacion(
      disenoOrigen: origen,
      disenoOrigenPin: pinO.id,
      disenoDestino: destino,
      disenoDestinoPin: pinD.id,
    );
    if (conflicto != null) {
      return conflicto;
    }

    return null;
  }

  Future<void> _cableConToques(Node<PlacedComponent> node) async {
    final comp = node.data;
    final nombre = '${comp.component.name} ${comp.instanceNumber}';

    // ---------------- PASO 1: ORIGEN ----------------
    if (_cableOrigenPin == null) {
      final salidas = comp.outputs
          .where((p) => p.type == PinType.digitalOutput)
          .toList();

      if (salidas.isEmpty) {
        _mensaje('$nombre no tiene salidas DO. Toque un componente con salida.');
        return;
      }

      final pin = await _elegirPin('Puerto de salida de $nombre', salidas);
      if (pin == null) return;

      setState(() {
        _cableOrigenNodoId = node.id;
        _cableOrigenPin = pin;
      });
      _mensaje('Origen: $nombre (${pin.label}). Ahora toque el componente destino.');
      return;
    }

    // ---------------- PASO 2: DESTINO ----------------
    if (node.id == _cableOrigenNodoId) {
      _mensaje('Elija un componente distinto al de origen.');
      return;
    }

    final entradas = comp.inputs
        .where((p) => p.type == PinType.digitalInput)
        .toList();

    if (entradas.isEmpty) {
      _mensaje('$nombre no tiene entradas DI.');
      return;
    }

    final pinDestino =
    await _elegirPin('Puerto de entrada de $nombre', entradas);
    if (pinDestino == null) return;

    PlacedComponent? origenComp;
    for (final c in componentesColocados) {
      if (c.instanceId == _cableOrigenNodoId) {
        origenComp = c;
      }
    }
    if (origenComp == null) {
      setState(() {
        _cableOrigenNodoId = null;
        _cableOrigenPin = null;
      });
      return;
    }

    final error = _validarConexionManual(
        origenComp, _cableOrigenPin!, comp, pinDestino);

    if (error != null) {
      _mensaje(error);
      return;
    }

    _flowController.addConnection(
      Connection(
        id: 'cable_${DateTime.now().microsecondsSinceEpoch}',
        sourceNodeId: _cableOrigenNodoId!,
        sourcePortId: _cableOrigenPin!.id,
        targetNodeId: node.id,
        targetPortId: pinDestino.id,
      ),
    );

    setState(() {
      _cableOrigenNodoId = null;
      _cableOrigenPin = null;
    });
    _mensaje('Conexión creada.');
  }

  // ==========================================================
  // ELIMINAR UN CABLE (con el botón Cable activado, toque el cable)
  // ==========================================================

  String _describirPuertoCable(String nodoId, String puertoId) {

    for (final c in componentesColocados) {

      if (c.instanceId == nodoId) {

        final pin = _buscarPin(c, puertoId);

        return '${c.component.name} ${c.instanceNumber} '
            '(${pin?.label ?? puertoId})';
      }
    }

    return puertoId;
  }


  Future<void> _confirmarEliminarCable(Connection conexion) async {

    final origen = _describirPuertoCable(
      conexion.sourceNodeId,
      conexion.sourcePortId,
    );

    final destino = _describirPuertoCable(
      conexion.targetNodeId,
      conexion.targetPortId,
    );

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {

        return AlertDialog(

          title: const Text('Eliminar conexión'),

          content: Text(
            '¿Desea eliminar la conexión?\n\n$origen\n→ $destino',
          ),

          actions: [

            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),

            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    _flowController.removeConnection(conexion.id);

    setState(() {});

    _mensaje('Conexión eliminada.');
  }


  Future<void> _manejarToqueNodo(Node<PlacedComponent> node) async {
    setState(() {
      componenteSeleccionado = node.data;
    });

    if (_modoMover) {
      setState(() {
        _nodoAMoverId = node.id;
      });
      return;
    }

    if (_modoEliminar) {
      await eliminarComponenteSeleccionado();
      return;
    }

    if (_modoCable) {
      await _cableConToques(node);
    }
  }


  // ==========================================================
  // ESCALA RESPONSIVA
  // ==========================================================


  double escala(BuildContext context) {

    final ancho = MediaQuery.of(context).size.width;
    return (ancho / 2521.0).clamp(0.55, 1.0);
  }


  double w(BuildContext context, double valor,) {

    return valor * escala(context);
  }


  // ==========================================================
  // CATEGORÍAS
  // ==========================================================


  List<ComponentModel> get componentesCategoria {

    return componentRegistry.values.where(
          (componente) => componente.category == tipoSeleccionado,
    ).toList();
  }


  // ==========================================================
  // OBTENER COMPONENTE DESDE EL REGISTRO
  // ==========================================================


  ComponentModel? obtenerComponente(String id) {return componentRegistry[id];}


  // ==========================================================
  // CREAR PUERTO NODE FLOW
  // ==========================================================

  static Port _crearPuertoNodeFlow({
    required PinModel pin,
    required bool esSalida,
    required int indice,
    required int cantidad,
    required PortPosition posicion,
  }) {
    final Color colorBorde = esSalida ? Colors.red : Colors.blue;
    final Color colorRelleno =
    esSalida ? Colors.red.shade100 : Colors.blue.shade100;
    final Color colorConectado =
    esSalida ? Colors.red.shade300 : Colors.blue.shade300;

    // --------------------------------------------------------
    // POSICIÓN DEL PUERTO
    //
    // El offset indica dónde va el CENTRO del puerto medido desde
    // la esquina superior izquierda del componente:
    //  - Puertos abajo/arriba: dx = posición horizontal, dy = 0 (sobre el borde)
    //  - Puertos izquierda/derecha: dy = posición vertical, dx = 0
    // Así los puertos quedan centrados en la parte de abajo del cuadrado.
    // --------------------------------------------------------

    final Offset offset;

    if (posicion == PortPosition.bottom || posicion == PortPosition.top) {

      double separacion = 0;

      if (cantidad > 1) {
        final maxima = (_nodoAncho - _puertoTam - 24) / (cantidad - 1);
        separacion = maxima < 80 ? maxima : 80;
      }

      offset = Offset(
        _nodoAncho / 2 + (indice - (cantidad - 1) / 2) * separacion,
        0,
      );

    } else {

      double separacion = 0;

      if (cantidad > 1) {
        final maxima = (_nodoAlto - _puertoTam - 24) / (cantidad - 1);
        separacion = maxima < 70 ? maxima : 70;
      }

      offset = Offset(
        0,
        _nodoAlto / 2 + (indice - (cantidad - 1) / 2) * separacion,
      );
    }

    return Port(
      id: pin.id,
      name: pin.label,

      type: esSalida
          ? PortType.output
          : PortType.input,

      position: posicion,

      offset: offset,

      multiConnections:
      pin.maxConnections > 1,

      // Puerto grande para poder presionarlo con el dedo.
      size: const Size(_puertoTam, _puertoTam),

      // Muestra el nombre del puerto (DI 1, DO 1...).
      showLabel: true,

      shape: MarkerShapes.circle,

      theme: PortTheme.light.copyWith(
        size: const Size(_puertoTam, _puertoTam),
        color: colorRelleno,
        connectedColor: colorConectado,
        highlightColor: Colors.orange,
        highlightBorderColor: Colors.black,
        borderColor: colorBorde,
        borderWidth: 3,
        labelTextStyle: _estiloEtiquetaPuerto,
        labelOffset: 4,
      ),
    );
  }

  // ==========================================================
// BUSCAR PIN
// ==========================================================

  PinModel? _buscarPin(
      PlacedComponent componente,
      String pinId) {

    for (final pin
    in componente.inputs) {

      if (pin.id == pinId) {
        return pin;
      }
    }

    for (final pin
    in componente.outputs) {

      if (pin.id == pinId) {
        return pin;
      }
    }

    return null;
  }

  ConnectionValidationResult
  _validarInicioConexion(
      ConnectionStartContext<PlacedComponent> context,
      ) {

    // ==========================================================
    // EL BOTÓN CABLE DEBE ESTAR ACTIVADO
    // ==========================================================

    if (!_modoCable) {

      return ConnectionValidationResult.deny(

        reason:
        'Active el botón Cable para realizar una conexión.',

        showMessage:
        true,
      );
    }

    // ==========================================================
    // SOLAMENTE SE PUEDE EMPEZAR DESDE UNA SALIDA
    // ==========================================================

    if (!context.isOutputPort) {

      return ConnectionValidationResult.deny(

        reason:
        'Debe comenzar la conexión desde un puerto DO.',

        showMessage:
        true,
      );
    }

    // ==========================================================
    // BUSCAR PIN
    // ==========================================================

    final pin =
    _buscarPin(
      context.sourceNode.data,
      context.sourcePort.id,
    );

    if (pin == null) {

      return ConnectionValidationResult.deny(

        reason:
        'Puerto no válido.',

        showMessage:
        true,
      );
    }

    // ==========================================================
    // EL ORIGEN DEBE SER DIGITAL OUTPUT
    // ==========================================================

    if (pin.type !=
        PinType.digitalOutput) {

      return ConnectionValidationResult.deny(

        reason:
        'Solo se puede comenzar desde una salida digital DO.',

        showMessage:
        true,
      );
    }

    // ==========================================================
    // LÍMITE DE CONEXIONES DEL DO
    // ==========================================================

    if (pin.maxConnections > 0 &&
        context.existingConnections.length >=
            pin.maxConnections) {

      return ConnectionValidationResult.deny(

        reason:
        '${pin.label} ya tiene una conexión.',

        showMessage:
        true,
      );
    }

    return ConnectionValidationResult.allow();
  }

  // ==========================================================
  // VALIDAR CONEXIÓN
  // ==========================================================

  ConnectionValidationResult
  _validarConexion(ConnectionCompleteContext<PlacedComponent>   context) {

    // --------------------------------------------------------
    // No permitir conexión del componente consigo mismo
    // --------------------------------------------------------

    if (context.isSelfConnection) {

      return ConnectionValidationResult.deny(
        reason:
        'No se puede conectar un componente consigo mismo.',

        showMessage:
        true,
      );
    }

    // --------------------------------------------------------
    // Solamente salida → entrada
    // --------------------------------------------------------

    if (!context.isOutputToInput) {

      return ConnectionValidationResult.deny(
        reason:
        'Solo se permite conectar una salida con una entrada.',

        showMessage:
        true,
      );
    }

    final origen =
        context.sourceNode.data;

    final destino =
        context.targetNode.data;

    final pinOrigen =
    _buscarPin(
      origen,
      context.sourcePort.id,
    );

    final pinDestino =
    _buscarPin(
      destino,
      context.targetPort.id,
    );

    if (pinOrigen == null ||
        pinDestino == null) {

      return ConnectionValidationResult.deny(
        reason:
        'Puerto no válido.',

        showMessage:
        true,
      );
    }

    // --------------------------------------------------------
    // Verificar que realmente sea DO → DI
    // --------------------------------------------------------

    if (pinOrigen.type !=
        PinType.digitalOutput) {

      return ConnectionValidationResult.deny(
        reason:
        'El puerto de origen debe ser una salida digital.',

        showMessage:
        true,
      );
    }

    if (pinDestino.type !=
        PinType.digitalInput) {

      return ConnectionValidationResult.deny(
        reason:
        'El puerto de destino debe ser una entrada digital.',

        showMessage:
        true,
      );
    }

    // --------------------------------------------------------
    // Verificar compatibilidad definida por el componente
    // --------------------------------------------------------

    if (!pinDestino
        .conexionesPermitidas
        .contains(
      pinOrigen.type,
    )) {

      return ConnectionValidationResult.deny(
        reason:
        'Este tipo de entrada no acepta este tipo de salida.',

        showMessage:
        true,
      );
    }

    // --------------------------------------------------------
    // LÍMITE DE CONEXIONES DEL DESTINO
    // --------------------------------------------------------

    if (pinDestino.maxConnections > 0 &&
        context.existingTargetConnections.length >=
            pinDestino.maxConnections) {

      return ConnectionValidationResult.deny(
        reason:
        '${pinDestino.label} ya tiene una conexión.',

        showMessage:
        true,
      );
    }

    // --------------------------------------------------------
    // LÍMITE DE CONEXIONES DEL ORIGEN
    // --------------------------------------------------------

    if (pinOrigen.maxConnections > 0 &&
        context.existingSourceConnections.length >=
            pinOrigen.maxConnections) {

      return ConnectionValidationResult.deny(
        reason:
        '${pinOrigen.label} ya tiene una conexión.',

        showMessage:
        true,
      );
    }

    // --------------------------------------------------------
    // La misma conexión no puede existir en la programación
    // por bloques (conflicto Diseño <-> Programación)
    // --------------------------------------------------------
    final conflicto = conflictoDisenoProgramacion(
      disenoOrigen: origen,
      disenoOrigenPin: pinOrigen.id,
      disenoDestino: destino,
      disenoDestinoPin: pinDestino.id,
    );
    if (conflicto != null) {
      return ConnectionValidationResult.deny(
        reason: conflicto,
        showMessage: true,
      );
    }

    return ConnectionValidationResult.allow();
  }

  // ==========================================================
// AGREGAR PINES A COMPONENTES "OTROS"
// ==========================================================

  Future<void> mostrarDialogoAgregarPines(
      Node<PlacedComponent> node) async {

    final componente =
        node.data;

    if (componente.component.category !=
        'Otros') {
      return;
    }

    final accion =
    await showDialog<String>(
      context: context,

      builder:
          (dialogContext) {

        return AlertDialog(
          title:
          const Text(
            'Agregar conexión',
          ),

          content:
          const Text(
            'Seleccione qué tipo de puerto desea agregar:',
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  'entrada',
                );
              },

              child:
              const Text(
                'Entrada digital',
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  'salida',
                );
              },

              child:
              const Text(
                'Salida digital',
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },

              child:
              const Text(
                'Cancelar',
              ),
            ),
          ],
        );
      },
    );

    if (accion == null) {
      return;
    }

    if (accion == 'entrada') {

      final numero =
          componente.inputs.length + 1;

      componente.inputs.add(
        PinModel(
          id:
          'di_$numero',

          label:
          'DI $numero',

          type:
          PinType.digitalInput,

          maxConnections:
          1,

          conexionesPermitidas: {
            PinType.digitalOutput,
          },
        ),
      );
    }

    if (accion == 'salida') {

      final numero =
          componente.outputs.length + 1;

      componente.outputs.add(
        PinModel(
          id:
          'do_$numero',

          label:
          'DO $numero',

          type:
          PinType.digitalOutput,

          maxConnections:
          1,
        ),
      );
    }

    _flowController.setNodePorts(
      node.id,
      _crearPuertosNodeFlow(
        componente,
      ),
    );

    _flowController.notifyNodeDataChanged(
      node.id,
    );

    setState(() {});
  }

  // ==========================================================
  // CREAR PUERTOS DEL COMPONENTE
  // ==========================================================


  static List<Port> _crearPuertosNodeFlow(PlacedComponent componente) {

    final List<Port> puertos = [];

    final bool soloEntradas = componente.outputs.isEmpty;

    final bool soloSalidas = componente.inputs.isEmpty;

    // --------------------------------------------------------
    // ENTRADAS
    // --------------------------------------------------------

    final posicionEntradas = soloEntradas
        ? PortPosition.bottom
        : PortPosition.left;

    for (int i = 0; i < componente.inputs.length; i++) {

      puertos.add(
        _crearPuertoNodeFlow(
          pin: componente.inputs[i],
          esSalida: false,
          indice: i,
          cantidad: componente.inputs.length,
          posicion: posicionEntradas,
        ),
      );
    }

    // --------------------------------------------------------
    // SALIDAS
    // --------------------------------------------------------

    final posicionSalidas = soloSalidas
        ? PortPosition.bottom
        : PortPosition.right;

    for (int i = 0; i < componente.outputs.length; i++) {

      puertos.add(
        _crearPuertoNodeFlow(
          pin: componente.outputs[i],
          esSalida: true,
          indice: i,
          cantidad: componente.outputs.length,
          posicion: posicionSalidas,
        ),
      );
    }

    return puertos;
  }


  // ==========================================================
  // CREAR NODE
  // ==========================================================

  static Node<PlacedComponent> _crearNode(PlacedComponent componente, Offset posicion) {
    final puertos = _crearPuertosNodeFlow(componente);

    return Node<PlacedComponent>(
      id: componente.instanceId,
      type: componente.component.id,
      position: posicion,
      size: const Size(260, 260),
      data: componente,
      ports: puertos, // Se pasa la lista completa de puertos aquí
    );
  }

  // ==========================================================
  // AÑADIR UN COMPONENTE DESDE LA PANTALLA DE ESCANEO DE QR
  //
  // Es estático porque la pantalla de Diseño y conexiones no está
  // abierta en ese momento: el componente se guarda en la lista
  // persistente y en el controlador estático, y aparece al abrirla.
  // ==========================================================

  // Cantidad de componentes añadidos por QR (para no apilarlos).
  static int _anadidosPorQR = 0;

  static PlacedComponent anadirComponenteDesdeQR(ComponentModel componente) {

    int siguienteNumero = 1;

    for (final existente in _componentesPersistentes) {
      if (existente.component.id == componente.id &&
          existente.instanceNumber >= siguienteNumero) {
        siguienteNumero = existente.instanceNumber + 1;
      }
    }

    final nuevo = PlacedComponent(
      instanceId: '${componente.id}_${DateTime.now().microsecondsSinceEpoch}',
      component: componente,
      instanceNumber: siguienteNumero,
    );

    final n = _anadidosPorQR++;

    final posicion = Offset(
      60.0 + (n % 4) * 320.0,
      60.0 + (n ~/ 4) * 320.0,
    );

    _componentesPersistentes.add(nuevo);

    _flowController.addNode(_crearNode(nuevo, posicion));

    _componenteSeleccionadoPersistente = nuevo;

    return nuevo;
  }

  void colocarComponenteEnCanvas(ComponentModel componente, Offset posicionGlobal,) {

    final posicion = _flowController.globalToGraph(
      ScreenPosition(posicionGlobal,),
    )
        .offset;

    // ==========================================================
    // CALCULAR EL SIGUIENTE NÚMERO DE ESTE TIPO DE COMPONENTE
    // ==========================================================

    int siguienteNumero = 1;

    for (final existente in componentesColocados) {

      if (existente.component.id == componente.id) {

        if (existente.instanceNumber >= siguienteNumero) {

          siguienteNumero = existente.instanceNumber + 1;
        }
      }
    }

    // ==========================================================
    // CREAR COMPONENTE
    // ==========================================================

    final nuevo = PlacedComponent(

      instanceId: '${componente.id}_${DateTime.now().microsecondsSinceEpoch}',

      component: componente,

      instanceNumber: siguienteNumero,

    );

    // ==========================================================
    // GUARDAR COMPONENTE
    // ==========================================================

    componentesColocados.add(nuevo,);

    // ==========================================================
    // POSICIÓN
    // ==========================================================

    final posicionNodo = Offset(posicion.dx - 130, posicion.dy - 130,);

    // ==========================================================
    // AÑADIR AL NODE FLOW
    // ==========================================================

    _flowController.addNode(_crearNode(
      nuevo,
      posicionNodo,
    ),
    );

    setState(() {componenteSeleccionado = nuevo;});
  }


  // ==========================================================
  // CABECERA
  // ==========================================================

  Widget construirCabecera(BuildContext context) {

    final size = MediaQuery.of(context).size;

    final alto = (size.height * 0.105).clamp(65.0, 110.0);

    final iconSize =(alto * 0.48).clamp(28.0, 52.0);

    final margen = (size.width * 0.015).clamp(12.0, 30.0);

    return Container(

      height: alto,

      decoration:
      const BoxDecoration(

        border:
        Border(
          bottom:
          BorderSide(
            color:
            Colors.black,
            width:
            1.5,
          ),
        ),
      ),

      child:
      Row(

        children: [

          // ==================================================
          // VOLVER
          // ==================================================

          SizedBox(

            width:
            (size.width * 0.055)
                .clamp(
              65.0,
              120.0,
            ),

            child:
            IconButton(

              iconSize:
              iconSize,

              padding:
              EdgeInsets.only(
                left:
                margen,
              ),

              icon:
              const Icon(
                Icons.arrow_back,
                color:
                Colors.black,
              ),

              tooltip:
              'Volver a inicio',

              onPressed: () {
                AppNav.irAInicio(context);
              },
            ),
          ),


          // ==================================================
          // PROGRAMACIÓN
          // ==================================================

          Expanded(

            child:
            IconButton(

              iconSize:
              iconSize,

              icon:
              const Icon(
                Icons.code,
                color:
                Colors.black,
              ),

              tooltip:
              'Programación por bloques',

              onPressed: () {
                AppNav.cambiarA(
                  context,
                  const ProgrammingScreen(),
                );
              },
            ),
          ),


          // ==================================================
          // MONITOREO
          // ==================================================

          Expanded(

            child:
            IconButton(

              iconSize:
              iconSize,

              icon:
              const Icon(
                Icons.monitor_heart_outlined,
                color:
                Colors.black,
              ),

              tooltip:
              'Monitoreo síncrono',

              onPressed: () {
                AppNav.cambiarA(
                  context,
                  const MonitoreoScreen(),
                );
              },
            ),
          ),


          // ==================================================
          // TÍTULO
          // ==================================================

          Expanded(

            flex:
            2,

            child:
            Center(

              child:
              Text(

                'Diseño y Conexiones',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(

                  fontSize:
                  (alto * 0.30)
                      .clamp(
                    18.0,
                    32.0,
                  ),

                  fontWeight:
                  FontWeight.w500,

                  color:
                  Colors.black,
                ),
              ),
            ),
          ),


          // ==================================================
          // COMPONENTES
          // ==================================================

          Expanded(

            child:
            IconButton(

              iconSize:
              iconSize,

              icon:
              const Icon(
                Icons.list,
                color:
                Colors.black,
              ),

              tooltip:
              'Componentes',

              onPressed: () {

                setState(() {

                  mostrarComponentes =
                  !mostrarComponentes;

                });

              },
            ),
          ),


          // ==================================================
          // COMENZAR
          // ==================================================

          SizedBox(
            width:
            (size.width * 0.07)
                .clamp(
              80.0,
              140.0,
            ),
            child: AnimatedBuilder(
              animation: EjecutorGlobal.instance,
              builder: (context, _) {
                final corriendo = EjecutorGlobal.instance.corriendo;
                return Tooltip(
                  message: corriendo ? 'Parar' : 'Comenzar',
                  child: InkWell(
                    onTap: _alternarEjecucion,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          corriendo
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline,
                          size: iconSize,
                          color: corriendo ? Colors.red : Colors.black,
                        ),
                        Text(
                          corriendo ? 'Parar' : 'Comenzar',
                          style: TextStyle(
                            fontSize: (alto * 0.17).clamp(10.0, 14.0),
                            fontWeight: FontWeight.w500,
                            color: corriendo ? Colors.red : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // ==========================================================
  // BARRA DE HERRAMIENTAS
  // ==========================================================

  Widget construirHerramientas(
      BuildContext context) {

    final ancho =
        MediaQuery.of(context).size.width;

    final anchoBoton =
    (ancho * 0.045)
        .clamp(
      48.0,
      75.0,
    );

    final tamanoIcono =
    (ancho * 0.018)
        .clamp(
      20.0,
      32.0,
    );


    return Container(

      height:
      w(
        context,
        65,
      ).clamp(
        48.0,
        75.0,
      ),

      decoration:
      const BoxDecoration(

        border:
        Border(
          bottom:
          BorderSide(
            color:
            Colors.black,
            width:
            1.5,
          ),
        ),
      ),

      child:
      Row(

        children: [

          // DESHACER

          SizedBox(

            width:
            anchoBoton,

            child:
            IconButton(

              padding:
              EdgeInsets.zero,

              iconSize:
              tamanoIcono,

              icon:
              const Icon(
                Icons.undo,
                color:
                Colors.black,
              ),

              tooltip:
              'Deshacer',

              onPressed: () {},
            ),
          ),


          // REHACER

          SizedBox(

            width:
            anchoBoton,

            child:
            IconButton(

              padding:
              EdgeInsets.zero,

              iconSize:
              tamanoIcono,

              icon:
              const Icon(
                Icons.redo,
                color:
                Colors.black,
              ),

              tooltip:
              'Rehacer',

              onPressed: () {},
            ),
          ),


          // NOMBRE DEL COMPONENTE

          Expanded(

            child:
            Container(

              decoration:
              mostrarComponentes

                  ? const BoxDecoration(
                border:
                Border(
                  right:
                  BorderSide(
                    color:
                    Colors.black,
                    width:
                    1.5,
                  ),
                ),
              )

                  : null,

              padding:
              EdgeInsets.symmetric(
                horizontal:
                w(
                  context,
                  20,
                ).clamp(
                  10.0,
                  25.0,
                ),
              ),

              alignment:
              Alignment.centerLeft,

              child:
              Text(

                componenteSeleccionado
                    ?.component.name ??
                    'Nombre del componente',

                maxLines:
                1,

                overflow:
                TextOverflow.ellipsis,

                style:
                TextStyle(

                  fontSize:
                  w(
                    context,
                    22,
                  ).clamp(
                    14.0,
                    24.0,
                  ),

                  color:
                  Colors.black,

                  fontWeight:
                  FontWeight.w500,
                ),
              ),
            ),
          ),


          // ==================================================
          // CATEGORÍAS
          // ==================================================

          if (mostrarComponentes) ...[

            Expanded(
              child:
              construirBotonCategoria(
                context,
                'Sensores',
              ),
            ),

            Expanded(
              child:
              construirBotonCategoria(
                context,
                'Actuadores',
              ),
            ),

            Expanded(
              child:
              construirBotonCategoria(
                context,
                'Otros',
              ),
            ),
          ],
        ],
      ),
    );
  }


  // ==========================================================
  // BOTÓN DE CATEGORÍA
  // ==========================================================

  Widget construirBotonCategoria(
      BuildContext context,
      String nombre) {

    final seleccionado =
        tipoSeleccionado ==
            nombre;


    return GestureDetector(

      onTap: () {

        setState(() {

          tipoSeleccionado =
              nombre;

        });

      },

      child:
      Container(

        decoration:
        BoxDecoration(

          color:
          seleccionado
              ? Colors.black
              : Colors.white,
        ),

        alignment:
        Alignment.center,

        child:
        Text(

          nombre,

          textAlign:
          TextAlign.center,

          style:
          TextStyle(

            fontSize:
            w(
              context,
              17,
            ).clamp(
              11.0,
              18.0,
            ),

            color:
            seleccionado
                ? Colors.white
                : Colors.black,

            fontWeight:
            seleccionado
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ),
    );
  }


  // ==========================================================
  // LISTA LATERAL DE COMPONENTES
  // ==========================================================

  Widget construirListaComponentes(
      BuildContext context) {

    final componentes =
        componentesCategoria;


    return Expanded(

      child:
      ListView.builder(

        padding:
        EdgeInsets.all(
          w(
            context,
            12,
          ).clamp(
            8.0,
            15.0,
          ),
        ),

        itemCount:
        componentes.length,

        itemBuilder:
            (context, index) {

          final componente =
          componentes[index];


          return Padding(

            padding:
            EdgeInsets.only(
              bottom:
              w(
                context,
                12,
              ).clamp(
                8.0,
                14.0,
              ),
            ),

            child:
            LongPressDraggable<ComponentModel>(

              data:
              componente,

              dragAnchorStrategy:
              pointerDragAnchorStrategy,

              feedback:
              Material(

                color:
                Colors.transparent,

                child:
                construirVistaComponente(
                  context,
                  componente,
                  false,
                ),
              ),

              child:
              Container(

                padding:
                EdgeInsets.all(
                  w(
                    context,
                    10,
                  ).clamp(
                    7.0,
                    12.0,
                  ),
                ),

                decoration:
                BoxDecoration(

                  border:
                  Border.all(
                    color:
                    Colors.black,
                    width:
                    1.5,
                  ),
                ),

                child:
                Row(

                  children: [

                    construirMiniatura(
                      context,
                      componente,
                    ),

                    SizedBox(
                      width:
                      w(
                        context,
                        12,
                      ).clamp(
                        8.0,
                        14.0,
                      ),
                    ),

                    Expanded(

                      child:
                      Text(

                        componente.name,

                        style:
                        TextStyle(

                          fontSize:
                          w(
                            context,
                            18,
                          ).clamp(
                            12.0,
                            20.0,
                          ),

                          color:
                          Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  // ==========================================================
  // MINIATURA
  // ==========================================================

  Widget construirMiniatura(
      BuildContext context,
      ComponentModel componente) {

    return SizedBox(

      width:
      w(
        context,
        70,
      ).clamp(
        45.0,
        75.0,
      ),

      height:
      w(
        context,
        55,
      ).clamp(
        40.0,
        60.0,
      ),

      child:
      ImagenComponente(
        modelo: componente,
        tamanoIcono: w(context, 40).clamp(28.0, 42.0),
      ),
    );
  }


  // ==========================================================
  // PANEL LATERAL
  // ==========================================================

  Widget construirPanelComponentes(
      BuildContext context) {

    return Container(

      decoration:
      const BoxDecoration(

        border:
        Border(
          left:
          BorderSide(
            color:
            Colors.black,
            width:
            1.5,
          ),
        ),
      ),

      child:
      Column(

        children: [

          construirListaComponentes(
            context,
          ),

        ],
      ),
    );
  }


  // ==========================================================
  // VISTA DEL COMPONENTE EN EL ÁREA DE TRABAJO
  // ==========================================================

  Widget construirVistaComponente(BuildContext context,
      ComponentModel componente, bool mostrarEstado) {

    return Container(

      width:
      230,

      padding:
      const EdgeInsets.all(10),

      decoration:
      BoxDecoration(

        color:
        Colors.white,

        border:
        Border.all(
          color:
          Colors.black,
          width:
          1.5,
        ),
      ),

      child:
      Column(

        mainAxisSize:
        MainAxisSize.min,

        children: [

          if (mostrarEstado)

            Container(

              width:
              double.infinity,

              padding:
              const EdgeInsets.symmetric(
                vertical:
                4,
              ),

              child:
              const Text(

                'OFF',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(

                  fontSize:
                  14,

                  fontWeight:
                  FontWeight.bold,

                  color:
                  Colors.black,
                ),
              ),
            ),


          SizedBox(

            height:
            105,

            child:
            ImagenComponente(
              modelo: componente,
              tamanoIcono: 65,
            ),
          ),


          const SizedBox(
            height:
            5,
          ),


          Text(

            componente.name,

            textAlign:
            TextAlign.center,

            maxLines:
            2,

            overflow:
            TextOverflow.ellipsis,

            style:
            const TextStyle(

              fontSize:
              14,

              fontWeight:
              FontWeight.w500,

              color:
              Colors.black,
            ),
          ),


          const SizedBox(
            height:
            8,
          ),


          // ==================================================
          // PINES
          // ==================================================

          Row(

            mainAxisAlignment:
            MainAxisAlignment.center,

            children: [

              ...componente.inputs.map(
                    (pin) =>
                    _construirIndicadorPin(
                      pin,
                    ),
              ),

              ...componente.outputs.map(
                    (pin) =>
                    _construirIndicadorPin(
                      pin,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
// VISTA VISUAL DEL NODE FLOW
// ==========================================================

  Widget construirNodeFlow(BuildContext context, Node<PlacedComponent> node) {
    // Se redibuja solo cuando cambia el estado del sistema (ON/OFF).
    return AnimatedBuilder(
      animation: EjecutorGlobal.instance,
      builder: (context, _) => _construirContenidoNodo(context, node),
    );
  }

  Widget _construirContenidoNodo(BuildContext context, Node<PlacedComponent> node) {

    final componente = node.data;

    final modelo = componente.component;

    final bool activo = componente.activo;

    // Sensor analógico (presión): una sola imagen y la medida
    // (en bar) arriba del bloque, en lugar de ON/OFF.
    final String? medidaAnalogica =
    EjecutorGlobal.instance.textoMedidaAnalogica(componente);

    // Imagen según el estado: apagado / encendido.
    final String imagen = activo && modelo.imageOnAsset != null
        ? modelo.imageOnAsset!
        : modelo.imageAsset;

    return Container(

      width: 260,

      height: 260,

      padding: const EdgeInsets.all(10),

      // ISA-101: fondo gris claro y borde de bajo contraste. El estado
      // se ve en la imagen, no en el color del bloque.
      decoration: BoxDecoration(

        color: kIsaFondo,

        border: Border.all(
          color: node.isSelected ? Colors.black : kIsaBorde,
          width: node.isSelected ? 2.5 : 1.5,
        ),
      ),

      child: Column(

        mainAxisAlignment: MainAxisAlignment.start,

        children: [

          // ======================================================
          // MEDIDA ANALÓGICA (arriba del bloque)
          // ======================================================

          if (medidaAnalogica != null) ...[

            Container(

              width: double.infinity,

              height: 30,

              alignment: Alignment.center,

              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: kIsaBorde, width: 1.2),
              ),

              child: Text(
                medidaAnalogica == '--'
                    ? '-- ${componente.unidadMedida}'
                    : medidaAnalogica,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kIsaTexto,
                ),
              ),
            ),

            const SizedBox(height: 4),
          ],

          // ======================================================
          // NOMBRE + NÚMERO
          // ======================================================

          SizedBox(

            width: double.infinity,

            height: 28,

            child: Text(

              '${modelo.name} ${componente.instanceNumber}',

              textAlign: TextAlign.center,

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kIsaTexto,
              ),
            ),
          ),

          // ======================================================
          // CUADRADO DE IMAGEN
          // ======================================================

          Container(

            width: 145,

            height: 145,

            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: kIsaBorde, width: 1.2),
            ),

            alignment: Alignment.center,

            child: Padding(

              padding: const EdgeInsets.all(8),

              child: ImagenComponente(
                modelo: modelo,
                asset: imagen,
                encendido: activo,
                colorLed: componente.colorLed,
                tamanoIcono: 70,
              ),
            ),
          ),

          // ======================================================
          // ESTADO ON / OFF (los sensores analógicos no lo llevan)
          // ======================================================

          if (medidaAnalogica == null) ...[

            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: activo ? kIsaOn : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                activo ? 'ON' : 'OFF',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: activo ? Colors.white : kIsaTexto,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // INDICADOR DE PIN
  // ==========================================================

  Widget _construirIndicadorPin(
      PinModel pin) {

    final bool esEntrada =
        pin.type ==
            PinType.digitalInput ||
            pin.type ==
                PinType.analogInput;


    return Container(

      margin:
      const EdgeInsets.symmetric(
        horizontal:
        4,
      ),

      child:
      Column(

        children: [

          Container(

            width:
            14,

            height:
            14,

            decoration:
            BoxDecoration(

              shape:
              BoxShape.circle,

              border:
              Border.all(
                color:
                esEntrada
                    ? Colors.black
                    : Colors.blue,
                width:
                2,
              ),
            ),
          ),

          const SizedBox(
            height:
            3,
          ),

          Text(

            pin.label,

            style:
            TextStyle(

              fontSize:
              10,

              fontWeight:
              FontWeight.bold,

              color:
              esEntrada
                  ? Colors.black
                  : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CALIBRAR EL SENSOR DE PRESIÓN
  // ==========================================================

  Future<void> _abrirCalibracion(PlacedComponent componente) async {

    final resultado = await showDialog<_ResultadoCalibracion>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _DialogoCalibracion(componente: componente);
      },
    );

    if (resultado == null || !mounted) {
      return;
    }

    setState(() {
      componente.calibA = resultado.a;
      componente.calibB = resultado.b;
      componente.calibR2 = resultado.r2;
      componente.calibPuntos = resultado.puntos;
    });

    if (resultado.restablecer) {

      _mensaje('Calibración restablecida a los valores de fábrica.');

    } else {

      _mensaje(
        'Calibración aplicada: A = ${resultado.a.toStringAsFixed(4)}, '
            'B = ${resultado.b.toStringAsFixed(4)}, '
            'R² = ${(resultado.r2! * 100).toStringAsFixed(2)} %.',
      );
    }
  }

  Future<void> eliminarComponenteSeleccionado() async {

    final componente =
        componenteSeleccionado;

    if (componente == null) {
      return;
    }

    final confirmar =
    await showDialog<bool>(

      context:
      context,

      builder:
          (dialogContext) {

        return AlertDialog(

          title:
          const Text(
            'Eliminar componente',
          ),

          content:
          Text(
            '¿Desea eliminar '
                '${componente.component.name} '
                '${componente.instanceNumber}?',
          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
              const Text(
                'Cancelar',
              ),
            ),

            TextButton(

              onPressed: () {

                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
              const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    // ==========================================================
    // ELIMINAR DEL NODE FLOW
    // ==========================================================

    _flowController.removeNode(
      componente.instanceId,
    );

    // ==========================================================
    // ELIMINAR DE LA LISTA PERSISTENTE
    // ==========================================================

    componentesColocados.removeWhere(
          (elemento) =>
      elemento.instanceId ==
          componente.instanceId,
    );

    // ==========================================================
    // QUITAR SELECCIÓN
    // ==========================================================

    setState(() {

      componenteSeleccionado =
      null;
    });
  }

  // ==========================================================
  // INFORMACIÓN DEL COMPONENTE
  // ==========================================================

  // Selector del color del LED (aparece en su información).
  List<Widget> _construirSelectorColorLed(
      BuildContext context,
      PlacedComponent componente) {

    return [

      Text(
        'Color:',
        style: TextStyle(
          fontSize: w(context, 18).clamp(13.0, 20.0),
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 8),

      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (int i = 0; i < kColoresLed.length; i++)
            Tooltip(
              message: kColoresLed[i].nombre,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    componente.indiceColorLed = i;
                  });
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: kColoresLed[i].color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: componente.indiceColorLed == i
                          ? Colors.black
                          : Colors.grey.shade500,
                      width: componente.indiceColorLed == i ? 3.5 : 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      const SizedBox(height: 20),
    ];
  }

  // Selector del sonido del Buzzer (aparece en su información).
  List<Widget> _construirSelectorSonido(
      BuildContext context,
      PlacedComponent componente) {

    final seleccionado =
    BuzzerManager.sonidos.containsKey(componente.sonido)
        ? componente.sonido
        : BuzzerManager.sonidoPorDefecto;

    return [

      Text(
        'Sonido:',
        style: TextStyle(
          fontSize: w(context, 18).clamp(13.0, 20.0),
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 6),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: seleccionado,
            items: [
              for (final entrada in BuzzerManager.sonidos.entries)
                DropdownMenuItem<String>(
                  value: entrada.key,
                  child: Text(entrada.value.nombre),
                ),
            ],
            onChanged: (nuevo) {
              if (nuevo == null) return;
              setState(() {
                componente.sonido = nuevo;
              });
              // Se escucha un momento el sonido elegido.
              BuzzerManager.instance.probar(nuevo);
            },
          ),
        ),
      ),

      const SizedBox(height: 8),

      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            BuzzerManager.instance.probar(seleccionado);
          },
          icon: const Icon(
            Icons.volume_up_outlined,
            color: Colors.black,
          ),
          label: const Text(
            'Probar sonido',
            style: TextStyle(color: Colors.black),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(
              color: Colors.black,
              width: 1.5,
            ),
          ),
        ),
      ),

      const SizedBox(height: 20),
    ];
  }

  Widget construirInformacionComponente(BuildContext context) {
    // Se redibuja cuando cambia el estado (ON/OFF) del sistema.
    return AnimatedBuilder(
      animation: EjecutorGlobal.instance,
      builder: (context, _) =>
          _construirInformacionComponenteInterna(context),
    );
  }

  Widget _construirInformacionComponenteInterna(BuildContext context) {

    final componente = componenteSeleccionado;

    if (componente == null) {

      return Container(

        decoration:
        const BoxDecoration(

          border:
          Border(
            left:
            BorderSide(
              color:
              Colors.black,
              width:
              1.5,
            ),
          ),
        ),

        child:
        const Center(

          child:
          Text(

            'Seleccione un componente\n'
                'para ver su información',

            textAlign:
            TextAlign.center,

            style:
            TextStyle(

              fontSize:
              20,

              color:
              Colors.grey,
            ),
          ),
        ),
      );
    }

    final modelo = componente.component;

    final entradas =
        componente.inputs;

    final salidas =
        componente.outputs;

    return Container(

      decoration: const BoxDecoration(

        border:
        Border(
          left:
          BorderSide(
            color:
            Colors.black,
            width:
            1.5,
          ),
        ),
      ),

      child: SingleChildScrollView(

        physics:
        const BouncingScrollPhysics(),

        child: Padding(

          padding:
          EdgeInsets.all(
            w(
              context,
              20,
            ).clamp(
              12.0,
              25.0,
            ),
          ),

          child: Column(

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              Text(

                'Información del componente',

                style:
                TextStyle(

                  fontSize:
                  w(
                    context,
                    20,
                  ).clamp(
                    14.0,
                    22.0,
                  ),

                  fontWeight:
                  FontWeight.bold,

                  color:
                  Colors.black,
                ),
              ),


              SizedBox(
                height:
                w(
                  context,
                  20,
                ).clamp(
                  12.0,
                  22.0,
                ),
              ),


              Text(

                modelo.name,

                style:
                TextStyle(

                  fontSize:
                  w(
                    context,
                    19,
                  ).clamp(
                    13.0,
                    21.0,
                  ),

                  fontWeight:
                  FontWeight.w600,

                  color:
                  Colors.black,
                ),
              ),


              SizedBox(
                height:
                w(
                  context,
                  15,
                ).clamp(
                  10.0,
                  18.0,
                ),
              ),


              Text(

                'Tipo: ${modelo.category}',

                style:
                TextStyle(

                  fontSize:
                  w(
                    context,
                    17,
                  ).clamp(
                    13.0,
                    19.0,
                  ),
                ),
              ),


              SizedBox(
                height:
                w(
                  context,
                  15,
                ).clamp(
                  10.0,
                  18.0,
                ),
              ),

              Text(

                EjecutorGlobal.instance.textoMedidaAnalogica(componente) !=
                    null
                    ? 'Medida: '
                    '${EjecutorGlobal.instance.textoMedidaAnalogica(componente)}'
                    : 'Estado: '
                    '${componente.activo ? 'ON' : 'OFF'}',

                style:
                TextStyle(

                  fontSize:
                  w(
                    context,
                    18,
                  ).clamp(
                    13.0,
                    20.0,
                  ),

                  fontWeight:
                  FontWeight.bold,
                ),
              ),


              SizedBox(
                height:
                w(
                  context,
                  20,
                ).clamp(
                  12.0,
                  20.0,
                ),
              ),


              // ==================================================
              // SONIDO (solo Buzzer)
              // ==================================================

              if (modelo.id == 'buzzer')
                ..._construirSelectorSonido(context, componente),

              // ==================================================
              // COLOR (solo LED)
              // ==================================================

              if (modelo.id == 'led')
                ..._construirSelectorColorLed(context, componente),

              // ==================================================
              // ENTRADAS
              // ==================================================

              Text(

                'Entradas:',

                style:
                TextStyle(

                  fontSize:
                  w(
                    context,
                    18,
                  ).clamp(
                    13.0,
                    20.0,
                  ),

                  fontWeight:
                  FontWeight.bold,
                ),
              ),


              if (entradas.isEmpty)

                const Padding(

                  padding:
                  EdgeInsets.only(
                    top:
                    5,
                  ),

                  child:
                  Text(
                    'Ninguna',
                  ),
                )

              else

                ...entradas.map(
                      (pin) => Padding(

                    padding:
                    const EdgeInsets.only(
                      top:
                      6,
                    ),

                    child: Text(
                      '${pin.label}: '
                          '${pin.tipoTexto}${_textoAsignacion(componente, pin)}',
                    ),
                  ),
                ),


              SizedBox(
                height:
                w(
                  context,
                  18,
                ).clamp(
                  10.0,
                  18.0,
                ),
              ),


              // ==================================================
              // SALIDAS
              // ==================================================

              Text(

                'Salidas:',

                style:
                TextStyle(

                  fontSize:
                  w(
                    context,
                    18,
                  ).clamp(
                    13.0,
                    20.0,
                  ),

                  fontWeight:
                  FontWeight.bold,
                ),
              ),


              if (salidas.isEmpty)

                const Padding(

                  padding:
                  EdgeInsets.only(
                    top:
                    5,
                  ),

                  child:
                  Text(
                    'Ninguna',
                  ),
                )

              else

                ...salidas.map(
                      (pin) =>
                      Padding(

                        padding:
                        const EdgeInsets.only(
                          top:
                          6,
                        ),

                        child:
                        Text(
                          '${pin.label}: '
                              '${pin.tipoTexto}${_textoAsignacion(componente, pin)}',
                        ),
                      ),
                ),


              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // BOTÓN ASIGNAR
              // ==================================================

              SizedBox(

                width:
                double.infinity,

                height:
                w(
                  context,
                  55,
                ).clamp(
                  42.0,
                  60.0,
                ),

                child:
                OutlinedButton(

                  onPressed:
                  _asignarPin,

                  style:
                  OutlinedButton.styleFrom(

                    side:
                    const BorderSide(
                      color:
                      Colors.black,
                      width:
                      2,
                    ),

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        25,
                      ),
                    ),
                  ),

                  child:
                  Text(

                    'Asignar',

                    style: TextStyle(

                      fontSize:
                      w(
                        context,
                        18,
                      ).clamp(
                        13.0,
                        20.0,
                      ),

                      color:
                      Colors.black,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                12,
              ),

// ==================================================
// BOTÓN CALIBRAR (solo sensor de presión)
// ==================================================

              if (modelo.id == kIdSensorPresion)

                SizedBox(

                  width:
                  double.infinity,

                  height:
                  w(
                    context,
                    55,
                  ).clamp(
                    42.0,
                    60.0,
                  ),

                  child:
                  OutlinedButton(

                    onPressed: () {
                      _abrirCalibracion(componente);
                    },

                    style:
                    OutlinedButton.styleFrom(

                      foregroundColor:
                      Colors.black,

                      side:
                      const BorderSide(

                        color:
                        Colors.black,

                        width:
                        2,
                      ),

                      shape:
                      RoundedRectangleBorder(

                        borderRadius:
                        BorderRadius.circular(
                          25,
                        ),
                      ),
                    ),

                    child:
                    Text(

                      'Calibrar',

                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(

                        fontSize:
                        w(
                          context,
                          18,
                        ).clamp(
                          13.0,
                          20.0,
                        ),

                        color:
                        Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ÁREA DE TRABAJO NODE FLOW
  // ==========================================================

  Widget construirEspacioTrabajo(
      BuildContext context) {

    final theme =
    NodeFlowTheme.light.copyWith(
      portTheme:
      PortTheme.light.copyWith(
        size: const Size(_puertoTam, _puertoTam),
        labelTextStyle: _estiloEtiquetaPuerto,
        labelOffset: 4,
      ),
    );

    return Stack(
      children: [

        // ======================================================
        // NODE FLOW
        // ======================================================

        DragTarget<ComponentModel>(

          onWillAcceptWithDetails:
              (details) {
            return true;
          },

          onAcceptWithDetails:
              (details) {

            colocarComponenteEnCanvas(
              details.data,
              details.offset,
            );
          },

          builder:
              (
              context,
              candidateData,
              rejectedData,
              ) {

            return Stack(
              children: [

                Positioned.fill(
                  child:
                  Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (evento) {
                        _ultimoToqueGlobal = evento.position;
                      },
                      child:
                      NodeFlowEditor<
                          PlacedComponent,
                          dynamic>(
                        controller:
                        _flowController,

                        theme:
                        theme,

                        behavior:
                        NodeFlowBehavior.design,

                        nodeBuilder:
                        construirNodeFlow,

                        events:
                        NodeFlowEvents<
                            PlacedComponent,
                            dynamic>(

                          // ----------------------------------------
                          // NODOS
                          // ----------------------------------------
                          node:
                          NodeEvents<PlacedComponent>(
                            onTap: (node) {
                              _DesignScreenState._activo
                                  ?._manejarToqueNodo(node);
                            },
                            onDoubleTap: (node) async {
                              await _DesignScreenState._activo
                                  ?._dobleToqueNodo(node);
                            },
                          ),

                          // ----------------------------------------
                          // CONEXIONES
                          // ----------------------------------------
                          connection:
                          ConnectionEvents<
                              PlacedComponent,
                              dynamic>(
                            // COMPROBAR SI SE PUEDE INICIAR EL CABLE
                            onBeforeStart: (context) {
                              return _DesignScreenState._activo
                                  ?._validarInicioConexion(context) ??
                                  ConnectionValidationResult.deny(
                                    reason: 'La pantalla no está lista.',
                                    showMessage: false,
                                  );
                            },

                            // COMPROBAR SI SE PUEDE TERMINAR EL CABLE
                            onBeforeComplete: (context) {
                              return _DesignScreenState._activo
                                  ?._validarConexion(context) ??
                                  ConnectionValidationResult.deny(
                                    reason: 'La pantalla no está lista.',
                                    showMessage: false,
                                  );
                            },

                            // CONEXIÓN CREADA
                            onCreated: (connection) {
                              _DesignScreenState._activo
                                  ?._alCrearConexion();
                            },

                            // TOCAR UN CABLE (solo con el botón Cable activo)
                            onTap: (connection) {
                              _DesignScreenState._activo
                                  ?._tocarCable(connection);
                            },
                          ),

                          // ----------------------------------------
                          // CANVAS
                          // ----------------------------------------
                          viewport:
                          ViewportEvents(
                            onCanvasTap: (position) {
                              _DesignScreenState._activo?._tocarCanvas();
                            },
                          ),
                        ),
                      )
                  ),
                ),

                // ==================================================
                // MENSAJE INICIAL
                // ==================================================

                if (_flowController.nodes.isEmpty)

                  const IgnorePointer(
                    child:
                    Center(
                      child:
                      Text(
                        'Arrastre un componente aquí',

                        style:
                        TextStyle(
                          fontSize:
                          22,

                          color:
                          Colors.grey,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // ======================================================
        // AVISO DE MODO ACTIVO
        // ======================================================

        if (_modoMover || _modoCable || _modoEliminar)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _textoModoActivo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ======================================================
        // BOTÓN ELIMINAR COMPONENTE
        // ======================================================

        Positioned(
          left: w(context, 20).clamp(12.0, 25.0) +
              (w(context, 90).clamp(65.0, 100.0) + 12) * 2,
          bottom: w(context, 20).clamp(12.0, 25.0),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: _alternarModoEliminar,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: w(context, 90).clamp(65.0, 100.0),
                height: w(context, 90).clamp(65.0, 100.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _modoEliminar ? Colors.blue : Colors.black,
                    width: _modoEliminar ? 3 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: w(context, 48).clamp(32.0, 55.0),
                  color: _modoEliminar ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),

        // ======================================================
        // BOTÓN MOVER
        // ======================================================

        Positioned(
          left: w(context, 20).clamp(12.0, 25.0) +
              w(context, 90).clamp(65.0, 100.0) +
              12,
          bottom: w(context, 20).clamp(12.0, 25.0),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: _alternarModoMover,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: w(context, 90).clamp(65.0, 100.0),
                height: w(context, 90).clamp(65.0, 100.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _modoMover ? Colors.blue : Colors.black,
                    width: _modoMover ? 3 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.open_with,
                  size: w(context, 48).clamp(32.0, 55.0),
                  color: _modoMover ? Colors.blue : Colors.black,
                ),
              ),
            ),
          ),
        ),

        // ======================================================
        // BOTÓN CABLE
        // ======================================================

        Positioned(
          left:
          w(
            context,
            20,
          ).clamp(
            12.0,
            25.0,
          ),

          bottom:
          w(
            context,
            20,
          ).clamp(
            12.0,
            25.0,
          ),

          child:
          Material(
            color:
            Colors.white,

            child:
            InkWell(
              onTap: _alternarModoCable,

              borderRadius:
              BorderRadius.circular(
                15,
              ),

              child:
              Container(
                width:
                w(
                  context,
                  90,
                ).clamp(
                  65.0,
                  100.0,
                ),

                height:
                w(
                  context,
                  90,
                ).clamp(
                  65.0,
                  100.0,
                ),

                decoration:
                BoxDecoration(
                  border:
                  Border.all(
                    color:
                    _modoCable
                        ? Colors.blue
                        : Colors.black,

                    width:
                    _modoCable
                        ? 3
                        : 1.5,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                ),

                child:
                Icon(
                  Icons.cable,

                  size:
                  w(
                    context,
                    48,
                  ).clamp(
                    32.0,
                    55.0,
                  ),

                  color:
                  _modoCable
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      backgroundColor:
      Colors.white,

      body:
      SafeArea(

        child:
        Column(

          children: [

            // CABECERA

            construirCabecera(
              context,
            ),


            // HERRAMIENTAS

            construirHerramientas(
              context,
            ),


            // CONTENIDO

            Expanded(

              child:
              Row(

                children: [

                  // ==========================================
                  // ÁREA DE TRABAJO
                  // ==========================================

                  Expanded(

                    flex:
                    mostrarComponentes
                        ? 70
                        : 68,

                    child:
                    construirEspacioTrabajo(
                      context,
                    ),
                  ),


                  // ==========================================
                  // INFORMACIÓN (oculta si el panel de
                  // componentes está abierto)
                  // ==========================================

                  if (!mostrarComponentes)

                    Expanded(

                      flex: 32,

                      child:
                      construirInformacionComponente(
                        context,
                      ),
                    ),


                  // ==========================================
                  // COMPONENTES
                  // ==========================================

                  if (mostrarComponentes)

                    Expanded(
                      flex:
                      30,

                      child:
                      construirPanelComponentes(
                        context,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// FONDO DEL ESPACIO DE TRABAJO
// ============================================================

class EspacioTrabajoPainter extends CustomPainter {

  @override
  void paint(
      Canvas canvas,
      Size size) {

    final paint =
    Paint()
      ..color =
      Colors.grey.withOpacity(
        0.12,
      )
      ..strokeWidth =
      1;

    const double separacion = 50;


    for (
    double x = 0;
    x < size.width;
    x += separacion
    ) {

      canvas.drawLine(

        Offset(
          x,
          0,
        ),

        Offset(
          x,
          size.height,
        ),

        paint,
      );
    }


    for (
    double y = 0;
    y < size.height;
    y += separacion
    ) {

      canvas.drawLine(

        Offset(
          0,
          y,
        ),

        Offset(
          size.width,
          y,
        ),

        paint,
      );
    }
  }


  @override
  bool shouldRepaint(
      covariant
      EspacioTrabajoPainter
      oldDelegate) {

    return false;
  }
}


// ============================================================
// PANTALLA DE PROGRAMACIÓN POR BLOQUES
// ============================================================

class ProgrammingScreen extends StatefulWidget {
  const ProgrammingScreen({super.key});

  @override
  State<ProgrammingScreen> createState() =>
      _ProgrammingScreenState();
}


// ============================================================
// MODELO VISUAL DE LOS BLOQUES DE PROGRAMACIÓN
//
// Estos modelos describen la apariencia y los tipos de
// entradas/salidas de cada bloque. La ejecución de la lógica,
// las comparaciones y los temporizadores se realiza en EjecutorGlobal.
// ============================================================

enum ProgramPinType {
  digitalInput,
  digitalOutput,
  analogInput,
  analogOutput,
}

class ProgramBlockDefinition {
  final String id;
  final String nombre;
  final String categoria;
  final int entradas;
  final int salidas;
  final ProgramPinType tipoEntrada;
  final ProgramPinType tipoSalida;

  const ProgramBlockDefinition({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.entradas,
    required this.salidas,
    required this.tipoEntrada,
    required this.tipoSalida,
  });

  // Los bloques DI, DO y AI representan un puerto físico de un
  // módulo y se asignan a módulo + puerto.
  bool get esES =>
      id == 'IN_DI' || id == 'OUT_DO' || id == 'IN_AI';

  // Los bloques V DI y V DO representan un Switch/Botón o un LED
  // virtual de Diseño y Conexiones (no usan módulos físicos).
  bool get esVirtual =>
      id == 'V_DI' || id == 'V_DO';
}


// Bloque colocado en el espacio de trabajo. La posición NO se
// guarda aquí: la administra el NodeFlowController (igual que en
// Diseño y Conexiones), por eso mover un bloque ya no lo duplica.
class ProgramBlockInstance {
  final String id;
  final ProgramBlockDefinition definition;

  // Número de esta instancia. Ejemplo: AND 1, AND 2, TON 1...
  final int numero;

  // Asignación (solo bloques de E/S): módulo 1-4 y puerto 1..N.
  // null = sin asignar.
  int? modulo;
  int? puerto;

  // Asignación (solo bloques V DI / V DO): clave de la variable
  // virtual de Diseño y Conexiones ('instanceId|pinId').
  String? varClave;

  // Si no es null, este bloque representa un componente de una conexión
  // hecha en Diseño y Conexiones (id de esa conexión).
  final String? espejoDe;

  // Nombre del componente que representa (solo bloques espejo).
  String? etiqueta;

  // Valor de comparación (solo bloques >= y <). Está en la unidad
  // final de la entrada: bar para el sensor de presión, V para el
  // resto. null = sin configurar.
  double? umbral;

  // Tiempo preestablecido de TON/TOF, expresado en segundos.
  // Se limita en el diálogo a valores entre 1 y 20 segundos.
  double? tiempoSegundos;

  bool get esEspejo => espejoDe != null;

  bool get asignado => definition.esVirtual
      ? varClave != null
      : (modulo != null && puerto != null);

  ProgramBlockInstance({
    required this.id,
    required this.definition,
    required this.numero,
    this.modulo,
    this.puerto,
    this.varClave,
    this.espejoDe,
    this.etiqueta,
  });

  String get nombreCompleto =>
      etiqueta ?? '${definition.nombre} $numero';
}


// Puerto (entrada o salida) de un bloque.
class _PuertoBloque {
  final String id;
  final String label;
  final ProgramPinType tipo;

  const _PuertoBloque({
    required this.id,
    required this.label,
    required this.tipo,
  });
}


String _textoTipoPuerto(ProgramPinType tipo) {

  switch (tipo) {

    case ProgramPinType.digitalInput:
      return 'DI';

    case ProgramPinType.digitalOutput:
      return 'DO';

    case ProgramPinType.analogInput:
      return 'AI';

    case ProgramPinType.analogOutput:
      return 'AO';
  }
}


// Variables virtuales de Diseño y Conexiones (pines sin asignar de
// componentes de la categoría 'Otros': Switch, Botón, LED).
//   V DI n = señal de un Switch/Botón
//   V DO n = entrada de un LED
// La numeración es la misma que usa la pantalla de Monitoreo.
List<VariableMonitoreo> variablesVirtualesDeDiseno() {

  final lista = <VariableMonitoreo>[];

  int contadorDI = 0;
  int contadorDO = 0;

  for (final comp
  in _DesignScreenState._componentesPersistentes) {

    final pines = <PinModel>[
      ...comp.inputs,
      ...comp.outputs,
    ];

    for (final pin in pines) {

      if (comp.asignaciones[pin.id] != null) continue;

      if (comp.component.category != 'Otros') continue;

      String tag;

      if (pin.type == PinType.digitalOutput) {
        contadorDI++;
        tag = 'V DI $contadorDI';
      } else if (pin.type == PinType.digitalInput) {
        contadorDO++;
        tag = 'V DO $contadorDO';
      } else {
        continue;
      }

      lista.add(
        VariableMonitoreo(
          componente: comp,
          pin: pin,
          tagVirtual: tag,
          asignacion: null,
        ),
      );
    }
  }

  return lista;
}

class _ProgrammingScreenState
    extends State<ProgrammingScreen> {
  // Instancia activa de la pantalla. El NodeFlowEditor usa un controlador
  // estático que puede conservar los eventos de una instancia vieja ya
  // destruida; por eso los eventos llaman siempre a la instancia activa.
  static _ProgrammingScreenState? _activo;

  // ==========================================================
  // BLOQUES ESPEJO DE DISEÑO Y CONEXIONES
  //
  // Cada cable hecho en Diseño y Conexiones aparece aquí como dos
  // bloques unidos (origen -> destino). Eliminar uno de esos bloques
  // o la unión también elimina el cable de Diseño y Conexiones.
  // ==========================================================
  ProgramBlockDefinition? _definicionEspejo(
      PlacedComponent comp,
      String pinId,
      bool esOrigen,
      ) {
    final fisico = comp.asignaciones[pinId] != null;
    String id;
    if (fisico) {
      id = esOrigen ? 'IN_DI' : 'OUT_DO';
    } else if (comp.component.category == 'Otros') {
      id = esOrigen ? 'V_DI' : 'V_DO';
    } else {
      return null;
    }
    for (final d in _bloquesLogicos) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _quitarBloqueYCables(String bloqueId) {
    final cables = _flowController.connections
        .where((c) =>
    c.sourceNodeId == bloqueId || c.targetNodeId == bloqueId)
        .map((c) => c.id)
        .toList();
    for (final id in cables) {
      _flowController.removeConnection(id);
    }
    _flowController.removeNode(bloqueId);
    _bloquesColocados.removeWhere((b) => b.id == bloqueId);
  }

  // Crea o actualiza el bloque que representa a un componente.
  String _asegurarBloqueEspejo({
    required String conexionId,
    required String rol,
    required ProgramBlockDefinition definicion,
    required PlacedComponent comp,
    required String pinId,
    required Offset posicion,
  }) {
    final idBloque = 'espejo_${rol}_$conexionId';
    ProgramBlockInstance? actual;
    for (final b in _bloquesColocados) {
      if (b.id == idBloque) actual = b;
    }

    // Si cambió de físico a virtual (o al revés), se vuelve a crear.
    if (actual != null && actual.definition.id != definicion.id) {
      _quitarBloqueYCables(idBloque);
      actual = null;
    }

    final asignacion = comp.asignaciones[pinId];
    final etiqueta = '${comp.component.name} ${comp.instanceNumber}';

    if (actual == null) {
      final nuevo = ProgramBlockInstance(
        id: idBloque,
        definition: definicion,
        numero: 1,
        modulo: asignacion?.modulo,
        puerto: asignacion?.puerto,
        varClave: asignacion == null
            ? '${comp.instanceId}|$pinId'
            : null,
        espejoDe: conexionId,
        etiqueta: etiqueta,
      );
      _bloquesColocados.add(nuevo);
      _flowController.addNode(_crearNode(nuevo, posicion));
    } else {
      actual.modulo = asignacion?.modulo;
      actual.puerto = asignacion?.puerto;
      actual.varClave =
      asignacion == null ? '${comp.instanceId}|$pinId' : null;
      actual.etiqueta = etiqueta;
      _flowController.notifyNodeDataChanged(idBloque);
    }
    return idBloque;
  }

  void _sincronizarEspejos() {
    final componentes = <String, PlacedComponent>{
      for (final c in _DesignScreenState._componentesPersistentes)
        c.instanceId: c,
    };
    final cablesDiseno =
    _DesignScreenState._flowController.connections.toList();

    final vigentes = <String>{};
    int fila = _bloquesColocados.where((b) => b.espejoDe != null).length ~/ 2;

    for (final c in cablesDiseno) {
      final origen = componentes[c.sourceNodeId];
      final destino = componentes[c.targetNodeId];
      if (origen == null || destino == null) continue;

      final defO = _definicionEspejo(origen, c.sourcePortId, true);
      final defD = _definicionEspejo(destino, c.targetPortId, false);
      if (defO == null || defD == null) continue;

      vigentes.add(c.id);

      final y = 80.0 + fila * 220.0;
      final idO = _asegurarBloqueEspejo(
        conexionId: c.id,
        rol: 'o',
        definicion: defO,
        comp: origen,
        pinId: c.sourcePortId,
        posicion: Offset(80, y),
      );
      final idD = _asegurarBloqueEspejo(
        conexionId: c.id,
        rol: 'd',
        definicion: defD,
        comp: destino,
        pinId: c.targetPortId,
        posicion: Offset(460, y),
      );
      fila++;

      final idUnion = 'espejo_${c.id}';
      final existe =
      _flowController.connections.any((x) => x.id == idUnion);
      if (!existe) {
        _flowController.addConnection(
          Connection(
            id: idUnion,
            sourceNodeId: idO,
            sourcePortId: 'out_1',
            targetNodeId: idD,
            targetPortId: 'in_1',
          ),
        );
      }
    }

    // Bloques cuyo cable ya no existe en Diseño y Conexiones.
    final huerfanos = _bloquesColocados
        .where((b) => b.espejoDe != null && !vigentes.contains(b.espejoDe))
        .map((b) => b.id)
        .toList();
    for (final id in huerfanos) {
      _quitarBloqueYCables(id);
    }
  }

  Future<bool> _confirmarEliminarEspejo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Advertencia'),
          content: const Text(
            'Esta conexión viene de Diseño y Conexiones. Eliminar la '
                'conexión o alguno de los bloques provocará que la '
                'conexión hecha en Diseño y Conexiones también se '
                'elimine.\n\n¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  // Elimina el cable de Diseño y Conexiones y sus bloques espejo.
  void _eliminarConexionDeDiseno(String conexionDisenoId) {
    _DesignScreenState._flowController
        .removeConnection(conexionDisenoId);
    _sincronizarEspejos();
    if (mounted) {
      setState(() {});
    }
    _mensaje('Conexión eliminada también en Diseño y Conexiones.');
  }

  @override
  void initState() {
    super.initState();
    _activo = this;
    AppNav.herramientasVivas++;

    // Fuerza un segundo build justo después del primero para que el
    // editor tome los eventos de ESTA instancia (así se puede configurar
    // un V DI sin abrir y cerrar la pestaña de selección de bloques).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Muestra como bloques unidos los cables de Diseño y Conexiones.
        _sincronizarEspejos();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    AppNav.herramientasVivas--;
    if (_activo == this) {
      _activo = null;
    }
    super.dispose();
  }

  void _alCrearConexion() {
    if (mounted) {
      setState(() {});
    }
  }

  // Con el botón Cable activo, tocar un cable ofrece eliminarlo.
  void _tocarCable(Connection conexion) {
    if (_modoCable) {
      _confirmarEliminarCable(conexion);
    }
  }

  void _tocarCanvas() {
    // Modo mover: mover el bloque elegido al lugar tocado.
    if (_modoMover && _nodoAMoverId != null) {
      _moverNodoA(
        _nodoAMoverId!,
        _ultimoToqueGlobal,
      );

      setState(() {
        _nodoAMoverId = null;
      });

      _mensaje('Bloque movido.');
    }
  }

  // ==========================================================
  // MOTOR NODE FLOW (mismo que Diseño y Conexiones)
  //
  // Es estático para que los bloques y sus cables se conserven
  // al salir y volver a esta pantalla.
  // ==========================================================

  // Tamaño (en unidades del gráfico) de cada bloque.
  // La altura adicional evita el desbordamiento de TON/TOF, que
  // muestran tanto el contador como el tiempo configurado.
  static const double _nodoAncho = 220;
  static const double _nodoAlto = 170;

  // Diámetro de los puertos.
  static const double _puertoTam = 40;

  static const TextStyle _estiloEtiquetaPuerto = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // Tamaño de la ficha que se ve al arrastrar desde el panel.
  static const double _fichaAlto = 56;
  static const double _feedbackAncho = 170;

  static final NodeFlowController<ProgramBlockInstance, dynamic>
  _flowController =
  NodeFlowController<ProgramBlockInstance, dynamic>(
    config: NodeFlowConfig(
      minZoom: 0.2,
      maxZoom: 2.0,
    ),
    initialViewport: GraphViewport(x: 0, y: 0, zoom: 0.6),
  );

  static final List<ProgramBlockInstance> _bloquesColocados =
  [];


  // ==========================================================
  // ESTADOS VISUALES
  // ==========================================================

  bool mostrarProgramacion = false;

  String categoriaSeleccionada = 'Lógicos';

  final GlobalKey _workspaceKey =
  GlobalKey();


  // ==========================================================
  // MODO CABLE / MODO MOVER
  // ==========================================================

  bool _modoCable = false;

  bool _modoMover = false;

  // Modo eliminar: toque un bloque para eliminarlo.
  bool _modoEliminar = false;

  // Bloque que se va a mover (ya tocado, falta tocar el destino).
  String? _nodoAMoverId;

  // Origen del cable (bloque + puerto de salida ya elegidos).
  String? _cableOrigenNodoId;
  _PuertoBloque? _cableOrigenPuerto;

  // Última posición tocada en pantalla (coordenadas globales).
  Offset _ultimoToqueGlobal = Offset.zero;

  // ==========================================================
  // DEFINICIÓN DE BLOQUES
  //
  // LÓGICOS:
  // AND, OR, XOR, NAND y NOR = 2 DI / 1 DO
  // NOT = 1 DI / 1 DO
  //
  // TEMPORALES:
  // TON y TOF = 1 DI / 1 DO
  //
  // COMPARACIÓN:
  // >= y < = 1 AI / 1 DO
  //
  // La lógica de funcionamiento se implementa en EjecutorGlobal.
  // ==========================================================

  static const List<ProgramBlockDefinition>
  _bloquesLogicos = [

    // ------------------------------------------------------
    // ENTRADAS / SALIDAS (puertos físicos de módulos)
    //
    // DI: lee una entrada digital de un módulo DI → salida digital
    // DO: escribe una salida digital de un módulo DO ← entrada digital
    // AI: lee una entrada analógica de un módulo AI → salida analógica
    //
    // Se asignan a módulo + puerto tocándolos. Todavía no
    // ejecutan lógica.
    // ------------------------------------------------------

    ProgramBlockDefinition(
      id: 'IN_DI',
      nombre: 'DI',
      categoria: 'Lógicos',
      entradas: 0,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'OUT_DO',
      nombre: 'DO',
      categoria: 'Lógicos',
      entradas: 1,
      salidas: 0,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'IN_AI',
      nombre: 'AI',
      categoria: 'Lógicos',
      entradas: 0,
      salidas: 1,
      tipoEntrada: ProgramPinType.analogInput,
      tipoSalida: ProgramPinType.analogOutput,
    ),

    // ------------------------------------------------------
    // VIRTUALES (Switch / Botón / LED de Diseño y Conexiones)
    //
    // V DI: señal de un Switch o Botón virtual → salida digital
    // V DO: entrada digital → enciende un LED virtual
    // ------------------------------------------------------
    ProgramBlockDefinition(
      id: 'V_DI',
      nombre: 'V DI',
      categoria: 'Lógicos',
      entradas: 0,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),
    ProgramBlockDefinition(
      id: 'V_DO',
      nombre: 'V DO',
      categoria: 'Lógicos',
      entradas: 1,
      salidas: 0,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),
    ProgramBlockDefinition(
      id: 'AND',
      nombre: 'AND',
      categoria: 'Lógicos',
      entradas: 2,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'OR',
      nombre: 'OR',
      categoria: 'Lógicos',
      entradas: 2,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'NOT',
      nombre: 'NOT',
      categoria: 'Lógicos',
      entradas: 1,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'XOR',
      nombre: 'XOR',
      categoria: 'Lógicos',
      entradas: 2,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'NAND',
      nombre: 'NAND',
      categoria: 'Lógicos',
      entradas: 2,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'NOR',
      nombre: 'NOR',
      categoria: 'Lógicos',
      entradas: 2,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),
  ];


  static const List<ProgramBlockDefinition>
  _bloquesTemporales = [

    ProgramBlockDefinition(
      id: 'TON',
      nombre: 'TON',
      categoria: 'Temporales',
      entradas: 1,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'TOF',
      nombre: 'TOF',
      categoria: 'Temporales',
      entradas: 1,
      salidas: 1,
      tipoEntrada: ProgramPinType.digitalInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),
  ];


  static const List<ProgramBlockDefinition>
  _bloquesComparacion = [

    ProgramBlockDefinition(
      id: 'MAYOR_IGUAL',
      nombre: '>=',
      categoria: 'Comparación',
      entradas: 1,
      salidas: 1,
      tipoEntrada: ProgramPinType.analogInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),

    ProgramBlockDefinition(
      id: 'MENOR',
      nombre: '<',
      categoria: 'Comparación',
      entradas: 1,
      salidas: 1,
      tipoEntrada: ProgramPinType.analogInput,
      tipoSalida: ProgramPinType.digitalOutput,
    ),
  ];


  // Tipo de módulo físico que corresponde a un bloque de E/S.
  String _tipoModuloDe(ProgramBlockDefinition d) {

    switch (d.id) {

      case 'IN_DI':
        return 'DI';

      case 'OUT_DO':
        return 'DO';

      case 'IN_AI':
      default:
        return 'AI';
    }
  }


  String _descripcionES(ProgramBlockDefinition d) {

    switch (d.id) {

      case 'IN_DI':
        return 'Entrada digital';

      case 'OUT_DO':
        return 'Salida digital';
      case 'V_DI':
        return 'Switch / Botón virtual';
      case 'V_DO':
        return 'LED virtual';
      case 'IN_AI':
      default:
        return 'Entrada analógica';
    }
  }


  List<ProgramBlockDefinition>
  obtenerBloquesCategoria() {

    switch (categoriaSeleccionada) {

      case 'Temporales':
        return _bloquesTemporales;

      case 'Comparación':
        return _bloquesComparacion;

      case 'Lógicos':
      default:
        return _bloquesLogicos;
    }
  }

  // ==========================================================
  // ESCALA RESPONSIVA
  //
  // Se conserva la referencia horizontal utilizada en Diseño
  // y Conexiones: 2524 px.
  // ==========================================================

  double escala(BuildContext context) {

    final ancho =
        MediaQuery.of(context).size.width;

    return (ancho / 2524.0)
        .clamp(0.55, 1.0);
  }


  double w(
      BuildContext context,
      double valor,
      ) {

    return valor * escala(context);
  }



  // ==========================================================
  // PUERTOS DE CADA BLOQUE
  //
  // Entradas: in_1, in_2...   Salida: out_1
  // ==========================================================

  List<_PuertoBloque> _entradasDe(
      ProgramBlockDefinition definicion,
      ) {

    return [
      for (int i = 1; i <= definicion.entradas; i++)
        _PuertoBloque(
          id: 'in_$i',
          label: '${_textoTipoPuerto(definicion.tipoEntrada)} $i',
          tipo: definicion.tipoEntrada,
        ),
    ];
  }


  List<_PuertoBloque> _salidasDe(
      ProgramBlockDefinition definicion,
      ) {

    return [
      for (int i = 1; i <= definicion.salidas; i++)
        _PuertoBloque(
          id: 'out_$i',
          label: '${_textoTipoPuerto(definicion.tipoSalida)} $i',
          tipo: definicion.tipoSalida,
        ),
    ];
  }


  _PuertoBloque? _buscarPuerto(
      ProgramBlockInstance bloque,
      String puertoId,
      ) {

    for (final p in _entradasDe(bloque.definition)) {
      if (p.id == puertoId) {
        return p;
      }
    }

    for (final p in _salidasDe(bloque.definition)) {
      if (p.id == puertoId) {
        return p;
      }
    }

    return null;
  }


  // Una salida solo puede conectarse a una entrada del mismo tipo
  // de señal: DO → DI  o  AO → AI.
  bool _tiposCompatibles(
      ProgramPinType origen,
      ProgramPinType destino,
      ) {

    return (origen == ProgramPinType.digitalOutput &&
        destino == ProgramPinType.digitalInput) ||
        (origen == ProgramPinType.analogOutput &&
            destino == ProgramPinType.analogInput);
  }


  MaterialColor _colorPuerto(ProgramPinType tipo) {

    switch (tipo) {

      case ProgramPinType.digitalInput:
        return Colors.blue;

      case ProgramPinType.digitalOutput:
        return Colors.red;

      case ProgramPinType.analogInput:
        return Colors.green;

      case ProgramPinType.analogOutput:
        return Colors.purple;
    }
  }


  // ==========================================================
  // CREAR PUERTO NODE FLOW
  // ==========================================================

  Port _crearPuertoNodeFlow({
    required _PuertoBloque puerto,
    required bool esSalida,
    required int indice,
    required int cantidad,
  }) {

    final MaterialColor color =
    _colorPuerto(puerto.tipo);

    double separacion = 0;

    if (cantidad > 1) {
      final maxima =
          (_nodoAlto - _puertoTam - 24) / (cantidad - 1);
      separacion = maxima < 60 ? maxima : 60;
    }

    // Igual que en Diseño y Conexiones: para puertos a la
    // izquierda/derecha, dx = 0 y dy = posición vertical.
    final offset = Offset(
      0,
      _nodoAlto / 2 +
          (indice - (cantidad - 1) / 2) * separacion,
    );

    return Port(
      id: puerto.id,
      name: puerto.label,

      type: esSalida
          ? PortType.output
          : PortType.input,

      position: esSalida
          ? PortPosition.right
          : PortPosition.left,

      offset: offset,

      // Una salida puede alimentar varias entradas.
      // Cada entrada admite una sola conexión.
      multiConnections: esSalida,

      size: const Size(_puertoTam, _puertoTam),

      showLabel: true,

      shape: MarkerShapes.circle,

      theme: PortTheme.light.copyWith(
        size: const Size(_puertoTam, _puertoTam),
        color: color.shade100,
        connectedColor: color.shade300,
        highlightColor: Colors.orange,
        highlightBorderColor: Colors.black,
        borderColor: color,
        borderWidth: 3,
        labelTextStyle: _estiloEtiquetaPuerto,
        labelOffset: 4,
      ),
    );
  }


  List<Port> _crearPuertosNodeFlow(
      ProgramBlockInstance bloque,
      ) {

    final entradas =
    _entradasDe(bloque.definition);

    final salidas =
    _salidasDe(bloque.definition);

    return [

      for (int i = 0; i < entradas.length; i++)
        _crearPuertoNodeFlow(
          puerto: entradas[i],
          esSalida: false,
          indice: i,
          cantidad: entradas.length,
        ),

      for (int i = 0; i < salidas.length; i++)
        _crearPuertoNodeFlow(
          puerto: salidas[i],
          esSalida: true,
          indice: i,
          cantidad: salidas.length,
        ),
    ];
  }


  Node<ProgramBlockInstance> _crearNode(
      ProgramBlockInstance bloque,
      Offset posicion,
      ) {

    return Node<ProgramBlockInstance>(
      id: bloque.id,
      type: bloque.definition.id,
      position: posicion,
      size: const Size(_nodoAncho, _nodoAlto),
      data: bloque,
      ports: _crearPuertosNodeFlow(bloque),
    );
  }


  // ==========================================================
  // MENSAJES
  // ==========================================================

  void _mensaje(String texto) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(texto),
        ),
      );
  }


  String get _textoModoActivo {

    if (_modoMover) {
      return _nodoAMoverId == null
          ? 'MOVER: toque el bloque que quiere mover'
          : 'MOVER: ahora toque el lugar vacío de destino';
    }

    if (_modoEliminar) {
      return 'ELIMINAR: toque el bloque que quiere eliminar';
    }

    if (_modoCable) {
      return _cableOrigenPuerto == null
          ? 'CABLE: toque el ORIGEN (salida) o un cable para eliminarlo'
          : 'CABLE: toque el bloque de DESTINO (entrada)';
    }

    return '';
  }


  // ==========================================================
  // ALTERNAR MODOS
  // ==========================================================

  void _alternarModoMover() {

    setState(() {

      _modoMover = !_modoMover;
      _nodoAMoverId = null;

      if (_modoMover) {
        _modoCable = false;
        _modoEliminar = false;
        _cableOrigenNodoId = null;
        _cableOrigenPuerto = null;
      }
    });

    _mensaje(_modoMover
        ? 'Mover activado: toque un bloque y luego el lugar de destino.'
        : 'Mover desactivado.');
  }


  void _alternarModoCable() {

    setState(() {

      _modoCable = !_modoCable;
      _cableOrigenNodoId = null;
      _cableOrigenPuerto = null;

      if (_modoCable) {
        _modoMover = false;
        _modoEliminar = false;
        _nodoAMoverId = null;
      }
    });

    _mensaje(_modoCable
        ? 'Cable activado: toque el bloque de origen, elija el puerto '
        'y luego toque el bloque de destino. También puede arrastrar '
        'desde un puerto de salida hasta una entrada. '
        'Toque un cable para eliminarlo.'
        : 'Cable desactivado.');
  }


  void _alternarModoEliminar() {

    setState(() {

      _modoEliminar = !_modoEliminar;

      if (_modoEliminar) {
        _modoCable = false;
        _modoMover = false;
        _nodoAMoverId = null;
        _cableOrigenNodoId = null;
        _cableOrigenPuerto = null;
      }
    });

    _mensaje(_modoEliminar
        ? 'Eliminar activado: toque un bloque para eliminarlo.'
        : 'Eliminar desactivado.');
  }


  // ==========================================================
  // ELIMINAR UN BLOQUE (y los cables conectados a él)
  // ==========================================================

  Future<void> _eliminarBloque(
      Node<ProgramBlockInstance> node,
      ) async {

    final bloque = node.data;

    // Bloque que viene de Diseño y Conexiones: advertencia especial.
    if (bloque.espejoDe != null) {
      final aceptar = await _confirmarEliminarEspejo();
      if (!aceptar || !mounted) return;
      _eliminarConexionDeDiseno(bloque.espejoDe!);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {

        return AlertDialog(

          title: const Text('Eliminar bloque'),

          content: Text(
            '¿Desea eliminar ${bloque.nombreCompleto}? '
                'También se eliminarán sus conexiones.',
          ),

          actions: [

            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),

            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    // Primero los cables conectados a este bloque.
    final cables = _flowController.connections
        .where(
          (c) =>
      c.sourceNodeId == bloque.id ||
          c.targetNodeId == bloque.id,
    )
        .map((c) => c.id)
        .toList();

    for (final id in cables) {
      _flowController.removeConnection(id);
    }

    _flowController.removeNode(bloque.id);

    _bloquesColocados.removeWhere(
          (b) => b.id == bloque.id,
    );

    setState(() {});

    _mensaje('Bloque eliminado.');
  }


  // ==========================================================
  // ELIMINAR UN CABLE (con el botón Cable activado, toque el cable)
  // ==========================================================

  String _describirPuertoCable(
      String nodoId,
      String puertoId,
      ) {

    for (final b in _bloquesColocados) {

      if (b.id == nodoId) {

        final p = _buscarPuerto(b, puertoId);

        return '${b.nombreCompleto} (${p?.label ?? puertoId})';
      }
    }

    return puertoId;
  }


  Future<void> _confirmarEliminarCable(
      Connection conexion,
      ) async {
    // Unión que viene de Diseño y Conexiones: advertencia especial.
    if (conexion.id.startsWith('espejo_')) {
      final aceptar = await _confirmarEliminarEspejo();
      if (!aceptar || !mounted) return;
      _eliminarConexionDeDiseno(conexion.id.substring(7));
      return;
    }

    final origen = _describirPuertoCable(
      conexion.sourceNodeId,
      conexion.sourcePortId,
    );

    final destino = _describirPuertoCable(
      conexion.targetNodeId,
      conexion.targetPortId,
    );

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {

        return AlertDialog(

          title: const Text('Eliminar conexión'),

          content: Text(
            '¿Desea eliminar la conexión?\n\n$origen\n→ $destino',
          ),

          actions: [

            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),

            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    _flowController.removeConnection(conexion.id);

    setState(() {});

    _mensaje('Conexión eliminada.');
  }


  // Coloca el centro del bloque donde se tocó.
  void _moverNodoA(
      String nodeId,
      Offset posicionGlobal,
      ) {

    final destino = _flowController
        .globalToGraph(ScreenPosition(posicionGlobal))
        .offset;

    _flowController.setNodePosition(
      nodeId,
      Offset(
        destino.dx - _nodoAncho / 2,
        destino.dy - _nodoAlto / 2,
      ),
    );
  }


  // ==========================================================
  // AÑADIR BLOQUE AL ESPACIO DE TRABAJO
  // ==========================================================

  void agregarBloque(
      ProgramBlockDefinition definicion,
      Offset posicionNodo,
      ) {

    int numero = 1;

    for (final existente in _bloquesColocados) {

      if (existente.definition.id == definicion.id &&
          existente.numero >= numero) {

        numero = existente.numero + 1;
      }
    }

    final nuevo = ProgramBlockInstance(
      id:
      '${definicion.id}_${DateTime.now().microsecondsSinceEpoch}',
      definition: definicion,
      numero: numero,
    );

    _bloquesColocados.add(nuevo);

    _flowController.addNode(
      _crearNode(nuevo, posicionNodo),
    );

    setState(() {});
  }


  // Suelta desde el panel lateral (arrastrar y soltar).
  void colocarBloqueDesdeArrastre(
      ProgramBlockDefinition definicion,
      Offset posicionGlobal,
      ) {

    // details.offset es la esquina de la ficha que se arrastra;
    // se usa su centro para colocar el bloque bajo el dedo.
    final centro = posicionGlobal +
        const Offset(_feedbackAncho / 2, _fichaAlto / 2);

    final posicion = _flowController
        .globalToGraph(ScreenPosition(centro))
        .offset;

    agregarBloque(
      definicion,
      Offset(
        posicion.dx - _nodoAncho / 2,
        posicion.dy - _nodoAlto / 2,
      ),
    );
  }


  // Un toque en la ficha añade el bloque al centro visible.
  void agregarBloqueAlCentro(
      ProgramBlockDefinition definicion,
      ) {

    final renderBox =
    _workspaceKey.currentContext
        ?.findRenderObject();

    Offset posicion = const Offset(100, 100);

    if (renderBox is RenderBox) {

      final centroGlobal = renderBox.localToGlobal(
        renderBox.size.center(Offset.zero),
      );

      final centro = _flowController
          .globalToGraph(ScreenPosition(centroGlobal))
          .offset;

      // Pequeño desplazamiento para que los bloques añadidos
      // seguidos no queden exactamente uno sobre otro.
      final desfase =
          (_bloquesColocados.length % 5) * 30.0;

      posicion = Offset(
        centro.dx - _nodoAncho / 2 + desfase,
        centro.dy - _nodoAlto / 2 + desfase,
      );
    }

    agregarBloque(definicion, posicion);
  }


  // ==========================================================
  // VALIDAR CONEXIÓN ARRASTRANDO EL CABLE
  // ==========================================================

  ConnectionValidationResult _validarInicioConexion(
      ConnectionStartContext<ProgramBlockInstance> context,
      ) {

    if (!_modoCable) {

      return ConnectionValidationResult.deny(
        reason:
        'Active el botón Cable para realizar una conexión.',
        showMessage: true,
      );
    }

    if (!context.isOutputPort) {

      return ConnectionValidationResult.deny(
        reason:
        'Debe comenzar la conexión desde un puerto de salida.',
        showMessage: true,
      );
    }

    final puerto = _buscarPuerto(
      context.sourceNode.data,
      context.sourcePort.id,
    );

    if (puerto == null) {

      return ConnectionValidationResult.deny(
        reason: 'Puerto no válido.',
        showMessage: true,
      );
    }

    return ConnectionValidationResult.allow();
  }


  ConnectionValidationResult _validarConexion(
      ConnectionCompleteContext<ProgramBlockInstance> context,
      ) {

    if (context.isSelfConnection) {

      return ConnectionValidationResult.deny(
        reason:
        'No se puede conectar un bloque consigo mismo.',
        showMessage: true,
      );
    }

    if (!context.isOutputToInput) {

      return ConnectionValidationResult.deny(
        reason:
        'Solo se permite conectar una salida con una entrada.',
        showMessage: true,
      );
    }

    final pOrigen = _buscarPuerto(
      context.sourceNode.data,
      context.sourcePort.id,
    );

    final pDestino = _buscarPuerto(
      context.targetNode.data,
      context.targetPort.id,
    );

    if (pOrigen == null || pDestino == null) {

      return ConnectionValidationResult.deny(
        reason: 'Puerto no válido.',
        showMessage: true,
      );
    }

    if (!_tiposCompatibles(pOrigen.tipo, pDestino.tipo)) {

      return ConnectionValidationResult.deny(
        reason:
        'No se puede conectar ${_textoTipoPuerto(pOrigen.tipo)} '
            'con ${_textoTipoPuerto(pDestino.tipo)}.',
        showMessage: true,
      );
    }

    if (context.existingTargetConnections.isNotEmpty) {

      return ConnectionValidationResult.deny(
        reason: '${pDestino.label} ya tiene una conexión.',
        showMessage: true,
      );
    }

    // La misma conexión no puede existir en Diseño y Conexiones
    // (ni directa ni pasando por otros bloques).
    final conflicto = conflictoDisenoProgramacion(
      programaOrigen: context.sourceNode.data,
      programaDestino: context.targetNode.data,
    );
    if (conflicto != null) {
      return ConnectionValidationResult.deny(
        reason: conflicto,
        showMessage: true,
      );
    }

    return ConnectionValidationResult.allow();
  }


  // ==========================================================
  // CABLE POR TOQUES (alternativa al arrastre)
  // ==========================================================

  Future<_PuertoBloque?> _elegirPuerto(
      String titulo,
      List<_PuertoBloque> puertos,
      ) {

    return showDialog<_PuertoBloque>(
      context: context,
      builder: (dialogContext) {

        return SimpleDialog(
          title: Text(titulo),
          children: [

            for (final p in puertos)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(dialogContext, p),
                child: Text(
                  p.label,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
          ],
        );
      },
    );
  }


  String? _validarConexionManual(
      ProgramBlockInstance origen,
      _PuertoBloque pOrigen,
      ProgramBlockInstance destino,
      _PuertoBloque pDestino,
      ) {

    if (origen.id == destino.id) {
      return 'No se puede conectar un bloque consigo mismo.';
    }

    if (!_tiposCompatibles(pOrigen.tipo, pDestino.tipo)) {
      return 'No se puede conectar '
          '${_textoTipoPuerto(pOrigen.tipo)} con '
          '${_textoTipoPuerto(pDestino.tipo)}.';
    }

    for (final c in _flowController.connections) {

      if (c.targetNodeId == destino.id &&
          c.targetPortId == pDestino.id) {

        return '${pDestino.label} ya tiene una conexión.';
      }
    }

    final conflicto = conflictoDisenoProgramacion(
      programaOrigen: origen,
      programaDestino: destino,
    );
    if (conflicto != null) {
      return conflicto;
    }

    return null;
  }


  Future<void> _cableConToques(
      Node<ProgramBlockInstance> node,
      ) async {

    final bloque = node.data;

    final nombre = bloque.nombreCompleto;

    // ---------------- PASO 1: ORIGEN ----------------

    if (_cableOrigenPuerto == null) {

      final salidas = _salidasDe(bloque.definition);

      if (salidas.isEmpty) {
        _mensaje('$nombre no tiene salidas.');
        return;
      }

      final puerto = salidas.length == 1
          ? salidas.first
          : await _elegirPuerto(
        'Puerto de salida de $nombre',
        salidas,
      );

      if (puerto == null || !mounted) return;

      setState(() {
        _cableOrigenNodoId = node.id;
        _cableOrigenPuerto = puerto;
      });

      _mensaje(
        'Origen: $nombre (${puerto.label}). '
            'Ahora toque el bloque destino.',
      );

      return;
    }

    // ---------------- PASO 2: DESTINO ----------------

    if (node.id == _cableOrigenNodoId) {
      _mensaje('Elija un bloque distinto al de origen.');
      return;
    }

    final entradas = _entradasDe(bloque.definition);

    if (entradas.isEmpty) {
      _mensaje('$nombre no tiene entradas.');
      return;
    }

    final pDestino = entradas.length == 1
        ? entradas.first
        : await _elegirPuerto(
      'Puerto de entrada de $nombre',
      entradas,
    );

    if (pDestino == null || !mounted) return;

    ProgramBlockInstance? origen;

    for (final b in _bloquesColocados) {
      if (b.id == _cableOrigenNodoId) {
        origen = b;
      }
    }

    if (origen == null || _cableOrigenPuerto == null) {

      setState(() {
        _cableOrigenNodoId = null;
        _cableOrigenPuerto = null;
      });

      return;
    }

    final error = _validarConexionManual(
      origen,
      _cableOrigenPuerto!,
      bloque,
      pDestino,
    );

    if (error != null) {
      _mensaje(error);
      return;
    }

    _flowController.addConnection(
      Connection(
        id: 'cable_${DateTime.now().microsecondsSinceEpoch}',
        sourceNodeId: _cableOrigenNodoId!,
        sourcePortId: _cableOrigenPuerto!.id,
        targetNodeId: node.id,
        targetPortId: pDestino.id,
      ),
    );

    setState(() {
      _cableOrigenNodoId = null;
      _cableOrigenPuerto = null;
    });

    _mensaje('Conexión creada.');
  }


  Future<void> _manejarToqueNodo(
      Node<ProgramBlockInstance> node,
      ) async {

    if (_modoMover) {

      setState(() {
        _nodoAMoverId = node.id;
      });

      return;
    }

    if (_modoEliminar) {
      await _eliminarBloque(node);
      return;
    }

    if (_modoCable) {
      await _cableConToques(node);
      return;
    }

    // Sin ningún modo activo: los bloques de E/S abren la
    // asignación de módulo y puerto.
    if (node.data.espejoDe != null) {
      _mensaje(
        'Este bloque representa un componente de Diseño y Conexiones. '
            'Cambie su asignación allí.',
      );
      return;
    }

    if (node.data.definition.esES) {
      await _asignarPuerto(node);
    } else if (node.data.definition.esVirtual) {
      await _asignarVirtual(node);
    } else if (node.data.definition.categoria == 'Comparación') {
      await _configurarComparacion(node);
    } else if (node.data.definition.categoria == 'Temporales') {
      await _configurarTemporizador(node);
    }
  }


  // ==========================================================
  // CONFIGURACIÓN DE LOS BLOQUES DE COMPARACIÓN (>= y <)
  //
  // Se compara el valor FINAL de la entrada analógica (por ejemplo
  // bar si el bloque AI está asignado al sensor de presión), no el
  // voltaje que muestra la app.
  // ==========================================================

  // Unidad del valor que recibe el bloque ('' si todavía no hay un
  // bloque AI asignado conectado a su entrada).
  String _unidadDeComparacion(ProgramBlockInstance bloque) {

    final origen = _GrafoPrograma().origenDeEntrada(bloque, 'in_1');

    if (origen == null ||
        origen.definition.id != 'IN_AI' ||
        !origen.asignado) {
      return '';
    }

    return EjecutorGlobal.instance.unidadDePuerto(
      origen.modulo!,
      origen.puerto!,
    );
  }

  Future<void> _configurarComparacion(
      Node<ProgramBlockInstance> node,
      ) async {

    final bloque = node.data;

    final ejecutor = EjecutorGlobal.instance;

    final origen = _GrafoPrograma().origenDeEntrada(bloque, 'in_1');

    String unidad = '';
    String fuente = 'sin entrada. Conecte un bloque AI a este bloque.';
    String actual = '--';

    if (origen != null &&
        origen.definition.id == 'IN_AI' &&
        origen.asignado) {

      final m = origen.modulo!;
      final p = origen.puerto!;

      unidad = ejecutor.unidadDePuerto(m, p);

      final comp = ejecutor.componenteAnalogicoEnPuerto(m, p);

      fuente = '${origen.nombreCompleto} (Módulo $m, Puerto $p)';

      if (comp != null) {
        fuente += ' - ${comp.component.name} ${comp.instanceNumber}';
      }

      final lectura = ejecutor.valorFinalDePuerto(m, p);

      if (lectura != null) {
        actual = '${lectura.toStringAsFixed(2)} $unidad';
      }

    } else if (origen != null) {

      fuente = 'la entrada debe venir de un bloque AI asignado a un '
          'módulo.';
    }

    final esMayor = bloque.definition.id == 'MAYOR_IGUAL';

    final valor = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return _DialogoUmbral(
          titulo: 'Configurar ${bloque.nombreCompleto}',
          condicion: esMayor
              ? 'La salida se activa (ON) cuando el valor medido es '
              'mayor o igual al valor de comparación.'
              : 'La salida se activa (ON) cuando el valor medido es '
              'menor que el valor de comparación.',
          fuente: fuente,
          valorActual: actual,
          unidad: unidad,
          umbralActual: bloque.umbral,
        );
      },
    );

    if (valor == null || !mounted) {
      return;
    }

    bloque.umbral = valor;

    _flowController.notifyNodeDataChanged(node.id);

    setState(() {});

    _mensaje(
      '${bloque.nombreCompleto}: valor de comparación '
          '${_formatoNumero(valor)}${unidad.isEmpty ? '' : ' $unidad'}.',
    );
  }


  // ==========================================================
  // CONFIGURACIÓN DE LOS TEMPORIZADORES TON Y TOF
  //
  // El tiempo preestablecido se introduce en segundos y se valida
  // para que permanezca dentro del intervalo de 1 a 20 segundos.
  // ==========================================================
  Future<void> _configurarTemporizador(
      Node<ProgramBlockInstance> node,
      ) async {
    final bloque = node.data;
    final esTon = bloque.definition.id == 'TON';

    final valor = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return _DialogoTiempoTemporizador(
          titulo: 'Configurar ${bloque.nombreCompleto}',
          tipo: bloque.definition.nombre,
          tiempoActual: bloque.tiempoSegundos,
          condicion: esTon
              ? 'La salida se activa cuando la entrada permanece en ON '
              'durante el tiempo configurado.'
              : 'La salida se mantiene en ON durante el tiempo configurado '
              'después de que la entrada pasa a OFF.',
        );
      },
    );

    if (valor == null || !mounted) return;

    bloque.tiempoSegundos = valor;
    EjecutorGlobal.instance.reiniciarTemporizador(bloque.id);
    _flowController.notifyNodeDataChanged(node.id);
    setState(() {});

    _mensaje(
      '${bloque.nombreCompleto}: tiempo configurado en '
          '${_formatoNumero(valor)} s.',
    );
  }


  // ==========================================================
  // ASIGNACIÓN DE MÓDULO Y PUERTO (bloques DI / DO / AI)
  //
  // DI y DO pueden reutilizar un mismo puerto físico en varias
  // instancias del mismo bloque. AI conserva la asignación única.
  // ==========================================================

  // Devuelve el nombre del bloque que impide usar ese puerto, o null.
  // Las instancias DI pueden compartir una entrada DI y las instancias
  // DO pueden compartir una salida DO. Los demás tipos mantienen la
  // exclusividad para no cambiar su comportamiento.
  String? _ocupadoPor(
      ProgramBlockInstance bloque,
      int modulo,
      int puerto,
      ) {
    final permiteCompartir =
        bloque.definition.id == 'IN_DI' ||
            bloque.definition.id == 'OUT_DO';

    for (final otro in _bloquesColocados) {
      if (otro.id == bloque.id ||
          otro.espejoDe != null ||
          otro.modulo != modulo ||
          otro.puerto != puerto) {
        continue;
      }

      // Se permite compartir únicamente entre bloques del mismo tipo
      // de E/S digital: DI con DI u DO con DO.
      if (permiteCompartir &&
          otro.definition.id == bloque.definition.id) {
        continue;
      }

      return otro.nombreCompleto;
    }

    return null;
  }

  // Nombres de otras instancias DI/DO que ya utilizan el puerto.
  // Solo informa al usuario: no deshabilita la selección.
  List<String> _bloquesQueCompartenPuerto(
      ProgramBlockInstance bloque,
      int modulo,
      int puerto,
      ) {
    final esCompartible =
        bloque.definition.id == 'IN_DI' ||
            bloque.definition.id == 'OUT_DO';
    if (!esCompartible) return const <String>[];

    return _bloquesColocados
        .where((otro) =>
    otro.id != bloque.id &&
        otro.espejoDe == null &&
        otro.definition.id == bloque.definition.id &&
        otro.modulo == modulo &&
        otro.puerto == puerto)
        .map((otro) => otro.nombreCompleto)
        .toList();
  }


  // Componente de Diseño y Conexiones que tiene asignado ese mismo
  // puerto físico (solo informativo: un bloque DI/DO puede leer o
  // escribir el puerto al que está conectado un componente).
  String? _componenteEnPuerto(
      int modulo,
      int puerto,
      ) {

    for (final c in _DesignScreenState._componentesPersistentes) {

      for (final e in c.asignaciones.entries) {

        if (e.value.modulo == modulo &&
            e.value.puerto == puerto) {

          return '${c.component.name} ${c.instanceNumber} (${e.key})';
        }
      }
    }

    return null;
  }


  Future<void> _asignarPuerto(
      Node<ProgramBlockInstance> node,
      ) async {

    final bloque = node.data;

    final tipoNecesario =
    _tipoModuloDe(bloque.definition);

    final modulos =
        BluetoothManager.instance.modulos;

    // ---------------- PASO 1: ELEGIR MÓDULO ----------------

    final moduloElegido = await showDialog<ModuloPin>(
      context: context,
      builder: (dialogContext) {

        return SimpleDialog(

          title: Text(
            '${bloque.nombreCompleto}: elija un módulo',
          ),

          children: [

            for (final m in modulos)
              Builder(builder: (_) {

                final compatible =
                    m.conectado && m.tipo == tipoNecesario;

                String detalle;

                if (!m.conectado) {

                  detalle = 'No conectado';

                } else if (m.tipo != tipoNecesario) {

                  detalle = '${m.tipoTexto} (no compatible, se necesita '
                      '${tipoNecesario == 'DO' ? 'salida' : tipoNecesario == 'DI' ? 'entrada digital' : 'entrada analógica'})';

                } else {

                  detalle =
                  '${m.tipoTexto}, ${m.cantidadPines} puertos';
                }

                return SimpleDialogOption(

                  onPressed: compatible
                      ? () => Navigator.pop(dialogContext, m)
                      : null,

                  child: Opacity(

                    opacity: compatible ? 1.0 : 0.4,

                    child: Text(
                      'Módulo ${m.numero}: $detalle',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }),

            if (bloque.asignado)
              SimpleDialogOption(

                onPressed: () => Navigator.pop(
                  dialogContext,
                  ModuloPin(numero: -1),
                ),

                child: const Text(
                  'Quitar asignación actual',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (moduloElegido == null || !mounted) return;

    if (moduloElegido.numero == -1) {

      bloque.modulo = null;
      bloque.puerto = null;

      _flowController.notifyNodeDataChanged(node.id);

      setState(() {});

      _mensaje(
        'Asignación de ${bloque.nombreCompleto} eliminada.',
      );

      return;
    }

    // ---------------- PASO 2: ELEGIR PUERTO ----------------

    final puerto = await showDialog<int>(
      context: context,
      builder: (dialogContext) {

        return SimpleDialog(

          title: Text(
            'Módulo ${moduloElegido.numero}: elija un puerto',
          ),

          children: [

            for (int i = 1; i <= moduloElegido.cantidadPines; i++)
              Builder(builder: (_) {

                final ocupado = _ocupadoPor(
                  bloque,
                  moduloElegido.numero,
                  i,
                );

                final compartidos = _bloquesQueCompartenPuerto(
                  bloque,
                  moduloElegido.numero,
                  i,
                );

                final componente = _componenteEnPuerto(
                  moduloElegido.numero,
                  i,
                );

                String texto = 'Puerto $i';

                // Los puertos 2 y 3 de los módulos DO están
                // deshabilitados.
                final habilitado = moduloElegido.puertoHabilitado(i);

                final disponible = ocupado == null && habilitado;

                if (!habilitado) {
                  texto += ' (deshabilitado)';
                } else if (ocupado != null) {
                  texto += ' (ocupado por $ocupado)';
                } else {
                  if (compartidos.isNotEmpty) {
                    texto += ' (compartido con ${compartidos.join(', ')})';
                  }
                  if (componente != null) {
                    texto += ' (conectado a $componente)';
                  }
                }

                return SimpleDialogOption(

                  onPressed: disponible
                      ? () => Navigator.pop(dialogContext, i)
                      : null,

                  child: Opacity(

                    opacity: disponible ? 1.0 : 0.4,

                    child: Text(
                      texto,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );

    if (puerto == null || !mounted) return;

    final moduloPrevio = bloque.modulo;
    final puertoPrevio = bloque.puerto;

    bloque.modulo = moduloElegido.numero;
    bloque.puerto = puerto;

    // Una conexión no puede existir a la vez en Diseño y Conexiones y
    // en la programación por bloques.
    final conflicto = conflictoDisenoProgramacion();
    if (conflicto != null) {
      bloque.modulo = moduloPrevio;
      bloque.puerto = puertoPrevio;
      _mensaje(conflicto);
      return;
    }

    _flowController.notifyNodeDataChanged(node.id);

    setState(() {});

    _mensaje(
      '${bloque.nombreCompleto} asignado a Módulo '
          '${moduloElegido.numero}, Puerto $puerto.',
    );
  }

  // ==========================================================
  // ASIGNACIÓN DE VARIABLE VIRTUAL (bloques V DI / V DO)
  //
  // V DI: se asigna a un Switch/Botón colocado en Diseño y
  //       Conexiones (variable V DI n).
  // V DO: se asigna a un LED colocado en Diseño y Conexiones
  //       (variable V DO n).
  // ==========================================================

  // Texto de la variable asignada (null = sin asignar o ya no existe).
  String? _etiquetaVirtual(ProgramBlockInstance bloque) {
    if (bloque.varClave == null) return null;

    for (final v in variablesVirtualesDeDiseno()) {
      if (v.clave == bloque.varClave) {
        return v.tagVirtual;
      }
    }
    return null;
  }

  Future<void> _asignarVirtual(
      Node<ProgramBlockInstance> node,
      ) async {

    final bloque = node.data;
    final esDI = bloque.definition.id == 'V_DI';

    // Variables compatibles: V DI = pines de salida de Switch/Botón,
    // V DO = pines de entrada de LED.
    final candidatas = variablesVirtualesDeDiseno()
        .where((v) => esDI
        ? v.pin!.type == PinType.digitalOutput
        : v.pin!.type == PinType.digitalInput)
        .toList();

    if (candidatas.isEmpty) {
      _mensaje(
        esDI
            ? 'No hay Switch ni Botones en Diseño y Conexiones.'
            : 'No hay LED en Diseño y Conexiones.',
      );
      return;
    }

    // Variables ya usadas por otro bloque del mismo tipo.
    String? ocupadaPor(String clave) {
      for (final otro in _bloquesColocados) {
        if (otro.id != bloque.id &&
            otro.espejoDe == null &&
            otro.definition.id == bloque.definition.id &&
            otro.varClave == clave) {
          return otro.nombreCompleto;
        }
      }
      return null;
    }

    final elegida = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(
            '${bloque.nombreCompleto}: elija '
                '${esDI ? 'un Switch / Botón' : 'un LED'}',
          ),
          children: [
            for (final v in candidatas)
              Builder(builder: (_) {
                final ocupada = ocupadaPor(v.clave);
                final texto =
                    '${v.tagVirtual} · ${v.textoComponente}'
                    '${ocupada != null ? ' (ocupado por $ocupada)' : ''}';
                return SimpleDialogOption(
                  onPressed: ocupada == null
                      ? () => Navigator.pop(dialogContext, v.clave)
                      : null,
                  child: Opacity(
                    opacity: ocupada == null ? 1.0 : 0.4,
                    child: Text(
                      texto,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }),
            if (bloque.varClave != null)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, ''),
                child: const Text(
                  'Quitar asignación actual',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (elegida == null || !mounted) return;

    if (elegida.isEmpty) {
      bloque.varClave = null;
      _flowController.notifyNodeDataChanged(node.id);
      setState(() {});
      _mensaje(
        'Asignación de ${bloque.nombreCompleto} eliminada.',
      );
      return;
    }

    bloque.varClave = elegida;
    _flowController.notifyNodeDataChanged(node.id);
    setState(() {});

    _mensaje(
      '${bloque.nombreCompleto} asignado a '
          '${_etiquetaVirtual(bloque) ?? elegida}.',
    );
  }

  // ==========================================================
  // CABECERA PRINCIPAL
  // ==========================================================

  Widget construirCabecera(
      BuildContext context,
      ) {

    final size =
        MediaQuery.of(context).size;

    final alto =
    (size.height * 0.105)
        .clamp(65.0, 110.0);

    final iconSize =
    (alto * 0.48)
        .clamp(28.0, 52.0);

    final margen =
    (size.width * 0.015)
        .clamp(12.0, 30.0);

    return Container(

      height:
      alto,

      decoration:
      const BoxDecoration(

        border:
        Border(
          bottom:
          BorderSide(
            color:
            Colors.black,
            width:
            1.5,
          ),
        ),

      ),

      child:
      Row(

        children: [

          // ==================================================
          // VOLVER A INICIO
          // ==================================================

          SizedBox(

            width:
            (size.width * 0.055)
                .clamp(65.0, 120.0),

            child:
            IconButton(

              iconSize:
              iconSize,

              padding:
              EdgeInsets.only(
                left:
                margen,
              ),

              icon:
              const Icon(
                Icons.arrow_back,
                color:
                Colors.black,
              ),

              tooltip:
              'Volver a inicio',

              onPressed: () {
                AppNav.irAInicio(context);
              },

            ),

          ),

          // ==================================================
          // DISEÑO Y CONEXIONES
          // ==================================================

          Expanded(

            child:
            IconButton(

              iconSize:
              iconSize,

              icon:
              const Icon(
                Icons.touch_app_outlined,
                color:
                Colors.black,
              ),

              tooltip:
              'Diseño y conexiones',

              onPressed: () {
                AppNav.cambiarA(
                  context,
                  const DesignScreen(),
                );
              },

            ),

          ),

          // ==================================================
          // MONITOREO SÍNCRONO
          // ==================================================

          Expanded(

            child:
            IconButton(

              iconSize:
              iconSize,

              icon:
              const Icon(
                Icons.monitor_heart_outlined,
                color:
                Colors.black,
              ),

              tooltip:
              'Monitoreo síncrono',

              onPressed: () {
                AppNav.cambiarA(
                  context,
                  const MonitoreoScreen(),
                );
              },

            ),

          ),

          // ==================================================
          // TÍTULO
          // ==================================================

          Expanded(

            flex:
            4,

            child:
            Center(

              child:
              Text(

                'Programación por bloques',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(

                  fontSize:
                  (alto * 0.30)
                      .clamp(
                    18.0,
                    32.0,
                  ),

                  fontWeight:
                  FontWeight.w500,

                  color:
                  Colors.black,

                ),

              ),

            ),

          ),

          // ==================================================
          // DESHACER
          // ==================================================

          Expanded(

            child:
            IconButton(

              iconSize:
              iconSize,

              icon:
              const Icon(
                Icons.undo,
                color:
                Colors.black,
              ),

              tooltip:
              'Deshacer',

              onPressed: () {

                // La lógica de historial se implementará
                // posteriormente.

              },

            ),

          ),

          // ==================================================
          // REHACER
          // ==================================================

          Expanded(

            child:
            IconButton(

              iconSize:
              iconSize,

              icon:
              const Icon(
                Icons.redo,
                color:
                Colors.black,
              ),

              tooltip:
              'Rehacer',

              onPressed: () {

                // La lógica de historial se implementará
                // posteriormente.

              },

            ),

          ),

          // ==================================================
          // ABRIR/CERRAR PANEL DE BLOQUES
          // ==================================================

          SizedBox(

            width:
            (size.width * 0.055)
                .clamp(65.0, 120.0),

            child:
            IconButton(

              iconSize:
              iconSize,

              icon:
              const Icon(
                Icons.code,
                color:
                Colors.black,
              ),

              tooltip:
              'Abrir/cerrar selección de bloques',

              onPressed: () {

                setState(() {

                  mostrarProgramacion =
                  !mostrarProgramacion;

                });

              },

            ),

          ),

        ],

      ),

    );

  }


  // ==========================================================
  // PESTAÑAS DE CATEGORÍAS
  // ==========================================================

  Widget construirPestanasCategorias(
      BuildContext context,
      ) {

    return SizedBox(

      height:
      w(context, 60)
          .clamp(
        45.0,
        65.0,
      ),

      child:
      Row(

        children: [

          Expanded(
            child:
            construirPestanaCategoria(
              context,
              'Lógicos',
            ),
          ),

          Expanded(
            child:
            construirPestanaCategoria(
              context,
              'Temporales',
            ),
          ),

          Expanded(
            child:
            construirPestanaCategoria(
              context,
              'Comparación',
            ),
          ),

        ],

      ),

    );

  }


  // ==========================================================
  // PESTAÑA INDIVIDUAL
  // ==========================================================

  Widget construirPestanaCategoria(
      BuildContext context,
      String nombre,
      ) {

    final seleccionada =
        categoriaSeleccionada ==
            nombre;

    return GestureDetector(

      onTap: () {

        setState(() {

          categoriaSeleccionada =
              nombre;

        });

      },

      child:
      Container(

        alignment:
        Alignment.center,

        decoration:
        BoxDecoration(

          color:
          seleccionada
              ? Colors.black
              : Colors.white,

          border:
          const Border(

            right:
            BorderSide(
              color:
              Colors.black,
              width:
              1.0,
            ),

          ),

        ),

        // FittedBox: con 4 pestañas el texto se reduce si no cabe.
        child:
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(

              nombre,

              textAlign:
              TextAlign.center,

              style:
              TextStyle(

                fontSize:
                w(context, 18)
                    .clamp(
                  11.0,
                  19.0,
                ),

                color:
                seleccionada
                    ? Colors.white
                    : Colors.black,

                fontWeight:
                seleccionada
                    ? FontWeight.bold
                    : FontWeight.normal,

              ),

            ),
          ),
        ),

      ),

    );

  }


  // ==========================================================
  // FICHA COMPACTA DE LA PALETA
  //
  // Una fila por bloque (antes se dibujaba el bloque completo
  // dentro de una cuadrícula y se veía apretado).
  // ==========================================================

  Widget _construirFichaBloque(
      BuildContext context,
      ProgramBlockDefinition definicion,
      ) {

    return Container(

      height: _fichaAlto,

      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),

      decoration: BoxDecoration(

        color: Colors.white,

        border: Border.all(
          color: Colors.black,
          width: 1.2,
        ),

        borderRadius: BorderRadius.circular(8),
      ),

      child: Row(

        children: [

          Expanded(

            child: Text(

              definicion.nombre,

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

              style: TextStyle(
                fontSize:
                w(context, 22).clamp(15.0, 22.0),
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          Text(

            (definicion.esES || definicion.esVirtual)
                ? _descripcionES(definicion)
                : '${definicion.entradas} '
                '${_textoTipoPuerto(definicion.tipoEntrada)}'
                '  •  '
                '${definicion.salidas} '
                '${_textoTipoPuerto(definicion.tipoSalida)}',

            style: TextStyle(
              fontSize:
              w(context, 14).clamp(10.0, 14.0),
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }


  // ==========================================================
  // ELEMENTO DE LA PALETA
  //
  // Mantener presionado y arrastrar al espacio de trabajo.
  // Un toque también añade el bloque al centro visible.
  // ==========================================================

  Widget construirElementoPaleta(
      BuildContext context,
      ProgramBlockDefinition definicion,
      ) {

    final ficha =
    _construirFichaBloque(context, definicion);

    return Padding(

      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),

      child: LongPressDraggable<ProgramBlockDefinition>(

        data: definicion,

        feedback: Material(

          color: Colors.transparent,

          child: Opacity(

            opacity: 0.9,

            child: SizedBox(
              width: _feedbackAncho,
              height: _fichaAlto,
              child: _construirFichaBloque(
                context,
                definicion,
              ),
            ),
          ),
        ),

        childWhenDragging: Opacity(
          opacity: 0.35,
          child: ficha,
        ),

        child: GestureDetector(

          onTap: () {
            agregarBloqueAlCentro(definicion);
          },

          child: ficha,
        ),
      ),
    );
  }


  // ==========================================================
  // PANEL LATERAL DE SELECCIÓN DE BLOQUES
  // ==========================================================

  Widget construirPanelProgramacion(
      BuildContext context,
      ) {

    final bloques =
    obtenerBloquesCategoria();

    return Container(

      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Colors.black,
            width: 1.5,
          ),
        ),
      ),

      child: Column(

        children: [

          // ==================================================
          // CATEGORÍAS
          // ==================================================

          construirPestanasCategorias(
            context,
          ),

          // ==================================================
          // LISTA DE BLOQUES
          // ==================================================

          Expanded(

            child: Container(

              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.black,
                    width: 1.0,
                  ),
                ),
              ),

              child: Scrollbar(

                child: ListView.builder(

                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                  ),

                  itemCount: bloques.length,

                  itemBuilder: (context, index) {

                    return construirElementoPaleta(
                      context,
                      bloques[index],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ==========================================================
  // VISTA DEL BLOQUE DENTRO DEL NODE FLOW
  //
  // No calcula AND/OR/etc. Solo representa el bloque; los
  // puertos los dibuja el NodeFlow en los bordes.
  // ==========================================================

  Widget construirBloqueNodeFlow(
      BuildContext context,
      Node<ProgramBlockInstance> node,
      ) {
    final bloque = node.data;
    final esTemporizador =
        bloque.definition.id == 'TON' || bloque.definition.id == 'TOF';

    final tamanoTitulo = esTemporizador ? 23.0 : 28.0;
    final tamanoTexto = esTemporizador ? 13.0 : 16.0;
    final espacio = esTemporizador ? 3.0 : 6.0;

    return Container(
      width: _nodoAncho,
      height: _nodoAlto,
      // Margen lateral para no chocar con los puertos. En los
      // temporizadores se reduce el padding vertical para evitar overflow.
      padding: EdgeInsets.symmetric(
        horizontal: 30,
        vertical: esTemporizador ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: node.isSelected
              ? Colors.black
              : (bloque.espejoDe != null
              ? Colors.blue.shade700
              : Colors.grey.shade700),
          width: node.isSelected ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cuenta ascendente en segundos, situada encima del TON/TOF.
          if (esTemporizador) ...[
            Text(
              bloque.tiempoSegundos == null
                  ? 'Cuenta: ${EjecutorGlobal.instance.textoCuentaTemporizador(bloque.id)} s'
                  : 'Cuenta: ${EjecutorGlobal.instance.textoCuentaTemporizador(bloque.id)} / ${_formatoNumero(bloque.tiempoSegundos!)} s',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 2),
          ],

          Text(
            bloque.nombreCompleto,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: tamanoTitulo,
              height: 1.0,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          SizedBox(height: espacio),

          Text(
            (bloque.definition.esES || bloque.definition.esVirtual)
                ? _descripcionES(bloque.definition)
                : bloque.definition.categoria,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: tamanoTexto,
              height: 1.0,
              color: Colors.grey.shade700,
            ),
          ),

          // Tiempo configurado de los bloques TON/TOF.
          if (esTemporizador) ...[
            SizedBox(height: espacio),
            Text(
              bloque.tiempoSegundos == null
                  ? 'Toque para configurar (1–20 s)'
                  : 'Tiempo: ${_formatoNumero(bloque.tiempoSegundos!)} s',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.0,
                fontWeight: FontWeight.bold,
                color: bloque.tiempoSegundos == null
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
          ],

          // Asignación de módulo y puerto (bloques de E/S).
          if (bloque.definition.esES || bloque.definition.esVirtual) ...[
            const SizedBox(height: 6),
            Text(
              bloque.definition.esVirtual
                  ? (_etiquetaVirtual(bloque) ?? 'Sin asignar')
                  : (bloque.asignado
                  ? 'Módulo ${bloque.modulo} • Puerto ${bloque.puerto}'
                  : 'Sin asignar'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: (bloque.definition.esVirtual
                    ? _etiquetaVirtual(bloque) != null
                    : bloque.asignado)
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ],

          // Valor de comparación (bloques >= y <).
          if (bloque.definition.categoria == 'Comparación') ...[
            const SizedBox(height: 6),
            Text(
              bloque.umbral == null
                  ? 'Toque para configurar'
                  : '${bloque.definition.nombre} '
                  '${_formatoNumero(bloque.umbral!)} '
                  '${_unidadDeComparacion(bloque)}'.trim(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: bloque.umbral == null
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // ÁREA DE TRABAJO (NODE FLOW)
  // ==========================================================

  Widget construirEspacioTrabajo(
      BuildContext context,
      ) {

    final theme =
    NodeFlowTheme.light.copyWith(
      portTheme: PortTheme.light.copyWith(
        size: const Size(_puertoTam, _puertoTam),
        labelTextStyle: _estiloEtiquetaPuerto,
        labelOffset: 4,
      ),
    );

    final tamBoton =
    w(context, 90).clamp(65.0, 100.0);

    final margenBoton =
    w(context, 20).clamp(12.0, 25.0);

    return Stack(

      key: _workspaceKey,

      children: [

        // ======================================================
        // NODE FLOW
        // ======================================================

        DragTarget<ProgramBlockDefinition>(

          onWillAcceptWithDetails: (details) {
            return true;
          },

          onAcceptWithDetails: (details) {

            colocarBloqueDesdeArrastre(
              details.data,
              details.offset,
            );
          },

          builder: (
              context,
              candidateData,
              rejectedData,
              ) {

            return Stack(

              children: [

                Positioned.fill(

                  child: Listener(

                    behavior: HitTestBehavior.translucent,

                    onPointerDown: (evento) {
                      _ultimoToqueGlobal = evento.position;
                    },

                    child: NodeFlowEditor<
                        ProgramBlockInstance,
                        dynamic>(

                      controller: _flowController,

                      theme: theme,

                      behavior: NodeFlowBehavior.design,

                      nodeBuilder: construirBloqueNodeFlow,

                      events: NodeFlowEvents<
                          ProgramBlockInstance,
                          dynamic>(

                        // --------------------------------------
                        // BLOQUES
                        // --------------------------------------
                        node: NodeEvents<ProgramBlockInstance>(
                          onTap: (node) {
                            _ProgrammingScreenState._activo
                                ?._manejarToqueNodo(node);
                          },
                        ),

                        // --------------------------------------
                        // CONEXIONES
                        // --------------------------------------
                        connection: ConnectionEvents<
                            ProgramBlockInstance,
                            dynamic>(
                          onBeforeStart: (context) {
                            return _ProgrammingScreenState._activo
                                ?._validarInicioConexion(context) ??
                                ConnectionValidationResult.deny(
                                  reason: 'La pantalla no está lista.',
                                  showMessage: false,
                                );
                          },

                          onBeforeComplete: (context) {
                            return _ProgrammingScreenState._activo
                                ?._validarConexion(context) ??
                                ConnectionValidationResult.deny(
                                  reason: 'La pantalla no está lista.',
                                  showMessage: false,
                                );
                          },

                          onCreated: (connection) {
                            _ProgrammingScreenState._activo
                                ?._alCrearConexion();
                          },

                          // Con el botón Cable activo, tocar un
                          // cable ofrece eliminarlo.
                          onTap: (connection) {
                            _ProgrammingScreenState._activo
                                ?._tocarCable(connection);
                          },
                        ),

                        // --------------------------------------
                        // CANVAS
                        // --------------------------------------
                        viewport: ViewportEvents(
                          onCanvasTap: (position) {
                            _ProgrammingScreenState._activo
                                ?._tocarCanvas();
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // ==============================================
                // MENSAJE INICIAL
                // ==============================================

                if (_bloquesColocados.isEmpty)

                  Center(

                    child: IgnorePointer(

                      child: Text(

                        'Espacio de trabajo',

                        style: TextStyle(
                          fontSize: w(context, 28)
                              .clamp(18.0, 30.0),
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // ======================================================
        // AVISO DE MODO ACTIVO
        // ======================================================

        if (_modoMover || _modoCable || _modoEliminar)

          Positioned(

            top: 12,
            left: 0,
            right: 0,

            child: IgnorePointer(

              child: Center(

                child: Container(

                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),

                  child: Text(

                    _textoModoActivo,

                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // ======================================================
        // BOTÓN CABLE
        // ======================================================

        Positioned(

          left: margenBoton,
          bottom: margenBoton,

          child: _construirBotonModo(
            context: context,
            icono: Icons.cable,
            activo: _modoCable,
            tamano: tamBoton,
            onTap: _alternarModoCable,
          ),
        ),

        // ======================================================
        // BOTÓN MOVER
        // ======================================================

        Positioned(

          left: margenBoton + tamBoton + 12,
          bottom: margenBoton,

          child: _construirBotonModo(
            context: context,
            icono: Icons.open_with,
            activo: _modoMover,
            tamano: tamBoton,
            onTap: _alternarModoMover,
          ),
        ),

        // ======================================================
        // BOTÓN ELIMINAR BLOQUE
        // ======================================================

        Positioned(

          left: margenBoton + (tamBoton + 12) * 2,
          bottom: margenBoton,

          child: _construirBotonModo(
            context: context,
            icono: Icons.delete_outline,
            activo: _modoEliminar,
            tamano: tamBoton,
            onTap: _alternarModoEliminar,
          ),
        ),
      ],
    );
  }


  // Botón cuadrado de modo (cable / mover), igual al de Diseño
  // y Conexiones.
  Widget _construirBotonModo({
    required BuildContext context,
    required IconData icono,
    required bool activo,
    required double tamano,
    required VoidCallback onTap,
  }) {

    return Material(

      color: Colors.white,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(15),

        child: Container(

          width: tamano,
          height: tamano,

          decoration: BoxDecoration(

            border: Border.all(
              color: activo ? Colors.blue : Colors.black,
              width: activo ? 3 : 1.5,
            ),

            borderRadius: BorderRadius.circular(15),
          ),

          child: Icon(
            icono,
            size: w(context, 48).clamp(32.0, 55.0),
            color: activo ? Colors.blue : Colors.black,
          ),
        ),
      ),
    );
  }


  // ==========================================================
  // INTERFAZ PRINCIPAL
  // ==========================================================

  @override
  Widget build(
      BuildContext context,
      ) {

    return Scaffold(

      backgroundColor: Colors.white,

      body: SafeArea(

        child: Column(

          children: [

            // ==================================================
            // CABECERA
            // ==================================================

            construirCabecera(
              context,
            ),

            // ==================================================
            // CONTENIDO
            // ==================================================

            Expanded(

              child: Row(

                children: [

                  // ==========================================
                  // ESPACIO DE TRABAJO
                  // ==========================================

                  Expanded(

                    flex: mostrarProgramacion
                        ? 70
                        : 100,

                    child: construirEspacioTrabajo(
                      context,
                    ),
                  ),

                  // ==========================================
                  // PANEL LATERAL
                  // ==========================================

                  if (mostrarProgramacion)

                    Expanded(

                      flex: 30,

                      child: construirPanelProgramacion(
                        context,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// PANTALLA DE MONITOREO SÍNCRONO
// ============================================================

// Variable que se puede monitorear: un pin de un componente
// colocado en Diseño y Conexiones.
//
//  - Pin asignado a Módulo/Puerto  -> variable FÍSICA.
//  - Pin sin asignar de un componente de la categoría 'Otros'
//    (Switch, Botón, LED)           -> variable VIRTUAL:
//        V DI n = señal que genera un Switch/Botón (se puede accionar)
//        V DO n = entrada de un LED (solo se observa su estado)
class VariableMonitoreo {
  // Componente y pin de Diseño y Conexiones. Son null cuando la
  // variable es un puerto de un módulo que NO está conectado a
  // ningún componente.
  final PlacedComponent? componente;

  final PinModel? pin;

  // Solo para variables virtuales. Ejemplo: 'V DI 2'.
  final String tagVirtual;

  final AsignacionPin? asignacion;

  VariableMonitoreo({
    this.componente,
    this.pin,
    required this.tagVirtual,
    required this.asignacion,
  });

  // Puerto de un módulo sin componente conectado.
  bool get sinComponente => componente == null || pin == null;

  bool get esVirtual => !sinComponente && asignacion == null;

  // Switch / Botón virtual: se puede accionar desde esta pantalla.
  bool get esEntradaVirtual =>
      esVirtual && pin!.type == PinType.digitalOutput;

  bool get esAnalogica {
    if (sinComponente) {
      final a = asignacion;
      final modulos = BluetoothManager.instance.modulos;
      if (a == null || a.modulo < 1 || a.modulo > modulos.length) {
        return false;
      }
      return modulos[a.modulo - 1].tipo == 'AI';
    }
    return pin!.type == PinType.analogOutput ||
        pin!.type == PinType.analogInput;
  }

  // Clave única y estable de la variable.
  String get clave {
    if (sinComponente) {
      return 'MOD|${asignacion!.modulo}|${asignacion!.puerto}';
    }
    return '${componente!.instanceId}|${pin!.id}';
  }

  String get textoVariable {
    if (esVirtual) {
      return tagVirtual;
    }

    return 'Módulo ${asignacion!.modulo}\n'
        'Pin ${asignacion!.puerto}';
  }

  String get textoVariableLinea =>
      textoVariable.replaceAll('\n', ' · ');

  String get textoComponente {
    if (sinComponente) {
      return 'No conectado';
    }

    final base =
        '${componente!.component.name} '
        '${componente!.instanceNumber}';

    final cantidadPines =
        componente!.inputs.length +
            componente!.outputs.length;

    // Si el componente tiene varios pines, se indica cuál es.
    return cantidadPines > 1
        ? '$base (${pin!.label})'
        : base;
  }
}


class MonitoreoScreen extends StatefulWidget {

  const MonitoreoScreen({
    super.key,
  });

  @override
  State<MonitoreoScreen> createState() =>
      _MonitoreoScreenState();
}


class _MonitoreoScreenState
    extends State<MonitoreoScreen> {

  final BluetoothManager bluetooth =
      BluetoothManager.instance;

  // ==========================================================
  // ESTADO PERSISTENTE (se conserva al salir y volver)
  // ==========================================================

  // Claves de las variables que están en la lista de monitoreo.
  static final List<String> _clavesMonitoreadas = [];

  // El ejecutor global corre el programa y los cables de Diseño y
  // Conexiones aunque esta pantalla esté cerrada.
  final EjecutorGlobal ejecutor = EjecutorGlobal.instance;

  // Modo eliminar: toque una fila para quitarla de la lista.
  bool _modoEliminar = false;

  // ==========================================================
  // INICIO / CIERRE
  // ==========================================================

  @override
  void initState() {
    super.initState();

    // El ejecutor avisa de cada cambio de Bluetooth y del sistema.
    ejecutor.addListener(_actualizarPantalla);

    // Si ya existe conexión, se piden los módulos para tener su estado
    // actualizado (si el sistema está en marcha no se piden, para no
    // reiniciar los valores de las salidas que se están controlando).
    if (bluetooth.conectado && !ejecutor.corriendo) {
      bluetooth.solicitarModulos();
    }
  }

  void _actualizarPantalla() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ejecutor.removeListener(_actualizarPantalla);

    // NO desconectar Bluetooth ni detener el sistema.
    super.dispose();
  }

  void _mensaje(String texto) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(texto),
        ),
      );
  }


  // ==========================================================
  // VARIABLES DISPONIBLES
  //
  //  - Pines de componentes colocados en Diseño y Conexiones.
  //  - Puertos de los módulos conectados que NO están asignados a
  //    ningún componente (en "Componente conectado" aparecen como
  //    "No conectado").
  // ==========================================================

  List<VariableMonitoreo> _todasLasVariables() {
    final lista = <VariableMonitoreo>[];

    // Los tags virtuales se numeran según el orden en que
    // se colocaron los componentes, así no cambian al añadir
    // o quitar variables de la lista de monitoreo.
    int contadorDI = 0;
    int contadorDO = 0;

    for (final comp
    in _DesignScreenState._componentesPersistentes) {
      final pines = <PinModel>[
        ...comp.inputs,
        ...comp.outputs,
      ];

      for (final pin in pines) {
        final asignacion = comp.asignaciones[pin.id];

        // ---------------- VARIABLE FÍSICA ----------------
        if (asignacion != null) {
          lista.add(
            VariableMonitoreo(
              componente: comp,
              pin: pin,
              tagVirtual: '',
              asignacion: asignacion,
            ),
          );
          continue;
        }

        // ---------------- VARIABLE VIRTUAL ---------------
        if (comp.component.category != 'Otros') {
          continue;
        }

        String tag;
        if (pin.type == PinType.digitalOutput) {
          contadorDI++;
          tag = 'V DI $contadorDI';
        } else if (pin.type == PinType.digitalInput) {
          contadorDO++;
          tag = 'V DO $contadorDO';
        } else {
          continue;
        }

        lista.add(
          VariableMonitoreo(
            componente: comp,
            pin: pin,
            tagVirtual: tag,
            asignacion: null,
          ),
        );
      }
    }

    // ------- PUERTOS DE MÓDULOS SIN COMPONENTE CONECTADO -------
    final usados = <String>{
      for (final v in lista)
        if (v.asignacion != null)
          '${v.asignacion!.modulo}|${v.asignacion!.puerto}',
    };

    for (final modulo in bluetooth.modulos) {
      if (!modulo.conectado) {
        continue;
      }
      for (int puerto = 1; puerto <= modulo.cantidadPines; puerto++) {
        if (usados.contains('${modulo.numero}|$puerto')) {
          continue;
        }
        // Puertos deshabilitados (2 y 3 de los módulos DO).
        if (!modulo.puertoHabilitado(puerto)) {
          continue;
        }
        lista.add(
          VariableMonitoreo(
            tagVirtual: '',
            asignacion: AsignacionPin(
              modulo: modulo.numero,
              puerto: puerto,
            ),
          ),
        );
      }
    }

    return lista;
  }

  // Variables que están en la lista de monitoreo, en el orden
  // en que se añadieron.
  List<VariableMonitoreo> _filasMonitoreadas() {
    final todas = _todasLasVariables();
    final filas = <VariableMonitoreo>[];

    for (final clave in _clavesMonitoreadas) {
      VariableMonitoreo? encontrada;

      for (final v in todas) {
        if (v.clave == clave) {
          encontrada = v;
          break;
        }
      }

      // Puerto de un módulo que dejó de estar disponible (por ejemplo,
      // el módulo se desconectó): se sigue mostrando.
      if (encontrada == null && clave.startsWith('MOD|')) {
        final partes = clave.split('|');
        final modulo =
        int.tryParse(partes.length > 1 ? partes[1] : '');
        final puerto =
        int.tryParse(partes.length > 2 ? partes[2] : '');

        if (modulo != null && puerto != null) {
          // Si ahora un componente usa ese puerto, se muestra el componente.
          for (final v in todas) {
            if (v.asignacion != null &&
                v.asignacion!.modulo == modulo &&
                v.asignacion!.puerto == puerto) {
              encontrada = v;
              break;
            }
          }

          encontrada ??= VariableMonitoreo(
            tagVirtual: '',
            asignacion: AsignacionPin(
              modulo: modulo,
              puerto: puerto,
            ),
          );
        }
      }

      // Un puerto deshabilitado ya no se muestra.
      if (encontrada != null &&
          encontrada.asignacion != null &&
          !bluetooth.puertoHabilitado(
            encontrada.asignacion!.modulo,
            encontrada.asignacion!.puerto,
          )) {
        continue;
      }

      if (encontrada != null) {
        filas.add(encontrada);
      }
    }

    return filas;
  }

  // ==========================================================
  // LECTURA DE ESTADOS (los calcula el ejecutor global)
  // ==========================================================

  // Valor actual de un puerto de un módulo (null = sin datos).
  double? _valorFisico(AsignacionPin a) {
    return ejecutor.valorFisico(a);
  }

  // Estado de una entrada virtual (LED): sigue al programa por
  // bloques o al cable de Diseño y Conexiones mientras el sistema
  // está en marcha.
  bool _estadoSalidaVirtual(VariableMonitoreo v) {
    return ejecutor.estadoSalidaVirtual(v);
  }

  String _formatearNumero(double valor) {
    if (valor == valor.roundToDouble()) {
      return valor.toInt().toString();
    }

    return valor.toStringAsFixed(2);
  }

  // ==========================================================
  // ACCIONAR UN SWITCH / BOTÓN VIRTUAL
  // ==========================================================

  void _cambiarEntradaVirtual(
      VariableMonitoreo v,
      bool encendido,
      ) {
    // El ejecutor reenvía el estado a las salidas físicas cableadas y
    // recalcula el programa por bloques.
    ejecutor.cambiarEntradaVirtual(v.clave, encendido);

    if (!ejecutor.corriendo) {
      _mensaje(
        'El sistema está detenido. Pulse Comenzar en Diseño y '
            'conexiones para enviar las órdenes al ESP32.',
      );
    }
  }


  // ==========================================================
  // AÑADIR VARIABLES
  // ==========================================================

  Future<void> _anadirVariables() async {

    final todas = _todasLasVariables();

    final disponibles = todas
        .where(
          (v) => !_clavesMonitoreadas.contains(v.clave),
    )
        .toList();

    if (disponibles.isEmpty) {

      _mensaje(
        todas.isEmpty
            ? 'No hay variables. Conecte módulos por Bluetooth o coloque '
            'componentes en Diseño y conexiones.'
            : 'Todas las variables ya están en la lista.',
      );

      return;
    }

    final seleccion = <String>{};

    final confirmado = await showDialog<bool>(

      context: context,

      builder: (dialogContext) {

        return StatefulBuilder(

          builder: (context, setDialog) {

            return AlertDialog(

              title: const Text('Añadir variables'),

              content: SizedBox(

                width: 520,

                child: ListView(

                  shrinkWrap: true,

                  children: [

                    for (final v in disponibles)

                      CheckboxListTile(

                        value: seleccion.contains(v.clave),

                        controlAffinity:
                        ListTileControlAffinity.leading,

                        onChanged: (marcado) {

                          setDialog(() {

                            if (marcado == true) {

                              seleccion.add(v.clave);

                            } else {

                              seleccion.remove(v.clave);
                            }
                          });
                        },

                        title: Text(v.textoVariableLinea),

                        subtitle: Text(v.textoComponente),
                      ),
                  ],
                ),
              ),

              actions: [

                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),

                TextButton(
                  onPressed: seleccion.isEmpty
                      ? null
                      : () =>
                      Navigator.pop(dialogContext, true),
                  child: const Text('Añadir'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmado != true || !mounted) return;

    setState(() {

      for (final v in disponibles) {

        if (seleccion.contains(v.clave)) {

          _clavesMonitoreadas.add(v.clave);
        }
      }
    });
  }


  // ==========================================================
  // ELIMINAR VARIABLES
  // ==========================================================

  void _alternarModoEliminar() {

    setState(() {

      _modoEliminar = !_modoEliminar;
    });

    _mensaje(
      _modoEliminar
          ? 'Eliminar activado: toque una variable para quitarla '
          'de la lista.'
          : 'Eliminar desactivado.',
    );
  }

  void _quitarVariable(VariableMonitoreo v) {

    setState(() {

      _clavesMonitoreadas.remove(v.clave);
    });

    _mensaje('${v.textoVariableLinea} quitada de la lista.');
  }


  // ==========================================================
  // NAVEGACIÓN ENTRE PANTALLAS
  // ==========================================================

  // Se reemplaza lo que hay sobre el inicio para que "volver"
  // siempre regrese a la pantalla de inicio.

  void _irADiseno() {
    AppNav.cambiarA(context, const DesignScreen());
  }

  void _irAProgramacion() {
    AppNav.cambiarA(context, const ProgrammingScreen());
  }


  // ==========================================================
  // CABECERA
  // ==========================================================

  Widget _construirCabecera(BuildContext context) {

    final size = MediaQuery.of(context).size;

    final alto =
    (size.height * 0.105).clamp(65.0, 110.0).toDouble();

    final iconSize =
    (alto * 0.48).clamp(28.0, 52.0).toDouble();

    final margen =
    (size.width * 0.015).clamp(12.0, 30.0).toDouble();

    return Container(

      height: alto,

      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.black,
            width: 1.5,
          ),
        ),
      ),

      child: Row(

        children: [

          // ================================================
          // VOLVER A INICIO
          // ================================================

          SizedBox(

            width: (size.width * 0.055)
                .clamp(65.0, 120.0)
                .toDouble(),

            child: IconButton(

              iconSize: iconSize,

              padding: EdgeInsets.only(left: margen),

              icon: const Icon(
                Icons.arrow_back,
                color: Colors.black,
              ),

              tooltip: 'Volver a inicio',

              onPressed: () {
                AppNav.irAInicio(context);
              },
            ),
          ),

          // ================================================
          // DISEÑO Y CONEXIONES
          // ================================================

          IconButton(

            iconSize: iconSize,

            icon: const Icon(
              Icons.touch_app_outlined,
              color: Colors.black,
            ),

            tooltip: 'Diseño y conexiones',

            onPressed: _irADiseno,
          ),

          // ================================================
          // PROGRAMACIÓN POR BLOQUES
          // ================================================

          IconButton(

            iconSize: iconSize,

            icon: const Icon(
              Icons.code,
              color: Colors.black,
            ),

            tooltip: 'Programación por bloques',

            onPressed: _irAProgramacion,
          ),

          // ================================================
          // TÍTULO
          // ================================================

          Expanded(

            child: Center(

              child: Text(

                'Monitoreo Síncrono',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: (alto * 0.30)
                      .clamp(18.0, 32.0)
                      .toDouble(),
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // ================================================
          // ELIMINAR VARIABLES
          // ================================================

          IconButton(

            iconSize: iconSize,

            icon: Icon(
              Icons.delete_outline,
              color:
              _modoEliminar ? Colors.blue : Colors.black,
            ),

            tooltip: 'Eliminar variables',

            onPressed: _alternarModoEliminar,
          ),

          // ================================================
          // AÑADIR VARIABLES
          // ================================================

          Padding(

            padding: EdgeInsets.only(right: margen),

            child: IconButton(

              iconSize: iconSize,

              icon: const Icon(
                Icons.add_circle_outline,
                color: Colors.black,
              ),

              tooltip: 'Añadir variables',

              onPressed: _anadirVariables,
            ),
          ),
        ],
      ),
    );
  }


  // ==========================================================
  // TABLA
  // ==========================================================

  static const int _flexVariable = 20;
  static const int _flexComponente = 50;
  static const int _flexEstado = 30;

  static const BorderSide _lineaTabla = BorderSide(
    color: Colors.black,
    width: 1.5,
  );

  Widget _celdaEncabezado(
      String texto,
      int flex,
      double f, {
        bool lineaDerecha = true,
      }) {

    return Expanded(

      flex: flex,

      child: Container(

        alignment: Alignment.center,

        padding: EdgeInsets.symmetric(vertical: f * 0.8),

        decoration: BoxDecoration(
          border: Border(
            right:
            lineaDerecha ? _lineaTabla : BorderSide.none,
          ),
        ),

        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: f * 1.15,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // Selector ON / OFF de un Switch o Botón virtual.
  Widget _interruptor(
      VariableMonitoreo v,
      bool encendido,
      double f,
      ) {

    Widget lado(
        String texto,
        bool seleccionado,
        bool valorAlTocar,
        ) {

      return Expanded(

        child: InkWell(

          onTap: _modoEliminar
              ? null
              : () => _cambiarEntradaVirtual(
            v,
            valorAlTocar,
          ),

          child: Container(

            alignment: Alignment.center,

            color:
            seleccionado ? Colors.black : Colors.white,

            child: Text(
              texto,
              style: TextStyle(
                fontSize: f,
                color: seleccionado
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
        ),
      );
    }

    return Container(

      width: f * 9,
      height: f * 2.2,

      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.black,
          width: 1.5,
        ),
      ),

      child: Row(
        children: [
          lado('ON', encendido, true),
          lado('OFF', !encendido, false),
        ],
      ),
    );
  }

  // ==========================================================
  // CIRCULITO DEL LED
  // ==========================================================

  bool _esLed(VariableMonitoreo v) {
    return !v.sinComponente && v.componente!.component.id == 'led';
  }

  bool _ledEncendido(VariableMonitoreo v) {

    if (v.esVirtual) {
      return _estadoSalidaVirtual(v);
    }

    final valor = _valorFisico(v.asignacion!);

    return valor != null && valor >= 0.5;
  }

  Widget _circuloLed(VariableMonitoreo v, double f) {

    final encendido = _ledEncendido(v);

    final color = v.componente!.colorLed;

    final tamano = f * 1.5;

    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: encendido ? color : Colors.grey.shade300,
        border: Border.all(
          color: Colors.black,
          width: 1.5,
        ),
        boxShadow: encendido
            ? [
          BoxShadow(
            color: color.withValues(alpha: 0.8),
            blurRadius: tamano * 0.6,
            spreadRadius: tamano * 0.1,
          ),
        ]
            : null,
      ),
    );
  }

  Widget _contenidoEstado(
      VariableMonitoreo v,
      double f,
      ) {

    // ---------------- SWITCH / BOTÓN VIRTUAL ----------------
    if (v.esEntradaVirtual) {

      return _interruptor(
        v,
        ejecutor.entradasVirtuales[v.clave] ?? false,
        f,
      );
    }

    String texto;

    if (v.esVirtual) {

      // ---------------- LED VIRTUAL ----------------
      texto = _estadoSalidaVirtual(v) ? 'ON' : 'OFF';

    } else {

      // ---------------- VARIABLE FÍSICA ----------------
      final valor = _valorFisico(v.asignacion!);

      if (valor == null) {

        texto = '--';

      } else if (v.esAnalogica) {

        // Sensor de presión: se muestra la presión en bares.
        if (!v.sinComponente &&
            v.componente!.component.id == kIdSensorPresion) {

          texto = '${v.componente!.presionDe(valor).toStringAsFixed(2)} bar';

        } else {

          texto = _formatearNumero(valor);
        }

      } else {

        texto = valor >= 0.5 ? 'ON' : 'OFF';
      }
    }

    return Text(
      texto,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: f * 1.15,
        color: Colors.black,
      ),
    );
  }

  Widget _construirFila(
      VariableMonitoreo v,
      double f,
      ) {

    return InkWell(

      onTap: _modoEliminar
          ? () => _quitarVariable(v)
          : null,

      child: Container(

        constraints: BoxConstraints(
          minHeight: f * 3.8,
        ),

        color: _modoEliminar
            ? Colors.red.shade50
            : Colors.transparent,

        child: Row(

          crossAxisAlignment: CrossAxisAlignment.center,

          children: [

            // ---------------- VARIABLE ----------------
            Expanded(

              flex: _flexVariable,

              child: Padding(

                padding: EdgeInsets.symmetric(
                  vertical: f * 0.5,
                  horizontal: f * 0.3,
                ),

                child: Text(
                  v.textoVariable,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: f * 1.15,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            // ---------------- COMPONENTE ----------------
            Expanded(

              flex: _flexComponente,

              child: Padding(

                padding: EdgeInsets.symmetric(
                  vertical: f * 0.5,
                  horizontal: f * 1.5,
                ),

                child: Row(
                  children: [

                    // Circulito del LED: se enciende con su color.
                    if (_esLed(v)) ...[
                      _circuloLed(v, f),
                      SizedBox(width: f * 0.6),
                    ],

                    Flexible(
                      child: Text(
                        v.textoComponente,
                        style: TextStyle(
                          fontSize: f * 1.15,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---------------- ESTADO ----------------
            Expanded(

              flex: _flexEstado,

              child: Center(
                child: _contenidoEstado(v, f),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTabla(
      BuildContext context,
      double f,
      ) {

    final filas = _filasMonitoreadas();

    return Column(

      children: [

        // ====================================================
        // ENCABEZADO
        // ====================================================

        Container(

          decoration: const BoxDecoration(
            border: Border(bottom: _lineaTabla),
          ),

          child: IntrinsicHeight(

            child: Row(

              crossAxisAlignment:
              CrossAxisAlignment.stretch,

              children: [

                _celdaEncabezado(
                    'Variables', _flexVariable, f),

                _celdaEncabezado(
                    'Componente Conectado',
                    _flexComponente,
                    f),

                _celdaEncabezado(
                  'Estado',
                  _flexEstado,
                  f,
                  lineaDerecha: false,
                ),
              ],
            ),
          ),
        ),

        // ====================================================
        // FILAS
        // ====================================================

        Expanded(

          child: Stack(

            children: [

              // Líneas verticales continuas de la tabla.
              Positioned.fill(

                child: Row(

                  children: [

                    Expanded(
                      flex: _flexVariable,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(right: _lineaTabla),
                        ),
                      ),
                    ),

                    Expanded(
                      flex: _flexComponente,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(right: _lineaTabla),
                        ),
                      ),
                    ),

                    const Expanded(
                      flex: _flexEstado,
                      child: SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              // Lista de variables.
              ListView.builder(

                itemCount: filas.length,

                itemBuilder: (context, index) {

                  return _construirFila(filas[index], f);
                },
              ),

              // Mensaje cuando la lista está vacía (dentro de la columna
              // "Componente conectado"; desaparece al añadir la primera
              // variable).
              if (filas.isEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          flex: _flexVariable,
                          child: SizedBox.shrink(),
                        ),
                        Expanded(
                          flex: _flexComponente,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: f * 0.9,
                              horizontal: f * 1.5,
                            ),
                            child: Text(
                              'No hay variables en la lista. '
                                  'Toque + para añadir variables '
                                  'a monitorear.',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: f * 1.1,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: _flexEstado,
                          child: SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }


  // ==========================================================
  // INTERFAZ PRINCIPAL
  // ==========================================================

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;

    // Tamaño base del texto, proporcional a la pantalla.
    final f =
    (size.width * 0.0155).clamp(14.0, 26.0).toDouble();

    return Scaffold(

      backgroundColor: Colors.white,

      body: SafeArea(

        child: Column(

          children: [

            // ==============================================
            // CABECERA
            // ==============================================

            _construirCabecera(context),

            // ==============================================
            // TABLA DE VARIABLES
            // ==============================================

            Expanded(
              child: _construirTabla(context, f),
            ),

            // ==============================================
            // ESTADO DE LA CONEXIÓN
            // ==============================================

            Container(

              width: double.infinity,

              padding: EdgeInsets.symmetric(
                vertical: f * 0.9,
              ),

              decoration: const BoxDecoration(
                border: Border(top: _lineaTabla),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bluetooth.conectado
                        ? (ejecutor.corriendo
                        ? 'Estado: En línea · Sistema en marcha'
                        : 'Estado: En línea')
                        : 'Estado: Fuera de línea',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: f * 1.2,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: f * 0.6),
                  PuntoEstado(
                    conectado: bluetooth.conectado,
                    tamano: f * 1.0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// PANTALLAS SECUNDARIAS VACÍAS
// ============================================================

class EmptyScreen extends StatelessWidget {

  final String title;

  const EmptyScreen({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [

            // ==================================================
            // CABECERA
            // ==================================================

            AppHeader(
              title: title,
              onBack: () {
                Navigator.pop(context);
              },
            ),

            // ==================================================
            // CONTENIDO VACÍO
            // ==================================================


            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(35),
                  child: Column(
                    children: [
                      const Text(
                        '',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// AJUSTES DE LA APP (nombre de usuario y volumen)
//
// Se guardan en el dispositivo para que se conserven al cerrar
// y volver a abrir la app.
// ============================================================

class AjustesApp extends ChangeNotifier {

  AjustesApp._();

  static final AjustesApp instance = AjustesApp._();

  static const String _claveNombre = 'ajustes_nombre_usuario';
  static const String _claveVolumen = 'ajustes_volumen';

  static const String nombrePorDefecto = 'Usuario';

  static const int largoMaximoNombre = 20;

  String nombreUsuario = nombrePorDefecto;

  // Volumen del sonido de la app (Buzzer):
  // 0.0 = silencio, 1.0 = máximo.
  double volumen = 0.7;

  // Se llama una sola vez al iniciar la app.
  Future<void> cargar() async {

    try {

      final prefs = await SharedPreferences.getInstance();

      final nombre = prefs.getString(_claveNombre);

      if (nombre != null && nombre.trim().isNotEmpty) {
        nombreUsuario = nombre.trim();
      }

      final guardado = prefs.getDouble(_claveVolumen);

      if (guardado != null) {
        volumen = guardado.clamp(0.0, 1.0).toDouble();
      }

    } catch (e) {

      print('ERROR AL CARGAR AJUSTES: $e');
    }

    notifyListeners();
  }

  Future<void> cambiarNombre(String nuevo) async {

    var limpio = nuevo.trim();

    if (limpio.isEmpty) {
      return;
    }

    if (limpio.length > largoMaximoNombre) {
      limpio = limpio.substring(0, largoMaximoNombre);
    }

    nombreUsuario = limpio;

    notifyListeners();

    try {

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_claveNombre, limpio);

    } catch (e) {

      print('ERROR AL GUARDAR EL NOMBRE: $e');
    }
  }

  // Cambia el volumen mientras se arrastra la barra.
  void establecerVolumen(double valor) {

    final nuevo = valor.clamp(0.0, 1.0).toDouble();

    if (nuevo == volumen) {
      return;
    }

    volumen = nuevo;

    notifyListeners();
  }

  // Guarda el volumen (al soltar la barra).
  Future<void> guardarVolumen() async {

    try {

      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble(_claveVolumen, volumen);

    } catch (e) {

      print('ERROR AL GUARDAR EL VOLUMEN: $e');
    }
  }
}


// ============================================================
// SONIDO DEL BUZZER
//
// Los sonidos se generan dentro de la app (no hacen falta
// archivos de audio). Mientras un Buzzer colocado en Diseño y
// Conexiones esté en ON, suena su sonido; al pasar a OFF se
// detiene. El volumen es el de la pantalla de Ajustes.
// ============================================================

class SonidoBuzzer {

  final String nombre;

  const SonidoBuzzer(this.nombre);
}

class BuzzerManager {

  BuzzerManager._();

  static final BuzzerManager instance = BuzzerManager._();

  // Si es false, un Buzzer cuya entrada está asignada a un puerto
  // de un módulo (buzzer físico) NO suena en la tablet; solo suena
  // el Buzzer virtual. Ponerlo en true para que suenen los dos.
  static const bool suenaTambienSiEsFisico = false;

  static const String sonidoPorDefecto = 'pitido';

  // Sonidos disponibles (id -> nombre que se muestra).
  static const Map<String, SonidoBuzzer> sonidos = {
    'pitido': SonidoBuzzer('Pitido continuo'),
    'agudo': SonidoBuzzer('Tono agudo'),
    'grave': SonidoBuzzer('Tono grave'),
    'intermitente': SonidoBuzzer('Pitido intermitente'),
    'alarma': SonidoBuzzer('Alarma (dos tonos)'),
    'sirena': SonidoBuzzer('Sirena'),
  };

  // 24 000 muestras por segundo: los tonos de abajo dan un número
  // exacto de ciclos y se repiten sin cortes.
  static const int _frecuenciaMuestreo = 24000;

  AudioPlayer? _player;

  Timer? _timer;

  bool _inicializado = false;

  bool _ocupado = false;

  // Sonido que está sonando ahora (null = silencio).
  String? _sonidoActual;

  // Vista previa temporal (botón "Probar sonido").
  String? _sonidoPrueba;

  DateTime _pruebaHasta =
  DateTime.fromMillisecondsSinceEpoch(0);

  final Map<String, Uint8List> _cacheWav = {};

  // Se llama una sola vez al iniciar la app.
  void inicializar() {

    if (_inicializado) {
      return;
    }

    _inicializado = true;

    AjustesApp.instance.addListener(_aplicarVolumen);

    _timer = Timer.periodic(
      const Duration(milliseconds: 150),
          (_) => _revisar(),
    );
  }

  // ¿Debe sonar este Buzzer?
  bool _debeSonar(PlacedComponent comp) {

    if (!suenaTambienSiEsFisico &&
        comp.asignaciones.isNotEmpty) {
      return false;
    }

    return comp.activo;
  }

  // Suena un sonido unos instantes (para probarlo).
  void probar(String id, {int milisegundos = 1200}) {

    _sonidoPrueba = id;

    _pruebaHasta = DateTime.now().add(
      Duration(milliseconds: milisegundos),
    );

    _revisar();
  }

  // Decide qué debe sonar según el estado de los Buzzer.
  void _revisar() {

    String? deseado;

    try {

      for (final comp
      in _DesignScreenState._componentesPersistentes) {

        if (comp.component.id != 'buzzer') {
          continue;
        }

        if (_debeSonar(comp)) {

          deseado = sonidos.containsKey(comp.sonido)
              ? comp.sonido
              : sonidoPorDefecto;

          break;
        }
      }

    } catch (e) {

      print('ERROR BUZZER: $e');
    }

    if (deseado == null &&
        DateTime.now().isBefore(_pruebaHasta)) {

      deseado = _sonidoPrueba;
    }

    unawaited(_aplicar(deseado));
  }

  Future<void> _aplicar(String? id) async {

    if (_ocupado || id == _sonidoActual) {
      return;
    }

    _ocupado = true;

    try {

      final player = _player ??= AudioPlayer();

      if (id == null) {

        await player.stop();

      } else {

        await player.setReleaseMode(ReleaseMode.loop);

        await player.setVolume(AjustesApp.instance.volumen);

        await player.play(
          BytesSource(
            _wavDe(id),
            mimeType: 'audio/wav',
          ),
        );
      }

    } catch (e) {

      print('ERROR AL REPRODUCIR EL BUZZER: $e');

    } finally {

      _sonidoActual = id;

      _ocupado = false;
    }
  }

  void _aplicarVolumen() {

    final player = _player;

    if (player == null) {
      return;
    }

    player
        .setVolume(AjustesApp.instance.volumen)
        .catchError((Object e) {
      print('ERROR AL CAMBIAR EL VOLUMEN: $e');
    });
  }

  // ==========================================================
  // GENERACIÓN DE LOS SONIDOS (WAV de 16 bits, mono)
  // ==========================================================

  Uint8List _wavDe(String id) {

    return _cacheWav.putIfAbsent(
      id,
          () => _generarWav(id),
    );
  }

  Uint8List _generarWav(String id) {

    final muestras = <int>[];

    const double amplitud = 0.5;

    // Onda cuadrada (suena como un zumbador).
    void tono(
        double frecuencia,
        double segundos, {
          bool suavizar = false,
        }) {

      final n = (segundos * _frecuenciaMuestreo).round();

      final rampa = (0.005 * _frecuenciaMuestreo).round();

      for (int i = 0; i < n; i++) {

        final fase =
            (i * frecuencia / _frecuenciaMuestreo) % 1.0;

        double v = fase < 0.5 ? 1.0 : -1.0;

        // Entrada y salida suaves para evitar chasquidos.
        if (suavizar) {

          if (i < rampa) {
            v *= i / rampa;
          }

          if (n - 1 - i < rampa) {
            v *= (n - 1 - i) / rampa;
          }
        }

        muestras.add((v * amplitud * 32767).round());
      }
    }

    void silencio(double segundos) {

      final n = (segundos * _frecuenciaMuestreo).round();

      for (int i = 0; i < n; i++) {
        muestras.add(0);
      }
    }

    // Sirena: el tono sube y baja entre 600 Hz y 1300 Hz.
    void sirena() {

      const double duracion = 1.6;

      final n = (duracion * _frecuenciaMuestreo).round();

      double fase = 0.0;

      for (int i = 0; i < n; i++) {

        final x = i / n;

        final triangulo = x < 0.5 ? x * 2 : (1 - x) * 2;

        final frecuencia = 600 + 700 * triangulo;

        fase += frecuencia / _frecuenciaMuestreo;

        fase -= fase.floorToDouble();

        final v = fase < 0.5 ? 1.0 : -1.0;

        muestras.add((v * amplitud * 32767).round());
      }
    }

    switch (id) {

      case 'agudo':
        tono(2000, 0.5);
        break;

      case 'grave':
        tono(400, 0.5);
        break;

      case 'intermitente':
        tono(1000, 0.2, suavizar: true);
        silencio(0.2);
        break;

      case 'alarma':
        tono(800, 0.25);
        tono(1200, 0.25);
        break;

      case 'sirena':
        sirena();
        break;

      default:
        tono(1000, 0.5);
        break;
    }

    return _empaquetarWav(muestras);
  }

  Uint8List _empaquetarWav(List<int> muestras) {

    final bytesDatos = muestras.length * 2;

    final datos = ByteData(44 + bytesDatos);

    void texto(int posicion, String valor) {

      for (int i = 0; i < valor.length; i++) {
        datos.setUint8(posicion + i, valor.codeUnitAt(i));
      }
    }

    texto(0, 'RIFF');
    datos.setUint32(4, 36 + bytesDatos, Endian.little);
    texto(8, 'WAVE');
    texto(12, 'fmt ');
    datos.setUint32(16, 16, Endian.little);
    datos.setUint16(20, 1, Endian.little);
    datos.setUint16(22, 1, Endian.little);
    datos.setUint32(24, _frecuenciaMuestreo, Endian.little);
    datos.setUint32(28, _frecuenciaMuestreo * 2, Endian.little);
    datos.setUint16(32, 2, Endian.little);
    datos.setUint16(34, 16, Endian.little);
    texto(36, 'data');
    datos.setUint32(40, bytesDatos, Endian.little);

    for (int i = 0; i < muestras.length; i++) {
      datos.setInt16(44 + i * 2, muestras[i], Endian.little);
    }

    return datos.buffer.asUint8List();
  }
}


// ============================================================
// PANTALLA DE AJUSTES
// ============================================================

class AjustesScreen extends StatefulWidget {

  const AjustesScreen({
    super.key,
  });

  @override
  State<AjustesScreen> createState() =>
      _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {

  final AjustesApp ajustes = AjustesApp.instance;

  @override
  void initState() {

    super.initState();

    ajustes.addListener(_actualizarPantalla);
  }

  void _actualizarPantalla() {

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {

    ajustes.removeListener(_actualizarPantalla);

    super.dispose();
  }

  // ==========================================================
  // CAMBIAR NOMBRE
  // ==========================================================

  Future<void> _cambiarNombre() async {

    final nuevo = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _DialogoNombre(
          nombreActual: ajustes.nombreUsuario,
        );
      },
    );

    if (nuevo == null || !mounted) {
      return;
    }

    await ajustes.cambiarNombre(nuevo);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            'Nombre cambiado a ${ajustes.nombreUsuario}.',
          ),
        ),
      );
  }

  // ==========================================================
  // ABRIR GUÍA
  // ==========================================================

  void _abrirGuia() {

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const GuiaScreen(),
      ),
    );
  }

  // Botón de bordes redondeados (como en el diseño).
  Widget _botonRedondeado(
      String texto,
      double fuente,
      VoidCallback onPressed) {

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(
          color: Colors.black,
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: fuente,
          color: Colors.black,
        ),
      ),
    );
  }

  // ==========================================================
  // INTERFAZ
  // ==========================================================

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;

    final alto = size.height;
    final ancho = size.width;

    final fuenteTexto = (alto * 0.050).clamp(20.0, 34.0);

    final fuenteBoton = (alto * 0.040).clamp(16.0, 26.0);

    final margenH = (ancho * 0.045).clamp(24.0, 90.0);

    final margenV = (alto * 0.045).clamp(14.0, 48.0);

    final botonAlto = (alto * 0.090).clamp(42.0, 70.0);

    final anchoCambiar = (ancho * 0.12).clamp(120.0, 220.0);

    final anchoGuia = (ancho * 0.30).clamp(220.0, 520.0);

    final estiloTexto = TextStyle(
      fontSize: fuenteTexto,
      color: Colors.black,
    );

    return Scaffold(

      backgroundColor: Colors.white,

      body: SafeArea(

        child: Column(

          children: [

            // ==================================================
            // CABECERA
            // ==================================================

            AppHeader(
              title: 'Ajustes / Configuración / Ayuda',
              onBack: () {
                Navigator.pop(context);
              },
            ),

            // ==================================================
            // CONTENIDO
            // ==================================================

            Expanded(

              child: Padding(

                padding: EdgeInsets.fromLTRB(
                  margenH,
                  margenV,
                  margenH,
                  margenV,
                ),

                child: Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    // ------------------------------------------
                    // NOMBRE + BOTÓN CAMBIAR
                    // ------------------------------------------

                    Row(

                      children: [

                        Expanded(
                          child: Text(
                            'Nombre: ${ajustes.nombreUsuario}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: estiloTexto,
                          ),
                        ),

                        SizedBox(
                          width: anchoCambiar,
                          height: botonAlto * 0.85,
                          child: _botonRedondeado(
                            'Cambiar',
                            fuenteBoton,
                            _cambiarNombre,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: margenV),

                    // ------------------------------------------
                    // VOLUMEN (izquierda) + GUÍA (derecha)
                    // ------------------------------------------

                    Expanded(

                      child: Row(

                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,

                        children: [

                          // ----------------------------------
                          // AJUSTAR VOLUMEN
                          // ----------------------------------

                          Expanded(

                            child: Column(

                              crossAxisAlignment:
                              CrossAxisAlignment.start,

                              children: [

                                Text(
                                  'Ajustar volumen',
                                  style: estiloTexto,
                                ),

                                SizedBox(height: margenV * 0.6),

                                const Expanded(
                                  child: Align(
                                    alignment:
                                    Alignment.centerLeft,
                                    child: _ControlVolumen(),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ----------------------------------
                          // ABRIR GUÍA DE USO
                          // ----------------------------------

                          Expanded(

                            child: Align(

                              alignment: Alignment.bottomRight,

                              child: SizedBox(

                                width: anchoGuia,

                                child: Column(

                                  mainAxisSize:
                                  MainAxisSize.min,

                                  children: [

                                    Text(
                                      'Abrir guía de uso de la app',
                                      textAlign:
                                      TextAlign.center,
                                      style: estiloTexto,
                                    ),

                                    SizedBox(
                                      height: margenV * 0.6,
                                    ),

                                    SizedBox(
                                      width: double.infinity,
                                      height: botonAlto,
                                      child: _botonRedondeado(
                                        'Guía',
                                        fuenteBoton,
                                        _abrirGuia,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// DIÁLOGO PARA CAMBIAR EL NOMBRE
// ============================================================

class _DialogoNombre extends StatefulWidget {

  final String nombreActual;

  const _DialogoNombre({
    required this.nombreActual,
  });

  @override
  State<_DialogoNombre> createState() =>
      _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {

  late final TextEditingController _controlador;

  @override
  void initState() {

    super.initState();

    _controlador = TextEditingController(
      text: widget.nombreActual,
    );

    _controlador.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controlador.text.length,
    );
  }

  @override
  void dispose() {

    _controlador.dispose();

    super.dispose();
  }

  void _guardar() {

    final texto = _controlador.text.trim();

    if (texto.isEmpty) {
      return;
    }

    Navigator.pop(context, texto);
  }

  @override
  Widget build(BuildContext context) {

    return AlertDialog(

      scrollable: true,

      title: const Text('Cambiar nombre'),

      content: SizedBox(

        width: 380,

        child: TextField(
          controller: _controlador,
          autofocus: true,
          maxLength: AjustesApp.largoMaximoNombre,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre del usuario',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _guardar(),
        ),
      ),

      actions: [

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),

        TextButton(
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}


// ============================================================
// BARRA VERTICAL DE VOLUMEN (con las barras indicadoras)
// ============================================================

class _ControlVolumen extends StatelessWidget {

  const _ControlVolumen();

  static const double _anchoControl = 90;
  static const double _anchoPista = 30;
  static const double _altoManija = 28;

  // Largo de cada barra indicadora (de arriba hacia abajo).
  static const List<double> _largosBarras = [
    104, 92, 80, 70, 60, 50, 42, 34,
  ];

  void _fijarDesdeToque(double dy, double alto) {

    final recorrido = alto - _altoManija;

    if (recorrido <= 0) {
      return;
    }

    final valor = 1.0 - ((dy - _altoManija / 2) / recorrido);

    AjustesApp.instance.establecerVolumen(valor);
  }

  // Al soltar: se guarda y se hace sonar un pitido corto para
  // que se escuche el nivel elegido.
  void _terminar() {

    AjustesApp.instance.guardarVolumen();

    BuzzerManager.instance.probar(
      'pitido',
      milisegundos: 350,
    );
  }

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (context, constraints) {

        final disponible = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 300.0;

        final alto = disponible < 320.0 ? disponible : 320.0;

        return AnimatedBuilder(
          animation: AjustesApp.instance,
          builder: (context, _) {

            final volumen = AjustesApp.instance.volumen;

            final recorrido = alto - _altoManija;

            final arriba = (1.0 - volumen) * recorrido;

            // Barras encendidas (se llenan desde abajo).
            final encendidas =
            (volumen * _largosBarras.length).ceil();

            return SizedBox(

              height: alto,

              child: Row(

                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  // ------------------------------------------
                  // BARRA DESLIZANTE
                  // ------------------------------------------

                  GestureDetector(

                    behavior: HitTestBehavior.opaque,

                    onTapDown: (d) => _fijarDesdeToque(
                      d.localPosition.dy,
                      alto,
                    ),

                    onTapUp: (_) => _terminar(),

                    onVerticalDragStart: (d) => _fijarDesdeToque(
                      d.localPosition.dy,
                      alto,
                    ),

                    onVerticalDragUpdate: (d) => _fijarDesdeToque(
                      d.localPosition.dy,
                      alto,
                    ),

                    onVerticalDragEnd: (_) => _terminar(),

                    child: SizedBox(

                      width: _anchoControl,

                      child: Stack(

                        children: [

                          // Pista
                          Positioned(
                            left: (_anchoControl - _anchoPista) / 2,
                            width: _anchoPista,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(
                                  _anchoPista / 2,
                                ),
                              ),
                            ),
                          ),

                          // Manija
                          Positioned(
                            left: 0,
                            width: _anchoControl,
                            top: arriba,
                            height: _altoManija,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(
                                  _altoManija / 2,
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 18),

                  // ------------------------------------------
                  // BARRAS INDICADORAS
                  // ------------------------------------------

                  Column(

                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,

                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      for (int i = 0; i < _largosBarras.length; i++)
                        Container(
                          width: _largosBarras[i],
                          height: 16,
                          decoration: BoxDecoration(
                            color: (_largosBarras.length - 1 - i) <
                                encendidas
                                ? Colors.black
                                : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}


// ============================================================
// GUÍA DE USO DE LA APP
// ============================================================

class _SeccionGuia {

  final IconData icono;
  final String titulo;
  final List<String> parrafos;

  const _SeccionGuia(
      this.icono,
      this.titulo,
      this.parrafos,
      );
}

class GuiaScreen extends StatelessWidget {

  const GuiaScreen({
    super.key,
  });

  static const List<_SeccionGuia> _secciones = [

    _SeccionGuia(
      Icons.home_outlined,
      'Pantalla de inicio',
      [
        'Desde aquí se accede a todas las secciones: Bluetooth, '
            'Prueba de pines, Escanear QR, Diseño y conexiones, '
            'Programación por bloques y Monitoreo síncrono.',
        'El botón de la esquina superior izquierda cierra la app '
            'y el engranaje de la derecha abre los Ajustes.',
      ],
    ),

    _SeccionGuia(
      Icons.bluetooth,
      'Bluetooth',
      [
        'Conecta la tablet o el teléfono con el ESP32.',
        '1) Pulse Buscar. 2) Cuando aparezca el ESP32 '
            '(ESP32-AUTOMATIZACION2, en negrita) pulse Conectar.',
        'El círculo junto a "Estado" es verde cuando hay '
            'conexión, naranja mientras se intenta reconectar y '
            'rojo cuando no hay conexión.',
        'Si la conexión se corta de forma inesperada, la app '
            'intenta reconectar sola durante unos 5 segundos. Si '
            'no lo logra, queda desconectada y el ESP32 queda libre '
            'para que otro dispositivo se conecte.',
        'Desconectar cierra la conexión manualmente.',
      ],
    ),

    _SeccionGuia(
      Icons.settings_input_component,
      'Prueba de pines',
      [
        'Elija un módulo (1 a 4) en la columna de la izquierda para '
            'ver sus puertos.',
        'Entrada digital (DI): muestra ON u OFF.',
        'Salida digital (DO): los botones ON y OFF encienden y '
            'apagan el puerto.',
        'Entrada analógica (AI): muestra el voltaje. El símbolo de '
            'advertencia junto a "Estado de los pines" indica que ese '
            'voltaje es referencial y no refleja el verdadero valor '
            'de un sensor.',
        'En los módulos DO solo funcionan los puertos 1 y 4. Los '
            'puertos 2 y 3 aparecen deshabilitados y tampoco se '
            'pueden usar en Diseño y conexiones ni en la '
            'programación por bloques.',
      ],
    ),

    _SeccionGuia(
      Icons.qr_code_2,
      'Escanear QR',
      [
        'Apunte la cámara al código QR de un sensor o actuador.',
        'Si el QR corresponde a un componente de la app, se '
            'muestran su nombre, tipo, número de entradas y salidas '
            'y una breve descripción.',
        '"Link para más información" abre la página del fabricante '
            'cuando está disponible.',
      ],
    ),

    _SeccionGuia(
      Icons.touch_app_outlined,
      'Diseño y conexiones',
      [
        'Aquí se arma el sistema. Abra la lista de Componentes y '
            'arrastre al área de trabajo actuadores, sensores u '
            'otros componentes (Switch, Botón, LED y Buzzer).',
        'Toque un componente para ver su información. "Asignar" '
            'vincula un pin del componente con un puerto de un '
            'módulo conectado.',
        'Cable: active el botón, toque el componente de origen '
            '(salida DO), elija el puerto y toque el componente de '
            'destino (entrada DI). Con Cable activo, toque un cable '
            'para eliminarlo.',
        'Mover: active el botón, toque un componente y luego el '
            'lugar de destino.',
        'Eliminar: active el botón (el del basurero, junto a Cable y '
            'Mover) y toque un componente para eliminarlo.',
        'En los componentes de "Otros" el doble toque permite '
            'agregar puertos de entrada o salida.',
        'Buzzer: cuando está en ON suena. En su información puede '
            'elegir el sonido y probarlo.',
        'LED: en su información puede elegir el color con el que '
            'enciende.',
        'Sensor de presión: el botón Calibrar de su información '
            'permite ingresar de 4 a 8 pares de valores (voltaje de la '
            'app y presión del sensor). La app calcula los parámetros '
            'A y B de Presión = A × Voltaje + B y muestra el '
            'coeficiente de determinación R².',
        'Comenzar / Parar: pone en marcha o detiene el envío de '
            'órdenes al ESP32 (cables de esta pantalla y programa '
            'por bloques).',
      ],
    ),

    _SeccionGuia(
      Icons.code,
      'Programación por bloques',
      [
        'Cree la lógica uniendo bloques con cables: entradas (DI, '
            'AI), salidas (DO), variables virtuales (V DI, V DO) y '
            'compuertas lógicas (AND, OR, NOT, XOR, NAND, NOR).',
        'Los bloques DI, DO y AI se asignan a un puerto de un módulo. '
            'Toque TON o TOF para configurar su tiempo entre 1 y 20 segundos. '
            'TON retrasa la activación y TOF retrasa la desactivación.',
        'Comparaciones (>= y <): conecte un bloque AI a su entrada y '
            'toque el bloque para configurar el valor de comparación. '
            'Si el AI está asignado al puerto del sensor de presión, '
            'se compara en bar (con su calibración); en los demás casos '
            'se compara el voltaje.',
        'Los cables hechos en Diseño y conexiones aparecen aquí '
            'como bloques unidos. Una misma conexión física no puede '
            'estar a la vez en Diseño y en la programación.',
        'El programa se ejecuta cuando el sistema está en marcha '
            '(botón Comenzar de Diseño y conexiones).',
      ],
    ),

    _SeccionGuia(
      Icons.monitor_heart_outlined,
      'Monitoreo síncrono',
      [
        'Muestra en tiempo real el estado de las variables que '
            'usted elija: puertos de los módulos y pines de los '
            'componentes.',
        'Use el botón de añadir para agregar variables y el de '
            'eliminar para quitarlas de la lista.',
        'Los Switch y Botones virtuales se pueden accionar desde '
            'aquí. El LED muestra un circulito que se enciende con su '
            'color y el Buzzer muestra su estado.',
        'Si asigna una entrada analógica al sensor de presión '
            '(Festo 572745), se muestra la presión en bares.',
        'Para que las órdenes lleguen al ESP32, el sistema debe '
            'estar en marcha (Comenzar en Diseño y conexiones).',
      ],
    ),

    _SeccionGuia(
      Icons.settings_outlined,
      'Ajustes',
      [
        'Cambiar: modifica el nombre que aparece en el saludo de '
            'la pantalla de inicio.',
        'Ajustar volumen: sube o baja el volumen del sonido del '
            'Buzzer. Al soltar la barra suena un pitido corto para '
            'que escuche el nivel.',
        'Guía: abre esta guía de uso.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {

    final size = MediaQuery.of(context).size;

    final fuenteTitulo = (size.height * 0.036).clamp(17.0, 26.0);

    final fuenteTexto = (size.height * 0.030).clamp(14.0, 22.0);

    final margenH = (size.width * 0.04).clamp(16.0, 80.0);

    return Scaffold(

      backgroundColor: Colors.white,

      body: SafeArea(

        child: Column(

          children: [

            AppHeader(
              title: 'Guía de uso',
              onBack: () {
                Navigator.pop(context);
              },
            ),

            Expanded(

              child: Theme(

                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),

                child: ListView(

                  padding: EdgeInsets.symmetric(
                    horizontal: margenH,
                    vertical: 16,
                  ),

                  children: [

                    for (final seccion in _secciones)
                      Container(

                        margin: const EdgeInsets.only(bottom: 12),

                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),

                        child: ExpansionTile(

                          leading: Icon(
                            seccion.icono,
                            color: Colors.black,
                            size: fuenteTitulo * 1.3,
                          ),

                          title: Text(
                            seccion.titulo,
                            style: TextStyle(
                              fontSize: fuenteTitulo,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),

                          iconColor: Colors.black,

                          collapsedIconColor: Colors.black,

                          childrenPadding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 16),

                          expandedCrossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [

                            for (final parrafo in seccion.parrafos)
                              Padding(
                                padding:
                                const EdgeInsets.only(top: 8),
                                child: Text(
                                  parrafo,
                                  style: TextStyle(
                                    fontSize: fuenteTexto,
                                    color: Colors.black,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// LED: COLORES DISPONIBLES
// ============================================================

class OpcionColorLed {

  final String nombre;
  final Color color;

  const OpcionColorLed(this.nombre, this.color);
}

const List<OpcionColorLed> kColoresLed = [
  OpcionColorLed('Rojo', Color(0xFFE53935)),
  OpcionColorLed('Verde', Color(0xFF43A047)),
  OpcionColorLed('Azul', Color(0xFF1E88E5)),
  OpcionColorLed('Amarillo', Color(0xFFFDD835)),
  OpcionColorLed('Naranja', Color(0xFFFB8C00)),
  OpcionColorLed('Blanco', Color(0xFFF5F5F5)),
];


// ============================================================
// IMAGEN DE UN COMPONENTE
//
// El LED se dibuja como un LED electrónico (con su color); los
// demás componentes usan su imagen.
// ============================================================

class ImagenComponente extends StatelessWidget {

  final ComponentModel modelo;

  // Imagen a usar (por ejemplo la de "encendido"). Si es null se
  // usa la imagen normal del modelo.
  final String? asset;

  final bool encendido;

  final Color? colorLed;

  // Tamaño del ícono que se muestra si la imagen no existe.
  final double tamanoIcono;

  const ImagenComponente({
    super.key,
    required this.modelo,
    this.asset,
    this.encendido = false,
    this.colorLed,
    this.tamanoIcono = 60,
  });

  @override
  Widget build(BuildContext context) {

    if (modelo.id == 'led') {

      return LedElectronico(
        color: colorLed ?? kColoresLed.first.color,
        encendido: encendido,
      );
    }

    return Image.asset(
      asset ?? modelo.imageAsset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.precision_manufacturing_outlined,
          size: tamanoIcono,
          color: Colors.black,
        );
      },
    );
  }
}


// ============================================================
// LED ELECTRÓNICO (dibujo)
// ============================================================

class LedElectronico extends StatelessWidget {

  final Color color;

  final bool encendido;

  const LedElectronico({
    super.key,
    required this.color,
    required this.encendido,
  });

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (context, constraints) {

        final ancho = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 100.0);

        final alto = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : ancho;

        final lado = ancho < alto ? ancho : alto;

        return Center(
          child: SizedBox(
            width: lado,
            height: lado,
            child: CustomPaint(
              painter: _LedPainter(color, encendido),
            ),
          ),
        );
      },
    );
  }
}

const double _piLed = 3.141592653589793;

class _LedPainter extends CustomPainter {

  final Color color;

  final bool encendido;

  const _LedPainter(this.color, this.encendido);

  @override
  void paint(Canvas canvas, Size size) {

    final s = size.width;

    final cx = s / 2;

    // Medidas del LED (cúpula, cuerpo, reborde y patas).
    final anchoCuerpo = s * 0.40;
    final izq = cx - anchoCuerpo / 2;
    final der = cx + anchoCuerpo / 2;

    final yCupula = s * 0.08;
    final yInicioCuerpo = yCupula + anchoCuerpo / 2;
    final yBase = s * 0.64;
    final yReborde = s * 0.70;
    final anchoReborde = anchoCuerpo * 1.22;

    final grosorLinea = s * 0.012 < 1.2 ? 1.2 : s * 0.012;

    final colorPlastico =
    encendido ? color : color.withValues(alpha: 0.45);

    // ----------------------------------------------------------
    // RESPLANDOR (solo encendido)
    // ----------------------------------------------------------

    if (encendido) {

      final centro = Offset(cx, yInicioCuerpo);

      final radio = s * 0.55;

      canvas.drawCircle(
        centro,
        radio,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.70),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: centro, radius: radio),
          ),
      );
    }

    // ----------------------------------------------------------
    // PATAS (la derecha, más larga, es el ánodo)
    // ----------------------------------------------------------

    final pata = Paint()
      ..color = const Color(0xFF8D8D8D)
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;

    final separacion = anchoCuerpo * 0.26;

    canvas.drawLine(
      Offset(cx - separacion, yReborde),
      Offset(cx - separacion, s * 0.90),
      pata,
    );

    canvas.drawLine(
      Offset(cx + separacion, yReborde),
      Offset(cx + separacion, s * 0.98),
      pata,
    );

    // ----------------------------------------------------------
    // CUERPO (cúpula + cilindro)
    // ----------------------------------------------------------

    final cuerpo = Path()
      ..moveTo(izq, yBase)
      ..lineTo(izq, yInicioCuerpo)
      ..arcTo(
        Rect.fromLTRB(izq, yCupula, der, yCupula + anchoCuerpo),
        _piLed,
        _piLed,
        false,
      )
      ..lineTo(der, yBase)
      ..close();

    canvas.drawPath(
      cuerpo,
      Paint()..color = colorPlastico,
    );

    // ----------------------------------------------------------
    // ELECTRODOS INTERNOS
    // ----------------------------------------------------------

    final interno = Paint()
      ..color = const Color(0xFF616161).withValues(alpha: 0.85)
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx - anchoCuerpo * 0.12, yBase),
      Offset(cx - anchoCuerpo * 0.12, yInicioCuerpo + anchoCuerpo * 0.08),
      interno,
    );

    canvas.drawLine(
      Offset(cx + anchoCuerpo * 0.12, yBase),
      Offset(cx + anchoCuerpo * 0.12, yInicioCuerpo + anchoCuerpo * 0.26),
      interno,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        cx - anchoCuerpo * 0.26,
        yInicioCuerpo + anchoCuerpo * 0.02,
        anchoCuerpo * 0.28,
        anchoCuerpo * 0.10,
      ),
      Paint()
        ..color = const Color(0xFF616161).withValues(alpha: 0.85),
    );

    // ----------------------------------------------------------
    // BRILLO DEL PLÁSTICO
    // ----------------------------------------------------------

    canvas.drawArc(
      Rect.fromLTRB(
        izq + anchoCuerpo * 0.12,
        yCupula + anchoCuerpo * 0.10,
        der - anchoCuerpo * 0.12,
        yCupula + anchoCuerpo * 0.90,
      ),
      _piLed * 1.05,
      _piLed * 0.38,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.022
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // ----------------------------------------------------------
    // CONTORNO DEL CUERPO
    // ----------------------------------------------------------

    final contorno = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosorLinea
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black;

    canvas.drawPath(cuerpo, contorno);

    // ----------------------------------------------------------
    // REBORDE
    // ----------------------------------------------------------

    final reborde = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cx - anchoReborde / 2,
        yBase,
        cx + anchoReborde / 2,
        yReborde,
      ),
      Radius.circular(s * 0.012),
    );

    canvas.drawRRect(
      reborde,
      Paint()..color = colorPlastico,
    );

    canvas.drawRRect(reborde, contorno);
  }

  @override
  bool shouldRepaint(covariant _LedPainter anterior) {

    return anterior.color != color ||
        anterior.encendido != encendido;
  }
}


// ============================================================
// REGRESIÓN LINEAL (para calibrar el sensor de presión)
//
//   presión = A * voltaje + B
//
// R² (coeficiente de determinación) indica qué tan bien se
// ajustan los parámetros a los valores ingresados.
// ============================================================

class ResultadoRegresion {

  final double a;
  final double b;

  // Entre 0 y 1 (1 = ajuste perfecto).
  final double r2;

  const ResultadoRegresion(this.a, this.b, this.r2);
}

// Devuelve null si no se puede calcular (por ejemplo, si todos
// los voltajes son iguales).
ResultadoRegresion? regresionLineal(
    List<double> x,
    List<double> y) {

  final n = x.length;

  if (n < 2 || y.length != n) {
    return null;
  }

  double sumaX = 0;
  double sumaY = 0;
  double sumaXY = 0;
  double sumaXX = 0;

  for (int i = 0; i < n; i++) {
    sumaX += x[i];
    sumaY += y[i];
    sumaXY += x[i] * y[i];
    sumaXX += x[i] * x[i];
  }

  final denominador = n * sumaXX - sumaX * sumaX;

  if (denominador.abs() < 1e-12) {
    return null;
  }

  final a = (n * sumaXY - sumaX * sumaY) / denominador;

  final b = (sumaY - a * sumaX) / n;

  final promedioY = sumaY / n;

  double ssTotal = 0;
  double ssResidual = 0;

  for (int i = 0; i < n; i++) {

    final estimado = a * x[i] + b;

    ssResidual += (y[i] - estimado) * (y[i] - estimado);

    ssTotal += (y[i] - promedioY) * (y[i] - promedioY);
  }

  double r2;

  if (ssTotal < 1e-12) {
    r2 = ssResidual < 1e-12 ? 1.0 : 0.0;
  } else {
    r2 = 1.0 - ssResidual / ssTotal;
  }

  if (r2 < 0) r2 = 0;
  if (r2 > 1) r2 = 1;

  return ResultadoRegresion(a, b, r2);
}


// ============================================================
// DIÁLOGO DE CALIBRACIÓN DEL SENSOR DE PRESIÓN
// ============================================================

class _ResultadoCalibracion {

  // true = volver a los valores de fábrica.
  final bool restablecer;

  final double a;
  final double b;
  final double? r2;

  final List<List<double>> puntos;

  const _ResultadoCalibracion({
    required this.restablecer,
    required this.a,
    required this.b,
    required this.r2,
    required this.puntos,
  });
}

class _DialogoCalibracion extends StatefulWidget {

  final PlacedComponent componente;

  const _DialogoCalibracion({
    required this.componente,
  });

  @override
  State<_DialogoCalibracion> createState() =>
      _DialogoCalibracionState();
}

class _DialogoCalibracionState
    extends State<_DialogoCalibracion> {

  static const int _minimo = 4;
  static const int _maximo = 8;

  final List<TextEditingController> _voltajes = [];
  final List<TextEditingController> _presiones = [];

  String? _error;

  ResultadoRegresion? _resultado;

  List<List<double>> _puntosValidos = [];

  String _formato(double valor) {

    return valor.toStringAsFixed(2);
  }

  @override
  void initState() {

    super.initState();

    // Si ya se calibró antes, se muestran esos valores.
    final previos = widget.componente.calibPuntos;

    final filas = previos.length < _minimo
        ? _minimo
        : (previos.length > _maximo ? _maximo : previos.length);

    for (int i = 0; i < filas; i++) {

      final hayPrevio = i < previos.length;

      _voltajes.add(
        TextEditingController(
          text: hayPrevio ? _formato(previos[i][0]) : '',
        ),
      );

      _presiones.add(
        TextEditingController(
          text: hayPrevio ? _formato(previos[i][1]) : '',
        ),
      );
    }
  }

  @override
  void dispose() {

    for (final c in _voltajes) {
      c.dispose();
    }

    for (final c in _presiones) {
      c.dispose();
    }

    super.dispose();
  }

  double? _numero(String texto) {

    return double.tryParse(
      texto.trim().replaceAll(',', '.'),
    );
  }

  void _agregarFila() {

    if (_voltajes.length >= _maximo) {
      return;
    }

    setState(() {
      _voltajes.add(TextEditingController());
      _presiones.add(TextEditingController());
      _resultado = null;
    });
  }

  void _quitarFila(int indice) {

    if (_voltajes.length <= _minimo) {
      return;
    }

    setState(() {

      _voltajes.removeAt(indice).dispose();
      _presiones.removeAt(indice).dispose();

      _resultado = null;
    });
  }

  // Copia en la fila el voltaje que la app está leyendo ahora.
  void _usarVoltajeActual(int indice) {

    final componente = widget.componente;

    double? voltaje;

    if (componente.outputs.isNotEmpty) {

      final asignacion =
      componente.asignaciones[componente.outputs.first.id];

      if (asignacion != null) {
        voltaje =
            EjecutorGlobal.instance.valorFisico(asignacion);
      }
    }

    if (voltaje == null) {

      setState(() {
        _error = 'No hay lectura de voltaje. Asigne el sensor a '
            'una entrada analógica y conecte el ESP32.';
      });

      return;
    }

    setState(() {

      _voltajes[indice].text = _formato(voltaje!);

      _error = null;
      _resultado = null;
    });
  }

  void _calcular() {

    final x = <double>[];
    final y = <double>[];

    for (int i = 0; i < _voltajes.length; i++) {

      final textoV = _voltajes[i].text.trim();
      final textoP = _presiones[i].text.trim();

      if (textoV.isEmpty && textoP.isEmpty) {
        continue;
      }

      if (textoV.isEmpty || textoP.isEmpty) {

        setState(() {
          _error = 'Complete el voltaje y la presión de la fila '
              '${i + 1}, o déjelos vacíos.';
          _resultado = null;
        });

        return;
      }

      final v = _numero(textoV);
      final p = _numero(textoP);

      if (v == null || p == null) {

        setState(() {
          _error = 'La fila ${i + 1} tiene un valor que no es un '
              'número.';
          _resultado = null;
        });

        return;
      }

      x.add(v);
      y.add(p);
    }

    if (x.length < _minimo) {

      setState(() {
        _error = 'Ingrese al menos $_minimo pares de valores '
            '(máximo $_maximo).';
        _resultado = null;
      });

      return;
    }

    final r = regresionLineal(x, y);

    if (r == null) {

      setState(() {
        _error = 'Los voltajes no pueden ser todos iguales: varíe '
            'la presión para tomar los valores.';
        _resultado = null;
      });

      return;
    }

    setState(() {

      _error = null;

      _resultado = r;

      _puntosValidos = [
        for (int i = 0; i < x.length; i++) [x[i], y[i]],
      ];
    });
  }

  Widget _campo(
      TextEditingController controlador,
      String etiqueta) {

    return TextField(
      controller: controlador,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      onChanged: (_) {
        if (_resultado != null) {
          setState(() {
            _resultado = null;
          });
        }
      },
      decoration: InputDecoration(
        labelText: etiqueta,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String _calidad(double r2) {

    if (r2 >= 0.99) return 'Excelente ajuste';
    if (r2 >= 0.95) return 'Buen ajuste';
    if (r2 >= 0.90) return 'Ajuste aceptable';
    return 'Ajuste bajo: revise los valores ingresados';
  }

  @override
  Widget build(BuildContext context) {

    final componente = widget.componente;

    final resultado = _resultado;

    return AlertDialog(

      scrollable: true,

      title: const Text('Calibrar sensor de presión'),

      content: SizedBox(

        width: 620,

        child: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              'Ingrese de 4 a 8 pares de valores medidos al mismo '
                  'tiempo: el voltaje que muestra la app y la presión '
                  '(en bar) que muestra el sensor. La app calcula A y B '
                  'para que:  Presión = A × Voltaje + B',
            ),

            const SizedBox(height: 8),

            Text(
              'Parámetros actuales:  '
                  'A = ${componente.calibA.toStringAsFixed(4)},  '
                  'B = ${componente.calibB.toStringAsFixed(4)}'
                  '${componente.calibR2 != null ? ',  R² = ${(componente.calibR2! * 100).toStringAsFixed(2)} %' : ' (valores de fábrica)'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            for (int i = 0; i < _voltajes.length; i++)
              Padding(

                padding: const EdgeInsets.only(bottom: 10),

                child: Row(

                  children: [

                    SizedBox(
                      width: 28,
                      child: Text('${i + 1}.'),
                    ),

                    Expanded(
                      child: _campo(
                        _voltajes[i],
                        'Voltaje app (V)',
                      ),
                    ),

                    IconButton(
                      tooltip: 'Usar el voltaje actual de la app',
                      icon: const Icon(Icons.sensors),
                      onPressed: () => _usarVoltajeActual(i),
                    ),

                    Expanded(
                      child: _campo(
                        _presiones[i],
                        'Presión sensor (bar)',
                      ),
                    ),

                    SizedBox(
                      width: 48,
                      child: _voltajes.length > _minimo
                          ? IconButton(
                        tooltip: 'Quitar fila',
                        icon: const Icon(Icons.close),
                        onPressed: () => _quitarFila(i),
                      )
                          : null,
                    ),
                  ],
                ),
              ),

            if (_voltajes.length < _maximo)
              TextButton.icon(
                onPressed: _agregarFila,
                icon: const Icon(Icons.add),
                label: const Text('Agregar valor'),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            if (resultado != null)
              Container(

                width: double.infinity,

                margin: const EdgeInsets.only(top: 12),

                padding: const EdgeInsets.all(12),

                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    const Text(
                      'Resultado:  Presión (bar) = A × Voltaje + B',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 6),

                    Text('A = ${resultado.a.toStringAsFixed(4)}'),

                    Text('B = ${resultado.b.toStringAsFixed(4)}'),

                    Text(
                      'Coeficiente de determinación  '
                          'R² = ${(resultado.r2 * 100).toStringAsFixed(2)} %',
                    ),

                    Text(
                      _calidad(resultado.r2),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: resultado.r2 >= 0.90
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),

      actions: [

        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              const _ResultadoCalibracion(
                restablecer: true,
                a: kCalibAFabrica,
                b: kCalibBFabrica,
                r2: null,
                puntos: [],
              ),
            );
          },
          child: const Text('Valores de fábrica'),
        ),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),

        TextButton(
          onPressed: _calcular,
          child: const Text('Calcular'),
        ),

        TextButton(
          onPressed: resultado == null
              ? null
              : () {
            Navigator.pop(
              context,
              _ResultadoCalibracion(
                restablecer: false,
                a: resultado.a,
                b: resultado.b,
                r2: resultado.r2,
                puntos: _puntosValidos,
              ),
            );
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}


// ============================================================
// DIÁLOGO PARA CONFIGURAR UN BLOQUE DE COMPARACIÓN (>= y <)
// ============================================================

class _DialogoUmbral extends StatefulWidget {

  final String titulo;

  // Explicación de cuándo se activa el bloque.
  final String condicion;

  // De dónde viene el valor que se compara.
  final String fuente;

  // Valor actual medido (ya en su unidad final), o '--'.
  final String valorActual;

  // 'bar', 'V' o '' si todavía no hay un bloque AI conectado.
  final String unidad;

  final double? umbralActual;

  const _DialogoUmbral({
    required this.titulo,
    required this.condicion,
    required this.fuente,
    required this.valorActual,
    required this.unidad,
    required this.umbralActual,
  });

  @override
  State<_DialogoUmbral> createState() => _DialogoUmbralState();
}

class _DialogoUmbralState extends State<_DialogoUmbral> {

  late final TextEditingController _controlador;

  String? _error;

  @override
  void initState() {

    super.initState();

    _controlador = TextEditingController(
      text: widget.umbralActual == null
          ? ''
          : _formatoNumero(widget.umbralActual!),
    );
  }

  @override
  void dispose() {

    _controlador.dispose();

    super.dispose();
  }

  void _guardar() {

    final valor = double.tryParse(
      _controlador.text.trim().replaceAll(',', '.'),
    );

    if (valor == null) {

      setState(() {
        _error = 'Ingrese un número válido.';
      });

      return;
    }

    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) {

    return AlertDialog(

      scrollable: true,

      title: Text(widget.titulo),

      content: SizedBox(

        width: 420,

        child: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(widget.condicion),

            const SizedBox(height: 10),

            Text(
              'Fuente: ${widget.fuente}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 4),

            Text('Valor actual: ${widget.valorActual}'),

            const SizedBox(height: 14),

            TextField(
              controller: _controlador,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onSubmitted: (_) => _guardar(),
              decoration: InputDecoration(
                labelText: 'Valor de comparación',
                suffixText: widget.unidad,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),

      actions: [

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),

        TextButton(
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ============================================================
// DIÁLOGO PARA CONFIGURAR LOS BLOQUES TON Y TOF
// ============================================================

class _DialogoTiempoTemporizador extends StatefulWidget {
  final String titulo;
  final String tipo;
  final String condicion;
  final double? tiempoActual;

  const _DialogoTiempoTemporizador({
    required this.titulo,
    required this.tipo,
    required this.condicion,
    required this.tiempoActual,
  });

  @override
  State<_DialogoTiempoTemporizador> createState() =>
      _DialogoTiempoTemporizadorState();
}

class _DialogoTiempoTemporizadorState
    extends State<_DialogoTiempoTemporizador> {
  late final TextEditingController _controlador;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(
      text: widget.tiempoActual == null
          ? '1'
          : _formatoNumero(widget.tiempoActual!),
    );
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _guardar() {
    final valor = double.tryParse(
      _controlador.text.trim().replaceAll(',', '.'),
    );

    if (valor == null || !valor.isFinite) {
      setState(() {
        _error = 'Ingrese un número válido.';
      });
      return;
    }

    if (valor < 1 || valor > 20) {
      setState(() {
        _error = 'El tiempo debe estar entre 1 y 20 segundos.';
      });
      return;
    }

    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.titulo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.condicion),
            const SizedBox(height: 12),
            Text(
              'Tiempo preestablecido (${widget.tipo})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controlador,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              onSubmitted: (_) => _guardar(),
              decoration: InputDecoration(
                labelText: 'Tiempo',
                suffixText: 'segundos',
                helperText: 'Valor permitido: de 1 a 20 segundos',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// Número sin ceros sobrantes: 2.5 -> "2.5", 3.0 -> "3".
String _formatoNumero(double valor) {

  var texto = valor.toStringAsFixed(3);

  if (texto.contains('.')) {

    texto = texto.replaceAll(RegExp(r'0+$'), '');

    texto = texto.replaceAll(RegExp(r'\.$'), '');
  }

  return texto;
}
