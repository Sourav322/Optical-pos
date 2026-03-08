# OptiCare POS — API Reference

Base URL: `https://yourdomain.com/api/v1`

## Authentication

All endpoints (except `/auth/login`) require:
```
Authorization: Bearer <accessToken>
```

### POST /auth/login
```json
{ "email": "user@shop.com", "password": "password" }
```
Response: `{ user, accessToken, refreshToken }`

### POST /auth/refresh
```json
{ "refreshToken": "..." }
```

### GET /auth/me
Returns current user + tenant info.

## Products

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /products | List products (search, category, page) |
| POST | /products | Create product |
| GET | /products/:id | Get product |
| PUT | /products/:id | Update product |
| GET | /products/barcode/:code | Find by barcode/SKU |
| GET | /products/low-stock | Low stock items |
| POST | /products/:id/stock-adjust | Adjust stock level |

## Customers

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /customers | List customers |
| POST | /customers | Create customer |
| GET | /customers/:id | Customer + history |
| PUT | /customers/:id | Update customer |
| GET | /customers/phone/:phone | Find by phone |
| GET | /customers/:id/prescriptions | Customer prescriptions |

## Invoices (POS Billing)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /invoices | List invoices |
| POST | /invoices | Create invoice (auto stock deduction) |
| GET | /invoices/:id | Full invoice with shop details |

### Create Invoice Request Body
```json
{
  "customer_id": "uuid (optional)",
  "customer_name": "Walk-in Customer",
  "items": [
    {
      "product_id": "uuid",
      "name": "Ray-Ban Aviator",
      "quantity": 1,
      "unit_price": 3500,
      "discount_amount": 0,
      "tax_rate": 18
    }
  ],
  "discount_amount": 0,
  "payment_mode": "cash|upi|card",
  "paid_amount": 4130,
  "is_interstate": false
}
```

## Prescriptions

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /prescriptions | Save prescription |
| GET | /prescriptions/:id | Get prescription |

## Orders

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /orders | List orders |
| POST | /orders | Create order |
| PUT | /orders/:id/status | Update order status |

### Order Statuses
`frame_selected → prescription_added → lens_selected → order_created → lab_processing → fitting_done → ready → delivered`

## Reports

| Endpoint | Description |
|----------|-------------|
| GET /reports/dashboard | KPIs: today sales, pending orders, low stock |
| GET /reports/sales | Sales report (daily/weekly/monthly) |
| GET /reports/inventory | Inventory reports (low_stock/best_selling/dead_stock) |
| GET /reports/gst | GST summary with CGST/SGST/IGST breakdown |

## Super Admin (role: super_admin only)

| Endpoint | Description |
|----------|-------------|
| GET /admin/dashboard | Platform KPIs + MRR |
| GET /admin/tenants | All shops |
| POST /admin/tenants | Create new shop + admin user |
| PUT /admin/tenants/:id/status | Activate / Suspend |
| GET /admin/plans | Subscription plans |

## Roles & Permissions

| Role | Access |
|------|--------|
| super_admin | Full platform access |
| shop_admin | Full shop access |
| staff | POS, customers, orders |
| optometrist | Prescriptions, customers |
