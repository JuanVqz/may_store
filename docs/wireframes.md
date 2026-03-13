# MayStore - Wireframes

**Version:** 5.0
**Last Updated:** March 2026

---

## Overview

All user-facing text references I18n locale keys. Wireframes show Spanish (default locale) text.

### Status Flows Reference

**Order Status:**
```
OPEN -> COOKING -> READY -> DELIVERED -> CLOSED
                                      \-> CANCELLED
```

**Item Status:**
```
ORDERING -> COOKING -> READY -> DELIVERED
                    \-> CANCELLED
```

### Key Rules

1. When waiter confirms order -> order becomes **COOKING**, ALL items become **COOKING**
2. Kitchen sees items **already cooking** (no "Start Cooking" button)
3. Kitchen queue shows **oldest orders first**
4. **All roles** (waiter, kitchen, admin) can: MARK READY, CANCEL, and MARK DELIVERED on items
5. **Adding items** to a cooking order: new items go directly to COOKING
6. **All users authenticate** via Account (employee_number + password)
7. **All text from I18n** — no hardcoded strings in views
8. **Role determines default screen**, not permissions (waiter -> tables, kitchen -> queue, admin -> dashboard)

---

## Screen Overview

| # | Screen | Priority | Role |
|---|--------|----------|------|
| 1 | Login | P0 | All |
| 2 | Table Selection | P0 | Waiter |
| 3 | Product Browser | P0 | Waiter |
| 4 | Product Customization | P0 | Waiter |
| 5 | Order Summary | P0 | Waiter |
| 6 | Active Order | P0 | Waiter |
| 7 | Kitchen Queue | P0 | Kitchen |
| 8 | Mixed Item Statuses | P0 | Waiter |
| 9 | Bill & Payment | P0 | Waiter |
| 10 | Split Payment | P0 | Waiter |
| 11 | Order Closed | P0 | Waiter |
| 12 | Order Cancelled | P0 | Waiter |
| 13 | Admin Dashboard | P0 | Admin |
| 14 | Cash Closing (Corte de Caja) | P0 | Admin |

---

## Screen 1: Login

```
+--------------------------------------------------------------------+
|                                                                    |
|                         MayStore                                   |
|                    cafe-delicias.store.com                          |
|                                                                    |
|            +--------------------------------------+                |
|            |  Numero de empleado                  |                |
|            |  +--------------------------------+  |                |
|            |  | EMP-001                        |  |                |
|            |  +--------------------------------+  |                |
|            |                                      |                |
|            |  Contrasena                          |                |
|            |  +--------------------------------+  |                |
|            |  | ******                         |  |                |
|            |  +--------------------------------+  |                |
|            |                                      |                |
|            |  +--------------------------------+  |                |
|            |  |        Iniciar sesion          |  |                |
|            |  +--------------------------------+  |                |
|            +--------------------------------------+                |
|                                                                    |
+--------------------------------------------------------------------+
```

**Auth flow:**
1. Store resolved from subdomain
2. Find `Account` by `employee_number` scoped to store
3. `account.authenticate(params[:password])`
4. Redirect by `user.role`: waiter -> mesas, kitchen -> cocina, admin -> admin dashboard

---

## Screen 2: Table Selection (Dashboard)

```
+--------------------------------------------------------------------+
| MayStore                              Bienvenido, Juan       [Salir] |
+--------------------------------------------------------------------+
|                                                                    |
|  +---------+  +---------+  +---------+  +---------+  +---------+  |
|  | MESA 1  |  | MESA 2  |  | MESA 3  |  | MESA 4  |  | MESA 5  |  |
|  |         |  |  Listo   |  |         |  |Preparando|  |Entregado|  |
|  +---------+  +---------+  +---------+  +---------+  +---------+  |
|                                                                    |
|  +---------+  +---------+  +---------+  +---------+  +---------+  |
|  | MESA 6  |  | MESA 7  |  | MESA 8  |  | MESA 9  |  | MESA 10 |  |
|  |Preparando|  |         |  |         |  |  Listo   |  |         |  |
|  +---------+  +---------+  +---------+  +---------+  +---------+  |
|                                                                    |
|  Leyenda:                                                          |
|  * Preparando (naranja) * Listo (verde) * Entregado (morado)      |
|  * Cerrado (gris)       * Sin orden (neutro)                      |
|                                                                    |
+--------------------------------------------------------------------+
```

