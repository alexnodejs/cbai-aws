#!/bin/bash
# Виконується один раз при першому запуску інстансу: ставить Apache і пише сторінку з ID інстансу.
dnf install -y httpd

TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }

INSTANCE_ID=$(md instance-id)
AZ=$(md placement/availability-zone)
PRIVATE_IP=$(md local-ipv4)
INSTANCE_TYPE=$(md instance-type)

cat > /var/www/html/index.html <<EOF
<!doctype html>
<html lang="uk">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${INSTANCE_ID}</title>
  <style>
    body { margin: 0; min-height: 100vh; display: grid; place-items: center;
           font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0; }
    main { text-align: center; padding: 16px; }
    h1 { font-size: 1rem; font-weight: 500; color: #94a3b8; margin: 0 0 12px; }
    .id { font-family: ui-monospace, monospace; font-size: clamp(1.5rem, 6vw, 3rem);
          color: #f97316; margin: 0 0 24px; word-break: break-all; }
    dl { display: grid; grid-template-columns: auto auto; gap: 6px 16px; justify-content: center; margin: 0; }
    dt { color: #94a3b8; text-align: right; }
    dd { margin: 0; text-align: left; font-family: ui-monospace, monospace; }
  </style>
</head>
<body>
  <main>
    <h1>GoIT · Тема 4 · Обчислювальні сервіси AWS</h1>
    <p class="id">${INSTANCE_ID}</p>
    <dl>
      <dt>Availability Zone</dt><dd>${AZ}</dd>
      <dt>Private IP</dt><dd>${PRIVATE_IP}</dd>
      <dt>Instance type</dt><dd>${INSTANCE_TYPE}</dd>
    </dl>
  </main>
</body>
</html>
EOF

systemctl enable --now httpd
