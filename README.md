# OptiCare POS — Production SaaS Optical Shop Management System

A full-stack, multi-tenant SaaS billing & POS system for optical shops.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18 + Vite + Tailwind CSS + Zustand |
| Backend | Node.js + Express.js REST API |
| Database | PostgreSQL (multi-tenant) |
| Auth | JWT + bcrypt |
| Deployment | Nginx + PM2 on AWS EC2 |

## Features

### POS Billing
- Fast billing interface with barcode scanner support (USB HID)
- Item-level discounts
- GST auto-calculation (CGST/SGST/IGST)
- Cash / UPI / Card / Split payment modes
- Real-time stock deduction on sale
- Printable GST invoice

### Inventory Management
- Frames, Lenses, Contact Lenses, Accessories
- Low stock alerts
- Stock movement history
- Supplier purchase management
- Barcode/SKU search

### Optical Prescription
- Full Rx entry: SPH, CYL, AXIS, ADD, PD (both eyes)
- Blue cut, photochromic, high index options
- Full prescription history per patient

### Order Workflow
7-step workflow: Frame → Rx → Lens → Created → Lab → Fitting → Ready → Delivered

### Customer CRM
- Customer profiles with complete purchase & prescription history
- Loyalty tracking

### Reports
- Daily/weekly/monthly sales reports with charts
- Inventory: low stock, dead stock, best sellers
- GST reports with CGST/SGST/IGST breakdown

### Super Admin (SaaS Console)
- Create/manage shops (tenants)
- Subscription plan management
- Activate / suspend tenants
- MRR tracking

## Project Structure

```
optical-saas/
├── backend/
│   ├── src/
│   │   ├── config/          # DB, logger
│   │   ├── controllers/     # auth, products, customers, invoices, orders, prescriptions, reports, superAdmin
│   │   ├── middleware/       # auth (JWT + RBAC)
│   │   └── routes/          # All API routes
│   └── .env.example
├── frontend/
│   └── src/
│       ├── pages/           # All page components
│       ├── services/        # API client (Axios)
│       ├── store/           # Zustand (auth + POS cart)
│       └── layouts/         # MainLayout sidebar
├── database/
│   └── schema.sql           # Complete PostgreSQL schema
├── nginx/
│   └── nginx.conf           # Production reverse proxy config
└── docs/
    ├── DEPLOYMENT.md        # AWS EC2 setup guide
    └── API.md               # Full API reference
```

## Quick Start (Development)

```bash
# 1. Database
psql -U postgres -c "CREATE DATABASE optical_saas;"
psql -U postgres -d optical_saas -f database/schema.sql

# 2. Backend
cd backend
cp .env.example .env  # fill in DB credentials + JWT secret
npm install
npm run dev  # runs on :5000

# 3. Frontend
cd frontend
npm install
npm run dev  # runs on :5173
```

## Default Login
- **Super Admin:** admin@opticalsaas.com / SuperAdmin@123
- **Sample Shop Admin:** admin@cleareyesoptical.com / Welcome@123

## Multi-Tenant Architecture
Every DB table contains `tenant_id`. All queries are scoped to the authenticated user's tenant. Super admin bypasses tenant scoping for platform management.
