const { query, getClient } = require('../config/database');
const { v4: uuidv4 } = require('uuid');

const generateOrderNumber = async (tenantId) => {
  const settings = await query('SELECT order_prefix FROM tenant_settings WHERE tenant_id = $1', [tenantId]);
  const prefix = settings.rows[0]?.order_prefix || 'ORD';
  const result = await query('SELECT COUNT(*) FROM orders WHERE tenant_id = $1', [tenantId]);
  const seq = parseInt(result.rows[0].count) + 1;
  return `${prefix}-${seq.toString().padStart(6, '0')}`;
};

exports.createOrder = async (req, res) => {
  const client = await getClient();
  try {
    await client.query('BEGIN');
    const { customer_id, prescription_id, items, discount_amount=0, notes, expected_delivery_date, advance_amount=0, payment_mode, lab_name, optometrist_id } = req.body;
    const orderNumber = await generateOrderNumber(req.tenantId);
    const id = uuidv4();
    let subtotal = 0, taxAmount = 0;
    const processedItems = items.map(item => {
      const lineTotal = item.unit_price * item.quantity;
      const discountAmt = (lineTotal * (item.discount_percent||0)) / 100;
      const taxable = lineTotal - discountAmt;
      const tax = taxable * (item.tax_rate||18) / 100;
      subtotal += taxable; taxAmount += tax;
      return { ...item, discount_amount: discountAmt, tax_amount: tax, total_amount: taxable + tax };
    });
    const totalAmount = subtotal + taxAmount - parseFloat(discount_amount);
    const balanceAmount = totalAmount - parseFloat(advance_amount);

    await client.query(
      `INSERT INTO orders (id, tenant_id, order_number, customer_id, prescription_id, subtotal, discount_amount, tax_amount, total_amount, paid_amount, balance_amount, advance_amount, notes, expected_delivery_date, created_by, lab_name, optometrist_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
      [id, req.tenantId, orderNumber, customer_id, prescription_id, subtotal.toFixed(2), parseFloat(discount_amount).toFixed(2), taxAmount.toFixed(2), totalAmount.toFixed(2), parseFloat(advance_amount).toFixed(2), balanceAmount.toFixed(2), parseFloat(advance_amount).toFixed(2), notes, expected_delivery_date, req.user.id, lab_name, optometrist_id]
    );

    for (const item of processedItems) {
      await client.query(`INSERT INTO order_items (order_id, product_id, item_type, name, brand, sku, quantity, unit_price, discount_percent, discount_amount, tax_rate, tax_amount, total_amount, lens_power, coating, notes) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`,
        [id, item.product_id, item.item_type||'product', item.name, item.brand, item.sku, item.quantity, item.unit_price, item.discount_percent||0, item.discount_amount, item.tax_rate||18, item.tax_amount, item.total_amount, item.lens_power, item.coating, item.notes]);
    }

    if (advance_amount > 0 && payment_mode) {
      await client.query(`INSERT INTO order_payments (order_id, tenant_id, payment_mode, amount, created_by) VALUES ($1,$2,$3,$4,$5)`, [id, req.tenantId, payment_mode, advance_amount, req.user.id]);
    }

    await client.query(`INSERT INTO order_status_history (order_id, to_status, changed_by) VALUES ($1,'order_created',$2)`, [id, req.user.id]);
    await client.query('COMMIT');
    const order = await query(`SELECT o.*, c.name as customer_name, c.phone as customer_phone FROM orders o LEFT JOIN customers c ON c.id = o.customer_id WHERE o.id = $1`, [id]);
    res.status(201).json({ success: true, data: order.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    res.status(500).json({ success: false, message: error.message });
  } finally { client.release(); }
};

exports.getOrders = async (req, res) => {
  try {
    const { status, search, page=1, limit=20 } = req.query;
    const offset = (page-1)*limit;
    let conditions = ['o.tenant_id = $1']; let params = [req.tenantId]; let idx = 2;
    if (status) { conditions.push(`o.status = $${idx}`); params.push(status); idx++; }
    if (search) { conditions.push(`(o.order_number ILIKE $${idx} OR c.name ILIKE $${idx} OR c.phone ILIKE $${idx})`); params.push(`%${search}%`); idx++; }
    const whereClause = conditions.join(' AND ');
    const orders = await query(`SELECT o.*, c.name as customer_name, c.phone as customer_phone FROM orders o LEFT JOIN customers c ON c.id = o.customer_id WHERE ${whereClause} ORDER BY o.created_at DESC LIMIT $${idx} OFFSET $${idx+1}`, [...params, limit, offset]);
    res.json({ success: true, data: orders.rows });
  } catch (error) { res.status(500).json({ success: false, message: error.message }); }
};

exports.updateOrderStatus = async (req, res) => {
  try {
    const { status, notes } = req.body;
    const validStatuses = ['frame_selected','prescription_added','lens_selected','order_created','lab_processing','fitting_done','ready','delivered','cancelled'];
    if (!validStatuses.includes(status)) return res.status(400).json({ success: false, message: 'Invalid status' });
    const current = await query('SELECT status FROM orders WHERE id = $1 AND tenant_id = $2', [req.params.id, req.tenantId]);
    if (!current.rows.length) return res.status(404).json({ success: false, message: 'Order not found' });
    await query('UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2', [status, req.params.id]);
    await query(`INSERT INTO order_status_history (order_id, from_status, to_status, notes, changed_by) VALUES ($1,$2,$3,$4,$5)`, [req.params.id, current.rows[0].status, status, notes, req.user.id]);
    if (status === 'delivered') await query('UPDATE orders SET delivered_date = CURRENT_DATE WHERE id = $1', [req.params.id]);
    res.json({ success: true, message: 'Order status updated' });
  } catch (error) { res.status(500).json({ success: false, message: error.message }); }
};

exports.getOrder = async (req, res) => {
  try {
    const { id } = req.params;
    const [orderResult, itemsResult, paymentsResult, historyResult] = await Promise.all([
      query(
        `SELECT o.*, c.name as customer_name, c.phone as customer_phone
         FROM orders o LEFT JOIN customers c ON o.customer_id = c.id
         WHERE o.id = $1 AND o.tenant_id = $2`,
        [id, req.tenantId]
      ),
      query(
        `SELECT oi.*, p.name as product_name, p.sku
         FROM order_items oi LEFT JOIN products p ON oi.product_id = p.id
         WHERE oi.order_id = $1`,
        [id]
      ),
      query(`SELECT * FROM order_payments WHERE order_id = $1`, [id]),
      query(`SELECT * FROM order_status_history WHERE order_id = $1 ORDER BY created_at ASC`, [id]),
    ]);

    if (!orderResult.rows.length) return res.status(404).json({ success: false, message: 'Order not found' });

    res.json({
      success: true,
      data: {
        ...orderResult.rows[0],
        items: itemsResult.rows,
        payments: paymentsResult.rows,
        history: historyResult.rows,
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