---

## Screen 3: Product Browser

```
+--------------------------------------------------------------------+
| < MESA 5                              Orden: CFE2601-001     $0.00 |
+--------------------------------------------------------------------+
|                                                                    |
|  +----------+ +----------+ +----------+ +----------+ +-----------+|
|  | BEBIDAS  | | TIZANAS  | | POSTRES  | | CREPAS   | | ESPECIAL  ||
|  | CALIENTES| |          | |          | |          | |           ||
|  | [ACTIVO] | |          | |          | |          | |           ||
|  +----------+ +----------+ +----------+ +----------+ +-----------+|
|                                                                    |
+--------------------------------------------------------------------+
|                                                                    |
|  +-----------------------------------------------------------+    |
|  |  +-----+                                                  |    |
|  |  | IMG |  ESPRESSO                           .... $25.00 |    |
|  |  |     |  Rico y fuerte shot de espresso                  |    |
|  |  +-----+                                                  |    |
|  +-----------------------------------------------------------+    |
|                                                                    |
|  +-----------------------------------------------------------+    |
|  |  +-----+                                                  |    |
|  |  | IMG |  CREPA DE NUTELLA                   .... $45.00 |    |
|  |  |     |  Crepa con Nutella         [Personalizar]        |    |
|  |  +-----+                                                  |    |
|  +-----------------------------------------------------------+    |
|                                                                    |
|  +-----------------------------------------------------------+    |
|  |  +-----+                                                  |    |
|  |  | IMG |  CAPPUCCINO CARAMEL                .... $45.00  |    |
|  |  |     |  Espresso, leche, caramelo [Personalizar]        |    |
|  |  +-----+                                                  |    |
|  +-----------------------------------------------------------+    |
|                                                                    |
+--------------------------------------------------------------------+
```

---

## Screen 4: Product Customization Modal

```
+--------------------------------------------------------------------+
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |              +----------------------------+                  | |
|  |              |      PRODUCT IMAGE         |                  | |
|  |              +----------------------------+                  | |
|  |                                                              | |
|  |              CREPA DE NUTELLA                 $45.00         | |
|  |              Crepa con Nutella                               | |
|  +--------------------------------------------------------------+ |
|                                                                   |
|  Ingredientes (ajustar porciones)               [Restablecer]     |
|                                                                   |
|  +--------------------------------------------------------------+ |
|  |  Base Crepa        (1/4) (1/2) (3/4) [Normal]        $0.00   | |
|  |  (requerido)                                                 | |
|  +--------------------------------------------------------------+ |
|  +--------------------------------------------------------------+ |
|  |  Nutella            (1/4) (1/2) (3/4) [Normal]        $0.00  | |
|  |  (requerido)                                                 | |
|  +--------------------------------------------------------------+ |
|  +--------------------------------------------------------------+ |
|  |  Crema Batida  (Sin) (1/4) [1/2] (3/4) (Normal)       $0.00  | |
|  +--------------------------------------------------------------+ |
|                                                                   |
|  Extras (agregar mas)                                             |
|                                                                   |
|  +--------------------------------------------------------------+ |
|  |  Rell. Extra Cajeta       [-]  [+]      1x         +$10.00   | |
|  +--------------------------------------------------------------+ |
|  +--------------------------------------------------------------+ |
|  |  Rell. Extra Lechera      [-]  [+]                 +$10.00   | |
|  +--------------------------------------------------------------+ |
|  +--------------------------------------------------------------+ |
|  |  Rell. Extra Rompope      [-]  [+]                 +$10.00   | |
|  +--------------------------------------------------------------+ |
|  +--------------------------------------------------------------+ |
|  |  Extra Helado             [-]  [+]                 +$20.00   | |
|  +--------------------------------------------------------------+ |
|  +--------------------------------------------------------------+ |
|  |  Extra Fresas             [-]  [+]                 +$20.00   | |
|  +--------------------------------------------------------------+ |
|  +--------------------------------------------------------------+ |
|  |  Extra Chocolate          [-]  [+]       2x        +$20.00   | |
|  +--------------------------------------------------------------+ |
|                                                                   |
|  Notas especiales                                                 |
|  +--------------------------------------------------------------+ |
|  |                                                              | |
|  +--------------------------------------------------------------+ |
|                                                                   |
|  +-------------------+    +----------------------------------+    |
|  | Cancelar          |    | Agregar a Orden        $95.00    |    |
|  +-------------------+    +----------------------------------+    |
|                                                                   |
+--------------------------------------------------------------------+
```

