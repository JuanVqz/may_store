# Takeout Orders (Para Llevar)

## Goal

Support orders that don't require a table assignment (takeout / para llevar).

## Approach

Make table optional on Order, add `order_type` enum (`dine_in` / `takeout`), and an optional `customer_name` field.

## Key Changes

- Order model: `belongs_to :table, optional: true`, `order_type` enum, `customer_name` column
- Tables screen: "Para Llevar" button alongside table grid
- Order views: show customer name or order code instead of table name for takeout
- Kitchen view: distinguish dine-in (table name) vs takeout ("Para Llevar" + customer name)
- Migration: add `order_type` (default: `dine_in`), `customer_name` to orders, make `table_id` nullable

## Dependencies

- Should be implemented after the single-page order flow refactor is done
