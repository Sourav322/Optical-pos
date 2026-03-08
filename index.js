const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { authenticate, authorize, requireTenant } = require('../middleware/auth');

const authController = require('../controllers/authController');
const productController = require('../controllers/productController');
const customerController = require('../controllers/customerController');
const invoiceController = require('../controllers/invoiceController');
const prescriptionController = require('../controllers/prescriptionController');
const orderController = require('../controllers/orderController');
const reportsController = require('../controllers/reportsController');
const superAdminController = require('../controllers/superAdminController');

const loginLimiter = rateLimit({ windowMs: 15*60*1000, max: 10, message: { success: false, message: 'Too many login attempts' } });

// Health check
router.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

// Auth
router.post('/auth/login', loginLimiter, authController.login);
router.post('/auth/refresh', authController.refresh);
router.post('/auth/logout', authenticate, authController.logout);
router.get('/auth/me', authenticate, authController.me);
router.put('/auth/change-password', authenticate, authController.changePassword);

// Products
router.get('/products', authenticate, requireTenant, productController.getProducts);
router.post('/products', authenticate, requireTenant, authorize('shop_admin','staff'), productController.createProduct);
router.get('/products/low-stock', authenticate, requireTenant, productController.getLowStockProducts);
router.get('/products/barcode/:barcode', authenticate, requireTenant, productController.getProductByBarcode);
router.get('/products/:id', authenticate, requireTenant, productController.getProduct);
router.put('/products/:id', authenticate, requireTenant, authorize('shop_admin','staff'), productController.updateProduct);
router.post('/products/:id/stock-adjust', authenticate, requireTenant, authorize('shop_admin','staff'), productController.adjustStock);

// Customers
router.get('/customers', authenticate, requireTenant, customerController.getCustomers);
router.post('/customers', authenticate, requireTenant, customerController.createCustomer);
router.get('/customers/phone/:phone', authenticate, requireTenant, customerController.searchByPhone);
router.get('/customers/:id', authenticate, requireTenant, customerController.getCustomer);
router.put('/customers/:id', authenticate, requireTenant, customerController.updateCustomer);

// Prescriptions
router.post('/prescriptions', authenticate, requireTenant, prescriptionController.createPrescription);
router.get('/prescriptions/:id', authenticate, requireTenant, prescriptionController.getPrescription);
router.get('/customers/:customerId/prescriptions', authenticate, requireTenant, prescriptionController.getCustomerPrescriptions);

// Orders
router.get('/orders', authenticate, requireTenant, orderController.getOrders);
router.post('/orders', authenticate, requireTenant, orderController.createOrder);
router.get('/orders/:id', authenticate, requireTenant, orderController.getOrder);
router.put('/orders/:id/status', authenticate, requireTenant, orderController.updateOrderStatus);

// Invoices
router.get('/invoices', authenticate, requireTenant, invoiceController.getInvoices);
router.post('/invoices', authenticate, requireTenant, invoiceController.createInvoice);
router.get('/invoices/:id', authenticate, requireTenant, invoiceController.getInvoice);

// Reports
router.get('/reports/dashboard', authenticate, requireTenant, reportsController.getDashboard);
router.get('/reports/sales', authenticate, requireTenant, reportsController.getSalesReport);
router.get('/reports/inventory', authenticate, requireTenant, reportsController.getInventoryReport);
router.get('/reports/gst', authenticate, requireTenant, reportsController.getGSTReport);

// Super Admin
router.get('/admin/dashboard', authenticate, authorize('super_admin'), superAdminController.getDashboard);
router.get('/admin/tenants', authenticate, authorize('super_admin'), superAdminController.getTenants);
router.post('/admin/tenants', authenticate, authorize('super_admin'), superAdminController.createTenant);
router.put('/admin/tenants/:id/status', authenticate, authorize('super_admin'), superAdminController.updateTenantStatus);
router.get('/admin/plans', authenticate, authorize('super_admin'), superAdminController.getPlans);

module.exports = router;

// ── Users (shop admin manages their own staff) ────────────
const usersController = require('../controllers/users.controller');
router.get('/users', authenticate, requireTenant, authorize('shop_admin','super_admin'), usersController.listUsers);
router.post('/users', authenticate, requireTenant, authorize('shop_admin','super_admin'), usersController.createUser);
router.put('/users/:id', authenticate, requireTenant, authorize('shop_admin','super_admin'), usersController.updateUser);
router.patch('/users/:id/toggle', authenticate, requireTenant, authorize('shop_admin','super_admin'), usersController.toggleUser);

// ── Suppliers & Purchases ─────────────────────────────────
const suppliersController = require('../controllers/suppliers.controller');
router.get('/suppliers', authenticate, requireTenant, suppliersController.listSuppliers);
router.post('/suppliers', authenticate, requireTenant, authorize('shop_admin'), suppliersController.createSupplier);
router.get('/purchases', authenticate, requireTenant, suppliersController.listPurchases);
router.get('/purchases/:id', authenticate, requireTenant, suppliersController.getPurchase);
router.post('/purchases', authenticate, requireTenant, authorize('shop_admin','staff'), suppliersController.createPurchase);