### Ingredient Portion Buttons

Discrete buttons in a row. Selected button is highlighted `[x]`, others are `(x)`. Default is `Normal` (1.0).

**Required ingredients** (e.g., Base Crepa, Nutella in "Crepa de Nutella"):
```
  (1/4)  (1/2)  (3/4)  [Normal]
```
No "Sin" button — the ingredient is always present. Labeled `(requerido)`.

**Optional ingredients** (e.g., Crema Batida):
```
  (Sin)  (1/4)  (1/2)  (3/4)  [Normal]
```
Can be set to "Sin" (portion 0.0) to exclude completely.

| Button | portion | I18n key | Spanish |
|--------|---------|----------|---------|
| 1st (optional only) | 0.0 | `portions.none` | Sin |
| 2nd | 0.25 | `portions.quarter` | 1/4 |
| 3rd | 0.5 | `portions.half` | 1/2 |
| 4th | 0.75 | `portions.three_quarters` | 3/4 |
| 5th | 1.0 | `portions.full` | Normal |

### Extras (Add/Remove Counter)

Extras use `[-]` and `[+]` buttons with a quantity indicator. Same extra can be added multiple times.

| State | UI | Records |
|-------|-----|---------|
| Not added | `[-]  [+]` (no quantity shown) | 0 LineItemComponent records |
| Added 1x | `[-]  [+]  1x` | 1 LineItemComponent record |
| Added 2x | `[-]  [+]  2x` | 2 LineItemComponent records |
| Added 3x | `[-]  [+]  3x` | 3 LineItemComponent records |

- `[+]` adds one record (portion 1.0, copies `unit_price_cents` from component)
- `[-]` removes one record (no-op when count is 0)
- Quantity indicator (`1x`, `2x`, etc.) only shown when count > 0
- Price shown is **per unit**. Total reflected in "Agregar a Orden" button.

---

## Screen 5: Order Summary (Before Confirming)

```
+--------------------------------------------------------------------+
| < MESA 5                                Orden: CFE2601-001        |
+--------------------------------------------------------------------+
|                                                                    |
|  Productos de la orden                         [Agregar Productos] |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #1  CREPA DE NUTELLA                                $75.00  | |
|  |      ------------------------------------------------        | |
|  |      Crema Batida: 1/2                                       | |
|  |      + Rell. Extra Cajeta x1                    +$10.00      | |
|  |      + Extra Chocolate x2                       +$20.00      | |
|  |      Estado: Ordenando                  [Editar] [X]        | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #2  OREO COFFEE FRAPPE                             $95.00   | |
|  |      ------------------------------------------------        | |
|  |      Coffee: 1/2                                             | |
|  |      + Extra Fresas x1                          +$20.00      | |
|  |      Estado: Ordenando                  [Editar] [X]        | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #3  CUCURUMBE                                      $99.00   | |
|  |      ------------------------------------------------        | |
|  |      Todos los ingredientes estandar                         | |
|  |      Estado: Ordenando                  [Editar] [X]        | |
|  +--------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  Total (3 productos)                              $269.00   | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |              Confirmar Orden                                 | |
|  |           (Enviar a Cocina)                                  | |
|  +--------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+
```

**When Confirmar Orden is clicked:**
- Order status -> COOKING
- ALL items status -> COOKING (automatic)
- Items appear in kitchen queue immediately

---

## Screen 6: Active Order (COOKING)

```
+--------------------------------------------------------------------+
| < MESAS                             MESA 5 - CFE2601-001          |
+--------------------------------------------------------------------+
|                                                                    |
|  Estado: Preparando                                 14:35         |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #1  CREPA DE NUTELLA                                $75.00  | |
|  |      Crema: 1/2 | + Rell. Extra Cajeta x1                   | |
|  |      + Extra Chocolate x2                                    | |
|  |      Estado: Preparando                                      | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #2  OREO COFFEE FRAPPE                             $95.00   | |
|  |      Coffee: 1/2 | + Extra Fresas x1                        | |
|  |      Estado: Preparando                                      | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #3  CUCURUMBE                                      $99.00   | |
|  |      Estado: Preparando                                      | |
|  +--------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+
|                                                                    |
|  [Agregar Productos]  [Cancelar Orden]  Total: $269.00            |
|                                              [Pedir Cuenta]      |
|                                                                    |
+--------------------------------------------------------------------+
```

