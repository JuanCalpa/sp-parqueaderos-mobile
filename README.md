# mobile-parking-sp

App móvil de **SP Parqueaderos**, hecha en Flutter, para el operador y el cajero. Usa las mismas cuentas, roles y datos que la web, y se conecta al backend solo a través del **API Gateway**.

El estilo visual sigue los diseños de `SpParqueaderosMobileDesigns/` (sistema *Precision Enterprise Parking System*):
- rojo carmesí para la marca y las acciones principales;
- verde para dinero y espacios libres, azul para categorías y ámbar para mensualidades;
- Plus Jakarta Sans para la interfaz y JetBrains Mono para placas, códigos y dinero.

## Pantallas (fase 1)

| Pantalla | Qué hace | API |
| --- | --- | --- |
| Iniciar sesión | Login con el mismo usuario de la web; el token se guarda cifrado. | `tenant /auth/login`, `/auth/me` |
| Crear cuenta | Crea el usuario y su parqueadero (queda como propietario). | `tenant /auth/register` |
| Elegir parqueadero | Solo aparece si el usuario pertenece a varios parqueaderos. | — |
| Inicio | Ocupación, ingresos de hoy, movimientos, mensualidades, mapa de espacios y vehículos adentro. | `reporting /dashboards/current`, `operation /tickets/*`, `/resources/board`, `payment /payments/today` |
| Entrada | Tipo de vehículo y placa; detecta la mensualidad. Asigna espacio, llave o hasta 2 cascos por moto, y envía el ticket por WhatsApp. | `operation /tickets/check-in` |
| Salidas | Busca la placa, muestra el tiempo, los casilleros por entregar y el desglose del cobro, y cobra en efectivo (con cambio) o en línea. | `pricing /pricing/calculate`, `operation /tickets/{uuid}/check-out` |
| Mensual | Consulta de mensualidades: vigentes, por vencer, vencidas y búsqueda. | `operation /monthly-subscriptions` |
| Caja | Apertura con base, recaudo del turno, historial de cobros y cierre con arqueo. | `payment /cash-sessions/*` |

## Estructura

```text
lib/
  main.dart / app.dart        arranque, rutas (go_router) y protección por sesión
  core/
    config/env.dart           URL del API Gateway (--dart-define)
    theme/                    colores, tipografías y tema (tokens de DESIGN.md)
    api/                      cliente HTTP con token y X-Tenant-Id, y errores legibles
    auth/                     sesión (flutter_secure_storage)
    models/                   espejo de los DTOs del backend
    utils/format.dart         dinero, placas, horas y tipos de vehículo
    widgets/                  tarjetas, placa, botones, KPIs, chips...
  features/                   una carpeta por pantalla
```

## Cómo correrla

1. Instala Flutter (canal estable) y Android Studio con un emulador. Luego ejecuta `flutter doctor` y verifica que todo salga en verde.
2. Genera las carpetas de plataforma. Solo se hace una vez; no sobrescribe `lib/` ni `pubspec.yaml`:
   ```bash
   flutter create . --org com.sp.parking --project-name mobile_parking_sp --platforms android,ios
   ```
3. Permite HTTP sin cifrar en desarrollo, porque el gateway local no tiene HTTPS. En `android/app/src/main/AndroidManifest.xml`, dentro de `<application ...>`, agrega:
   ```xml
   android:usesCleartextTraffic="true"
   ```
   En producción el gateway va con HTTPS y esta línea se quita.
4. Levanta el backend con `start-local.ps1` desde la raíz del workspace. Eso incluye el gateway en el puerto 8090.
5. Instala las dependencias y corre la app:
   ```bash
   flutter pub get
   flutter run                                                    # emulador Android (usa 10.0.2.2:8090)
   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8090 # celular físico: IP de tu PC
   ```

### Celular por Wi-Fi, sin cable

1. Copia `config/local.example.json` como `config/local.json` y pon la IP de tu PC. Ese archivo no se sube a git porque cada desarrollador tiene una IP distinta.
2. Compila con:
   ```bash
   flutter run --dart-define-from-file=config/local.json
   ```
3. Abre el puerto 8090 en el firewall de Windows. Solo se hace una vez, en PowerShell como administrador:
   ```powershell
   New-NetFirewallRule -DisplayName "SP Parqueaderos API Gateway 8090" -Direction Inbound -Protocol TCP -LocalPort 8090 -Action Allow -Profile Any -RemoteAddress LocalSubnet
   ```

El PC y el celular deben estar en la misma red Wi-Fi. Si el router le asigna otra IP al PC, actualiza `config/local.json` y vuelve a compilar.

Para probar, usa el usuario demo: `admin@spparqueaderos.com` / `admin123`.

## Pendiente (siguientes fases)

- Impresión del ticket en impresora térmica Bluetooth (ESC/POS de 58 u 80 mm).
- Crear, renovar y cancelar mensualidades desde la app.
- Historial de tickets.
- Escanear la placa con la cámara.
