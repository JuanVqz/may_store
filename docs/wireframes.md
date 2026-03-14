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
5. **Adding items** to a cooking/ready/delivered order: new items go directly to COOKING, order transitions (back) to COOKING
6. **All users authenticate** via Account (employee_number + password)
7. **All text from I18n** — no hardcoded strings in views
8. **Role determines default screen**, not permissions (waiter -> home, kitchen -> queue, admin -> dashboard)

---

## Screen Overview

| # | Screen | Priority | Role |
|---|--------|----------|------|
| 1 | Login | P0 | All |
| 1b | Home | P0 | Waiter |
| 1c | Takeouts | P0 | Waiter |
| 2 | Table Selection | P0 | Waiter |
| 3 | Order Page (Single-Page) | P0 | Waiter |
| 4 | Inline Product Customization | P0 | Waiter |
| 5 | (Merged into Screen 3) | — | — |
| 6 | (Merged into Screen 3) | — | — |
| 7 | Kitchen Queue | P0 | Kitchen |
| 8 | (Merged into Screen 3) | — | — |
| 9 | Bill & Payment | P0 | Waiter |
| 10 | Split Payment | P0 | Waiter |
| 11 | Order Closed | P0 | Waiter |
| 12 | Order Cancelled | P0 | Waiter |
| 13 | Admin Dashboard | P0 | Admin |
| 14 | Cash Closing (Corte de Caja) | P0 | Admin |

**Note:** Screens 3, 5, 6, and 8 are now a single unified order page with two panels: a product browser (left/top) and an order sidebar (right/bottom). Desktop shows side-by-side; mobile stacks products then order.

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
4. Redirect by `user.role`: waiter -> `/` (home), kitchen -> cocina, admin -> admin dashboard

---

## Screen 1b: Home (Waiter Landing)

After login, waiters land on the home screen at `/` (root). Two large square buttons navigate to table orders or takeout orders.

```
+--------------------------------------------------------------------+
| MayStore                              Bienvenido, Juan       [Salir] |
+--------------------------------------------------------------------+
|                                                                    |
|           +-------------------+  +-------------------+             |
|           |                   |  |                   |             |
|           |     🍽️ Mesas      |  |  🛍️ Para Llevar   |             |
|           |                   |  |                   |             |
|           +-------------------+  +-------------------+             |
|                                                                    |
+--------------------------------------------------------------------+
```

- **Mesas** links to Screen 2 (Table Selection)
- **Para Llevar** links to Screen 1c (Takeouts)

---

## Screen 1c: Takeouts (Para Llevar)

List of active takeout orders (non-closed, non-cancelled). Each row shows order code, status, time, and total. The "+ Nueva Orden" button creates a new takeout order (no spot assigned).

```
+--------------------------------------------------------------------+
| MayStore                              Bienvenido, Juan       [Salir] |
+--------------------------------------------------------------------+
|                                                                    |
|  Para Llevar                              [+ Nueva Orden]          |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  | CFE2603-002    Abierto              14:35    $95.00           | |
|  +--------------------------------------------------------------+ |
|  | CFE2603-005    Preparando           14:20    $120.00          | |
|  +--------------------------------------------------------------+ |
|  | CFE2603-008    Listo                14:10    $45.00           | |
|  +--------------------------------------------------------------+ |
|                                                                    |
+--------------------------------------------------------------------+
```

- Clicking a row opens Screen 3 (Order Page) for that takeout order
- "+ Nueva Orden" creates an order with no spot and redirects to Screen 3

---

## Screen 2: Table Selection

Accessed from Home (Screen 1b) via the "Mesas" button.

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

## Screen 3: Order Page (Single-Page, Two Panels)

The order page is a unified single-page layout with two panels:
- **Product browser** (left on desktop, top on mobile): category tabs + product cards
- **Order sidebar** (right on desktop, bottom on mobile): order header, line items, actions

The product browser is **always visible** for all order statuses (open, cooking, ready, delivered). There is no "Agregar Productos" toggle button.

### Desktop Layout (side-by-side)

```
+-------------------------------+-----------------------------------+
|  PRODUCT BROWSER              |  ORDER SIDEBAR                    |
|                               |                                   |
|  +--------+ +--------+ +---+ |  <- Atras   Mesa 5                |
|  |BEBIDAS | |TIZANAS | |...| |  CFE2601-001        [Preparando]  |
|  |CALIENTE| |        | |   | |                                   |
|  |[ACTIVO]| |        | |   | |  Productos de la orden             |
|  +--------+ +--------+ +---+ |                                   |
|  (category tabs, Turbo Frame) |  +-------------------------------+|
|                               |  | #1 CREPA DE NUTELLA    $75.00 ||
|  +---------------------------+|  |    Crema: 1/2                  ||
|  | +-----+                   ||  |    + Rell. Extra Cajeta x1     ||
|  | | IMG | ESPRESSO    $25.00||  |    Estado: Preparando          ||
|  | |     | Rico y fuerte     ||  |    [Listo] [Cancelar]          ||
|  | +-----+                   ||  +-------------------------------+|
|  | [Agregar a Orden]         ||                                   |
|  +---------------------------+|  +-------------------------------+|
|                               |  | #2 ESPRESSO            $25.00 ||
|  +---------------------------+|  |    Estado: Listo               ||
|  | +-----+                   ||  |    [Marcar Entregado]          ||
|  | | IMG | CREPA DE    $45.00||  +-------------------------------+|
|  | |     | NUTELLA           ||                                   |
|  | +-----+ Crepa con Nutella ||  +-------------------------------+|
|  | [Agregar a Orden]         ||  | #3 CUCURUMBE           $99.00 ||
|  | [Personalizar]            ||  |    Estado: Entregado           ||
|  +---------------------------+|  +-------------------------------+|
|                               |                                   |
|  +---------------------------+|  +-------------------------------+|
|  | +-----+                   ||  | #4 CAPPUCCINO          $45.00 ||
|  | | IMG | CAPPUCCINO  $45.00||  |    Estado: Ordenando           ||
|  | |     | CARAMEL           ||  |    [Eliminar]                  ||
|  | +-----+ Espresso, leche  ||  +-------------------------------+|
|  | [Agregar a Orden]         ||                                   |
|  | [Personalizar]            ||  Total (4 productos)     $244.00 |
|  +---------------------------+|                                   |
|                               |  [Confirmar Orden]                |
|                               |  (or [Cancelar Orden]             |
|                               |   [Pedir Cuenta] if cooking+)    |
+-------------------------------+-----------------------------------+
```

