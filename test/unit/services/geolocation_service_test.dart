// File: test/unit/services/geolocation_service_test.dart
//
// GeolocationService — test onesti
// ================================
//
// Il servizio chiama gli statici di Geolocator/geocoding direttamente, che
// in ambiente test non sono mockabili senza refactor (wrapper iniettabile —
// segnalato in tech-debt). Questi test coprono solo ciò che è realmente
// esercitabile: i percorsi di fallback e la gestione degli errori quando la
// piattaforma non è disponibile (MissingPluginException catturata).
//
// La versione precedente aveva 29 test ma quasi tutti chiamavano il servizio
// reale e assertavano isA<String>/isNotEmpty: teatro, non copertura.

import 'package:flutter_test/flutter_test.dart';

import 'package:wavnote/services/location/geolocation_service.dart';
import 'package:wavnote/core/errors/exceptions.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await TestHelpers.initializeTestEnvironment();
  });

  group('GeolocationService — fallback senza piattaforma', () {
    late GeolocationService service;

    setUp(() {
      service = GeolocationService();
    });

    test(
      'getRecordingLocationName ripiega su "Recording g/m/aaaa" '
      'quando la geolocalizzazione non è disponibile',
      () async {
        final result = await service.getRecordingLocationName();

        expect(result, matches(r'^Recording \d{1,2}/\d{1,2}/\d{4}$'));
      },
    );

    test(
      'getCurrentAddress rilancia SystemException quando la piattaforma '
      'non è disponibile (il fallback è responsabilità del chiamante)',
      () async {
        await expectLater(
          service.getCurrentAddress(),
          throwsA(isA<SystemException>()),
        );
      },
    );

    test(
      'hasLocationPermission gestisce la piattaforma assente '
      'restituendo false senza lanciare',
      () async {
        final result = await service.hasLocationPermission();

        expect(result, isFalse);
      },
    );

    test(
      'requestLocationPermission gestisce la piattaforma assente '
      'restituendo false senza lanciare',
      () async {
        final result = await service.requestLocationPermission();

        expect(result, isFalse);
      },
    );

    test(
      'chiamate concorrenti a getRecordingLocationName non interferiscono',
      () async {
        final results = await Future.wait([
          service.getRecordingLocationName(),
          service.getRecordingLocationName(),
          service.getRecordingLocationName(),
        ]);

        for (final r in results) {
          expect(r, matches(r'^Recording \d{1,2}/\d{1,2}/\d{4}$'));
        }
      },
    );
  });
}
