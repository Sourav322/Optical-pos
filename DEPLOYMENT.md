# OptiCare POS — Deployment Guide (AWS EC2 / Ubuntu 22.04)

## 1. Server Setup

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y nodejs npm postgresql nginx certbot python3-certbot-nginx git
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pm2
```

## 2. PostgreSQL Setup

```bash
sudo -u postgres psql
CREATE DATABASE optical_saas;
CREATE USER optical_user WITH ENCRYPTED PASSWORD 'your_strong_password';
GRANT ALL PRIVILEGES ON DATABASE optical_saas TO optical_user;
\q

psql -U optical_user -d optical_saas -f /var/www/optical-saas/database/schema.sql
```

## 3. Deploy Backend

```bash
cd /var/www/optical-saas/backend
cp .env.example .env
nano .env  # Fill in all values
npm install --production
pm2 start src/index.js --name "optical-api" --instances 2 -i max
pm2 save && pm2 startup
```

## 4. Build & Deploy Frontend

```bash
cd /var/www/optical-saas/frontend
echo "VITE_API_URL=/api/v1" > .env.production
npm install && npm run build
```

## 5. Nginx & SSL

```bash
sudo cp /var/www/optical-saas/nginx/nginx.conf /etc/nginx/nginx.conf
# Edit nginx.conf: replace yourdomain.com with your real domain
sudo certbot --nginx -d yourdomain.com
sudo systemctl restart nginx
```

## 6. Default Credentials

- Super Admin: `admin@opticalsaas.com` / `SuperAdmin@123`
- Change immediately after first login!

## 7. PM2 Commands

```bash
pm2 status          # Check status
pm2 logs optical-api  # View logs
pm2 restart optical-api  # Restart
pm2 monit           # Monitor
```

## 8. Security Checklist

- [ ] Change all default passwords
- [ ] Set strong JWT_SECRET (64+ chars)
- [ ] Enable UFW firewall (ports 22, 80, 443 only)
- [ ] Configure regular PostgreSQL backups
- [ ] Set up CloudWatch or similar monitoring
- [ ] Enable fail2ban for SSH protection