### Mobile Layout (stacked)

On mobile, products stack on top, order sidebar below. Same content, vertical flow.

### Product Card Actions

Each product card has:
- **"Agregar a Orden"** green button — quick add with default ingredients
- **"Personalizar"** button — expands inline customization (see Screen 4) under the product card via Stimulus controller

### Order Sidebar Header

The sidebar header contains order info (no separate navbar):
- **Spot name · Order code** (e.g., "Mesa 5 · CFE2601-001") — for takeout orders with no spot, shows "Para Llevar · CFE2603-002"
- **Status badge** (e.g., [Preparando])

### Item Actions by Status

| Item Status | Actions Shown |
|-------------|---------------|
| ORDERING | [Eliminar] (hard delete, kitchen never saw it) |
| COOKING | [Listo] [Cancelar] (cancel requires confirmation dialog, soft cancel → status cancelled) |
| READY | [Marcar Entregado] |
| DELIVERED | (no action buttons) |
| CANCELLED | (no action buttons) |

### Order-Level Actions

Shown at the bottom of the order sidebar:

| Order Status | Actions |
|--------------|---------|
| OPEN | [Confirmar Orden] |
| COOKING | [Cancelar Orden] [Pedir Cuenta] |
| READY | [Cancelar Orden] [Pedir Cuenta] |
| DELIVERED | [Pedir Cuenta] |

### Status Transition on Adding Items

Adding an item to a **READY** or **DELIVERED** order automatically transitions the order back to **COOKING**. New items go directly to COOKING status.

### Flash Messages

Flash messages appear fixed-position in the top-right corner.

### Turbo Integration

- Category tabs load via **Turbo Frame**
- Add/remove items use **Turbo Stream** responses
- Real-time updates via ActionCable

---

## Screen 4: Inline Product Customization

Customization expands **inline** under the product card in the product browser panel via a Stimulus controller. It is not a modal or separate page.

```
+--------------------------------------------------------------------+
|  PRODUCT CARD (expanded)                                           |
|  +--------------------------------------------------------------+ |
|  |  +-----+                                                     | |
|  |  | IMG |  CREPA DE NUTELLA                        $45.00     | |
|  |  |     |  Crepa con Nutella                                  | |
|  |  +-----+                                                     | |
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

## Screen 5: (Merged into Screen 3)

See Screen 3 — the order sidebar shows the order summary for all statuses.

---

## Screen 6: (Merged into Screen 3)

See Screen 3 — the same single-page layout is used for open, cooking, ready, and delivered orders. Item action buttons change based on item status (see Screen 3 item actions table).

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
9. **Takeout orders** show "PARA LLEVAR" instead of a table name (e.g., "PARA LLEVAR | CFE2603-002 | 14:35 | Juan")

---

## Screen 8: (Merged into Screen 3)

See Screen 3 — mixed item statuses are handled in the same single-page layout. Each item shows its own status badge and appropriate action buttons. The product browser remains visible alongside the order sidebar.

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
|  |  Lugar: Mesa 5                                                | |
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
| delivered | Entregado | Delivered to spot |
| cancelled | Cancelado | Removed from order |

### Item Actions (All Roles)

All roles (waiter, kitchen, admin) can perform these actions. Role determines **default screen**, not permissions.

| Item Status | Available Actions |
|-------------|-------------------|
| ORDERING | Eliminar (hard delete, kitchen never saw it) |
| COOKING | Listo, Cancelar (with confirmation dialog, soft cancel) |
| READY | Marcar Entregado |
| DELIVERED | (sin accion) |
| CANCELLED | (sin accion) |

### Order-Level Actions

| Order Status | Available Actions |
|--------------|-------------------|
| OPEN | Confirmar Orden |
| COOKING | Cancelar Orden, Pedir Cuenta |
| READY | Cancelar Orden, Pedir Cuenta |
| DELIVERED | Pedir Cuenta |
| CLOSED | (sin accion) |
| CANCELLED | (sin accion) |

**Note:** There is no "Agregar Productos" toggle button. The product browser is always visible on the order page for all statuses. Adding items to a READY or DELIVERED order transitions the order back to COOKING.
