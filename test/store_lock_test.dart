import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/services/commerce_persistence.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/services/store_lock.dart';
import 'package:b_plus_commerce/app/utils/user_facing_errors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mensaje crudo tal cual lo reporta Windows al fallar el lock de Hive.
const String _rawWindowsLockError =
    "PathAccessException: lock failed, path = "
    "'C:\\Users\\marco\\Documents\\b_plus_commerce.lock' "
    "(OS Error: El proceso no tiene acceso al archivo porque otro proceso "
    "tiene bloqueada una parte del archivo., errno = 33)";

const _zeroBackoff = <Duration>[Duration.zero, Duration.zero, Duration.zero];

void main() {
  group('classifyStorageError', () {
    test('reconoce un lock de Windows (errno 33) como otra instancia', () {
      expect(
        classifyStorageError(Exception(_rawWindowsLockError)),
        StoreAccessIssue.anotherInstance,
      );
    });

    test('reconoce un error de permisos', () {
      expect(
        classifyStorageError(Exception('OS Error: Access is denied')),
        StoreAccessIssue.permissionDenied,
      );
    });

    test('un error cualquiera queda como desconocido', () {
      expect(
        classifyStorageError(Exception('disk full')),
        StoreAccessIssue.unknown,
      );
    });
  });

  group('runWithStorageRetry', () {
    test('reintenta y termina funcionando si el lock se libera', () async {
      var attempts = 0;
      final result = await runWithStorageRetry<String>(
        () async {
          attempts++;
          if (attempts < 3) {
            throw Exception(_rawWindowsLockError);
          }
          return 'ok';
        },
        backoff: _zeroBackoff,
      );

      expect(result, 'ok');
      expect(attempts, 3);
    });

    test('un lock que sigue tomado termina como otra instancia', () async {
      var attempts = 0;
      await expectLater(
        runWithStorageRetry<void>(
          () async {
            attempts++;
            throw Exception(_rawWindowsLockError);
          },
          backoff: _zeroBackoff,
        ),
        throwsA(
          isA<StoreAccessException>().having(
            (e) => e.issue,
            'issue',
            StoreAccessIssue.anotherInstance,
          ),
        ),
      );
      expect(attempts, 4);
    });

    test('un error de permisos no se reintenta', () async {
      var attempts = 0;
      await expectLater(
        runWithStorageRetry<void>(
          () async {
            attempts++;
            throw Exception('Access is denied');
          },
          backoff: _zeroBackoff,
        ),
        throwsA(
          isA<StoreAccessException>().having(
            (e) => e.issue,
            'issue',
            StoreAccessIssue.permissionDenied,
          ),
        ),
      );
      expect(attempts, 1);
    });
  });

  group('mensajes para el usuario', () {
    test('otra instancia tiene un mensaje humano y claro', () {
      final message = StoreAccessException(
        StoreAccessIssue.anotherInstance,
        Exception(_rawWindowsLockError),
      ).userMessage;

      expect(message, contains('otra ventana'));
      expect(message, contains('Reintentar'));
      expect(message.toLowerCase(), isNot(contains('pathaccessexception')));
      expect(message.toLowerCase(), isNot(contains('errno')));
    });

    test('userFacingErrorMessage nunca filtra el PathAccessException crudo', () {
      final message = userFacingErrorMessage(Exception(_rawWindowsLockError));

      expect(message.toLowerCase(), isNot(contains('pathaccessexception')));
      expect(message.toLowerCase(), isNot(contains('errno')));
      expect(message, isNot(contains(r'.lock')));
      expect(message, contains('otra ventana'));
    });

    test('userFacingErrorMessage usa el mensaje de StoreAccessException', () {
      final exception = StoreAccessException(
        StoreAccessIssue.temporary,
        Exception('algo'),
      );
      expect(
        userFacingErrorMessage(exception),
        exception.userMessage,
      );
      expect(userFacingErrorMessage(exception), contains('Reintentar'));
    });
  });

  group('CommerceStore con lock', () {
    const newProduct = Product(
      id: 'p-lock',
      name: 'Producto de prueba',
      stockUnits: 5,
      minStockUnits: 1,
      costPesos: 100,
      pricePesos: 200,
    );

    test(
      'un lock al guardar no pierde datos y muestra mensaje humano',
      () async {
        final persistence = _FlakyLockPersistence(failuresBeforeSuccess: 99);
        final store = CommerceStore.withPersistenceForTest(
          persistence,
          seedDemoData: true,
        );
        final initialProducts = store.products.length;

        await expectLater(
          store.addProduct(newProduct),
          throwsA(isA<StoreAccessException>()),
        );

        // Los datos previos siguen intactos (rollback en memoria).
        expect(store.products.length, initialProducts);
        expect(store.productById('p-lock'), isNull);
        // El mensaje es humano, sin texto técnico.
        expect(store.lastError, isNotNull);
        expect(store.lastError, contains('otra ventana'));
        expect(
          store.lastError!.toLowerCase(),
          isNot(contains('pathaccessexception')),
        );
      },
    );

    test('Reintentar vuelve a guardar bien cuando se libera el lock', () async {
      final persistence = _FlakyLockPersistence(failuresBeforeSuccess: 1);
      final store = CommerceStore.withPersistenceForTest(
        persistence,
        seedDemoData: true,
      );

      // Primer guardado: el lock está tomado -> falla y deja el error.
      await expectLater(
        store.addProduct(newProduct),
        throwsA(isA<StoreAccessException>()),
      );
      expect(store.lastError, isNotNull);

      // Se cerró la otra ventana: Reintentar guarda y limpia el error.
      await store.retrySave();

      expect(store.lastError, isNull);
      expect(persistence.successfulSaves, 1);
    });
  });
}

/// Persistencia que simula un lock tomado durante los primeros guardados.
class _FlakyLockPersistence extends CommercePersistence {
  _FlakyLockPersistence({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int saveCalls = 0;
  int successfulSaves = 0;

  @override
  Future<void> save(Map<String, dynamic> json) async {
    saveCalls++;
    if (saveCalls <= failuresBeforeSuccess) {
      throw StoreAccessException(
        StoreAccessIssue.anotherInstance,
        Exception(_rawWindowsLockError),
      );
    }
    successfulSaves++;
  }
}