---

## Screen 7: Kitchen Queue (Oldest First)

```
+--------------------------------------------------------------------+
| COCINA                                 Bienvenido, Cocina 1 [Salir] |
+--------------------------------------------------------------------+
|                                                                    |
|  Ordenado por: Mas antiguo primero               Cola: 6          |
|                                                                    |
+--------------------------------------------------------------------+
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  MAS ANTIGUO - Esperando 8 min                               | |
|  |  MESA 3 | CFE2601-008 | 14:27 | Maria                       | |
|  +--------------------------------------------------------------+ |
|  |                                                              | |
|  |  #1 AMERICANO                                               | |
|  |      Preparacion estandar                                    | |
|  |      Estado: Preparando                                      | |
|  |  +------------------------------------------------------+   | |
|  |  |            [Listo]           [Cancelar]              |   | |
|  |  +------------------------------------------------------+   | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  Esperando 5 min                                             | |
|  |  MESA 5 | CFE2601-009 | 14:30 | Juan                        | |
|  +--------------------------------------------------------------+ |
|  |                                                              | |
|  |  #1 CREPA DE NUTELLA                                        | |
|  |      Crema: 1/2 *                                           | |
|  |      + Rell. Extra Cajeta x1                                | |
|  |      + Extra Chocolate x2                                   | |
|  |      Estado: Preparando                                      | |
|  |  +------------------------------------------------------+  | |
|  |  |            [Listo]           [Cancelar]              |  | |
|  |  +------------------------------------------------------+  | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  LISTO - Esperando 1 min para recoger                        | |
|  |  MESA 5 | CFE2601-009 | 14:30 | Juan                        | |
|  +--------------------------------------------------------------+ |
|  |                                                              | |
|  |  #3 CUCURUMBE                                               | |
|  |      Preparacion estandar                                    | |
|  |      Estado: Listo                                           | |
|  |      +--------------------------------------------------+   | |
|  |      |  [Cancelar]  (listo, esperando mesero)           |   | |
|  |      +--------------------------------------------------+   | |
|  +--------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+
```

### Kitchen Display Rules

1. **Oldest first** - items waiting longest at top
2. **Items already COOKING** - no "Start Cooking" button
3. **Two actions only:** `[Listo]` -> READY, `[Cancelar]` -> CANCELLED
4. **Show wait time** per item
5. **No prices** - kitchen doesn't need pricing info
6. **Modified ingredients** shown with * marker
7. **Extras** shown with + prefix and quantity: `+ Extra Chocolate x2`
8. **Auto-refreshes** via Turbo Streams

---

## Screen 8: Order with Mixed Item Statuses

```
+--------------------------------------------------------------------+
| < MESAS                             MESA 5 - CFE2601-009          |
+--------------------------------------------------------------------+
|                                                                    |
|  Estado: Preparando                                 14:30         |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #1  CREPA DE NUTELLA                                $75.00  | |
|  |      Estado: Listo                    [Marcar Entregado]     | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #2  OREO COFFEE FRAPPE                             $95.00   | |
|  |      Estado: Preparando                                      | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #3  CUCURUMBE                                      $99.00   | |
|  |      Estado: Entregado                                       | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  #4  ESPRESSO                                       $25.00   | |
|  |      Estado: Cancelado                                       | |
|  +--------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+
|                                                                    |
|  [Agregar Productos]  [Cancelar Orden]  Total: $269.00            |
|                                              [Pedir Cuenta]      |
|                                                                    |
+--------------------------------------------------------------------+
```

**Order Status Logic:**

| Item Statuses | Order Status |
|---------------|--------------|
| Any COOKING or ORDERING | Preparando |
| All READY/CANCELLED/DELIVERED | Listo |
| All DELIVERED/CANCELLED | Entregado |

---

## Screen 9: Bill & Payment (Full Payment)

