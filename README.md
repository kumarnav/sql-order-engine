# 🗄️ PostgreSQL E-Commerce Inventory & Transaction Engine

An advanced relational database architecture and PL/pgSQL backend script designed to manage high-concurrency e-commerce transactions, inventory control, automated audit logging, and financial ledger updates.

## 🚀 Key Features
- **ACID-Compliant Stored Procedures:** Features row-level locking (`FOR UPDATE`) to prevent race conditions during simultaneous customer checkouts.
- **Automated Triggers:** Automatically records audit trails whenever product inventory changes.
- **Custom Aggregate Functions:** PL/pgSQL function to calculate complex customer lifetime metrics on the fly.
- **Referential Integrity:** Enforces strict foreign keys, check constraints, and cascading deletes.

## 🛠️ Tech Stack
- **Database:** PostgreSQL 14+
- **Language:** PL/pgSQL, Standard SQL

## 📦 How to Deploy
1. Run `schema.sql` to initialize tables, relationships, and indexes.
2. Run `procedures.sql` to compile procedures, functions, and triggers.
3. Test a transaction:
   ```sql
   CALL process_order(1, 1, 2);