# Port de CareerMP 0.0.37 a BeamNG.drive 0.40.6

## Estado
Base: CareerMP v0.0.37 (StanleyDudek), verificado por su autor solo en BeamNG 0.38.5.
Objetivo: BeamNG.drive 0.40.6, BeamMP actual.

## Qué hay en el repo
- `client/` : el mod cliente (se empaqueta como `Resources/Client/CareerMP.zip`). Solo las extensiones propias de CareerMP, **sin** los archivos que reemplazaban código del juego.
- `server/CareerMP/` : plugin de servidor BeamMP. Auto-update desactivado por defecto (bajaba el CareerMP original y pisaba el port).
- `reference/careermp-0.0.37-overrides/` : los 10 archivos del juego que CareerMP 0.0.37 reemplazaba, guardados solo para consulta. No se empaquetan.
- `tools/build.py` : genera `dist/Resources/` para copiar a la raíz del servidor.

## Análisis de los overrides (CareerMP 0.0.37 vs vanilla 0.40.6)
| Archivo | Líneas distintas | Referencias a MP | Plan |
|---|---|---|---|
| career/modules/painting.lua | 44 | 0 | descartar, verificar en juego |
| career/modules/computer.lua | 45 | 0 | descartar, verificar en juego |
| career/modules/insurance/insurance.lua | 3643 | 0 | descartar; revisar si los bugfixes de seguro siguen haciendo falta |
| career/modules/insurance/history.lua | 12 | 0 | descartar, verificar en juego |
| career/modules/tuning.lua | 61 | 0 | descartar, verificar en juego |
| career/modules/inventory.lua | 295 | 0 | revisar: posible lógica de spawn/estado de vehículos |
| career/modules/partShopping.lua | 269 | 0 | revisar |
| career/modules/playerDriving.lua | 258 | 5 | **portar** como hook |
| gameplay/walk.lua | 519 | 1 | **portar** como hook |
| gameplay/drag/display.lua | 1771 | 20 | **portar** (sync del árbol de drag) |

"Referencias a MP" cuenta líneas con MP/MPVehicleGE/MPConfig/careerMP/isOwn; cero no garantiza que el cambio sea irrelevante para multijugador.

## Próximos pasos
1. Probar el cliente sin overrides en 0.40.6 + servidor local y leer `beamng.log`.
2. Portar los cambios MP de playerDriving, walk y drag/display envolviendo funciones del módulo vanilla en vez de reemplazar el archivo.
3. Revisar inventory y partShopping contra lo que falle en la prueba.