```
+--------------------------------------------------------------------+
| < MESA 5                                    CFE2601-009            |
+--------------------------------------------------------------------+
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |                                                              | |
|  |                        CUENTA                                | |
|  |                                                              | |
|  |  Mesa: 5                                                     | |
|  |  Orden: CFE2601-009                                          | |
|  |  Fecha: 12 de marzo de 2026                                  | |
|  |  Mesero: Juan                                                | |
|  |                                                              | |
|  |  ---------------------------------------------------------- | |
|  |                                                              | |
|  |  #1  Crepa de Nutella                                $45.00 | |
|  |      Crema: 1/2                                             | |
|  |      + Rell. Extra Cajeta x1                      +$10.00   | |
|  |      + Extra Chocolate x2                         +$20.00   | |
|  |                                                              | |
|  |  #2  Oreo Coffee Frappe                             $75.00  | |
|  |      Coffee: 1/2                                            | |
|  |      + Extra Fresas x1                            +$20.00   | |
|  |                                                              | |
|  |  #3  Cucurumbe                                      $99.00  | |
|  |                                                              | |
|  |  #4  Espresso                       CANCELADO       ---     | |
|  |                                                              | |
|  |  ---------------------------------------------------------- | |
|  |                                                              | |
|  |  TOTAL                                             $269.00  | |
|  |                                                              | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  Metodo de pago                                                    |
|                                                                    |
|  +----------------+ +----------------+ +----------------+         |
|  |   Efectivo     | |   Tarjeta      | |  Mercado Pago  |         |
|  +----------------+ +----------------+ +----------------+         |
|                                                                    |
|  +--------------+  +------------------+  +-------------------+    |
|  | Imprimir     |  | Pago Dividido    |  | Confirmar Pago    |    |
|  +--------------+  +------------------+  +-------------------+    |
|                                                                    |
+--------------------------------------------------------------------+
```

---

## Screen 10: Split Payment

```
+--------------------------------------------------------------------+
| < CUENTA                                     CFE2601-009           |
+--------------------------------------------------------------------+
|                                                                    |
|  PAGO DIVIDIDO                                                     |
|                                                                    |
|  Total de la orden:                               $269.00         |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  Pagos agregados                                             | |
|  +--------------------------------------------------------------+ |
|  |                                                              | |
|  |  #1  Efectivo                                      $150.00   | |
|  |                                           [Eliminar]         | |
|  |                                                              | |
|  |  #2  Tarjeta                                       $100.00   | |
|  |                                           [Eliminar]         | |
|  |                                                              | |
|  +--------------------------------------------------------------+ |
|  |  Pagado:                                           $250.00   | |
|  |  Restante:                                          $19.00   | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  Agregar Pago                                                      |
|                                                                    |
|  Metodo de pago:                                                   |
|  +----------------+ +----------------+ +----------------+         |
|  |   Efectivo     | |  [Tarjeta]     | | Mercado Pago   |         |
|  +----------------+ +----------------+ +----------------+         |
|                                                                    |
|  Monto:                                                            |
|  +--------------------------------------------------------------+ |
|  | $19.00                                              [MAX]    | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |                    Agregar Pago                               | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |        Confirmar Todos los Pagos ($269.00)                   | |
|  +--------------------------------------------------------------+ |
|  (Habilitado solo cuando el restante es $0.00)                     |
|                                                                    |
+--------------------------------------------------------------------+
```

---

## Screen 11: Order Closed

```
+--------------------------------------------------------------------+
|                                                                    |
|                       ORDEN CERRADA                                |
|                                                                    |
|                    Orden: CFE2601-009                               |
|                    Total: $269.00                                  |
|                    Mesa 5 ahora esta disponible                    |
|                                                                    |
|              +----------------------------+                        |
|              |       Volver a Mesas        |                        |
|              +----------------------------+                        |
|                                                                    |
+--------------------------------------------------------------------+
```

---

## Screen 12: Order Cancelled

```
+--------------------------------------------------------------------+
|                                                                    |
|                     ORDEN CANCELADA                                |
|                                                                    |
|                    Orden: CFE2601-009                               |
|                    Mesa 5 ahora esta disponible                    |
|                                                                    |
|              +----------------------------+                        |
|              |       Volver a Mesas        |                        |
|              +----------------------------+                        |
|                                                                    |
+--------------------------------------------------------------------+
```

---

## Screen 13: Admin Dashboard

```
+--------------------------------------------------------------------+
| MayStore ADMIN                   Bienvenido, Admin Principal [Salir] |
+--------------------------------------------------------------------+
|                                                                    |
|  PANEL DE ADMINISTRACION                                           |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  RESUMEN DEL DIA - 12 de marzo de 2026                      | |
|  |                                                              | |
|  |  Ordenes cerradas:          24                               | |
|  |  Ordenes canceladas:        2                                | |
|  |  Total del dia:             $6,240.00                        | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  POR METODO DE PAGO                                          | |
|  |                                                              | |
|  |  Efectivo:                  $3,120.00                        | |
|  |  Tarjeta:                   $2,100.00                        | |
|  |  Mercado Pago:              $780.00                          | |
|  |  Transferencia:             $240.00                          | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |            REALIZAR CORTE DE CAJA                            | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  CORTES RECIENTES                                            | |
|  |                                                              | |
|  |  11 mar 2026  06:00-22:00  Admin 1  Cerrado   Dif: -$50.00  | |
|  |  10 mar 2026  06:00-22:00  Admin 1  Cerrado   Dif: +$20.00  | |
|  |  09 mar 2026  06:00-22:00  Admin 1  Cerrado   Dif: $0.00    | |
|  +--------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+
```

---

## Screen 14: Cash Closing (Corte de Caja)

```
+--------------------------------------------------------------------+
| < ADMIN                                    CORTE DE CAJA           |
+--------------------------------------------------------------------+
|                                                                    |
|  Periodo: 12 mar 2026  06:00  -  12 mar 2026  22:00              |
|                                                                    |
|  Realizado por: Admin Principal                                    |
|                                                                    |
+--------------------------------------------------------------------+
|                                                                    |
|  +--------------------------------------------------------------+ |
|  | Metodo de pago      | Esperado    | Real        | Diferencia | |
|  |--------------------------------------------------------------|  |
|  | Efectivo            |  $3,120.00  |  $3,070.00  |   -$50.00  | |
|  | Tarjeta             |  $2,100.00  |  $2,100.00  |     $0.00  | |
|  | Mercado Pago        |    $780.00  |    $780.00  |     $0.00  | |
|  | Transferencia       |    $240.00  |    $240.00  |     $0.00  | |
|  |--------------------------------------------------------------|  |
|  | TOTAL               |  $6,240.00  |  $6,190.00  |   -$50.00  | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  Notas                                                             |
|  +--------------------------------------------------------------+ |
|  | Faltaron $50 en efectivo, posible error en cambio de mesa 8  | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |               CERRAR CORTE DE CAJA                           | |
|  +--------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+
```

### Cash Closing Flow

1. Admin clicks "Realizar Corte de Caja"
2. System creates `CashClosing` with `status: :open`
3. System calls `calculate_expected!` — sums payments from closed orders in period
4. Admin enters `actual_cents` for each payment method (physically counted)
5. System auto-calculates `difference_cents = actual - expected`
6. Admin adds optional notes
7. Admin clicks "Cerrar Corte de Caja" -> `status: :closed`

---

## Summary: Status Transitions

### Order Status Flow

```
OPEN -> COOKING -> READY -> DELIVERED -> CLOSED
                                      \-> CANCELLED
```

| Status | Spanish | When |
|--------|---------|------|
| open | Abierto | Waiter building order |
| cooking | Preparando | Waiter confirmed, items in kitchen |
| ready | Listo | All items ready or cancelled |
| delivered | Entregado | All items delivered or cancelled |
| closed | Cerrado | Payment(s) recorded |
| cancelled | Cancelado | Order cancelled |

### Item Status Flow

```
ORDERING -> COOKING -> READY -> DELIVERED
                    \-> CANCELLED
```

| Status | Spanish | When |
|--------|---------|------|
| ordering | Ordenando | Item in order, not confirmed |
| cooking | Preparando | In kitchen |
| ready | Listo | Kitchen finished |
| delivered | Entregado | Delivered to table |
| cancelled | Cancelado | Removed from order |

### Item Actions (All Roles)

All roles (waiter, kitchen, admin) can perform these actions. Role determines **default screen**, not permissions.

| Item Status | Available Actions |
|-------------|-------------------|
| ORDERING | Editar, Eliminar |
| COOKING | Listo, Cancelar |
| READY | Marcar Entregado, Cancelar |
| DELIVERED | (sin accion) |
| CANCELLED | (sin accion) |

### Order-Level Actions

| Order Status | Available Actions |
|--------------|-------------------|
| OPEN | Confirmar, Agregar productos |
| COOKING | Agregar productos, Cancelar orden, Pedir cuenta |
| READY | Agregar productos, Cancelar orden, Pedir cuenta |
| DELIVERED | Pedir cuenta |
| CLOSED | (sin accion) |
| CANCELLED | (sin accion) |
