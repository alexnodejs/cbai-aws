# Тема 3. Мережеві сервіси AWS: VPC через Terraform

Terraform-версія практики з теми 3: VPC, публічні й приватні підмережі, таблиці маршрутизації, Internet Gateway, NAT Gateway, Security Group і Network ACL.

## Що створюється

```
VPC 10.0.0.0/16 (eu-central-1)
├── Internet Gateway
├── AZ a
│   ├── public-1   10.0.1.0/24   ─┐  route: 0.0.0.0/0 → IGW
│   │   └── NAT Gateway + EIP     │  (лише з enable_nat_gateway=true)
│   └── private-1  10.0.11.0/24  ─┼┐ route: 0.0.0.0/0 → NAT (якщо NAT увімкнено)
├── AZ b                          ││
│   ├── public-2   10.0.2.0/24   ─┘│
│   └── private-2  10.0.12.0/24  ──┘
├── Security Group web: 80, 443 з інтернету; 22 лише з вашого IP
└── Network ACL на публічних підмережах: 80, 443, 22 (ваш IP), ефемерні 1024–65535, трафік VPC
```

| Слайд | Ресурс у `main.tf` |
|---|---|
| CIDR-діапазон | `aws_vpc.main` |
| Підмережі (Subnets) | `aws_subnet.public`, `aws_subnet.private` |
| Таблиці маршрутизації | `aws_route_table.public`, `aws_route_table.private` |
| Internet Gateway | `aws_internet_gateway.main` |
| NAT Gateway | `aws_eip.nat`, `aws_nat_gateway.main`, `aws_route.private_nat` |
| Security Groups | `aws_security_group.web` |
| Network ACLs | `aws_network_acl.public` |

## Передумови

- Terraform ≥ 1.5: `terraform version`.
- Профіль `admin` з гайду «AWS CLI: роль з правами адміністратора як profile». Перевірка:

```bash
aws sts get-caller-identity --profile admin
# "Arn": "arn:aws:sts::<ACCOUNT_ID>:assumed-role/cli-admin-role/student-cli-admin"
```

Інший профіль можна передати через `-var aws_profile=<ім'я>`.

## Запуск

```bash
cd topic-03-vpc

# 1. Ваш публічний IP — лише з нього буде дозволено SSH
echo "my_ip_cidr = \"$(curl -s https://checkip.amazonaws.com)/32\"" > terraform.tfvars

# 2. Завантажити провайдер AWS
terraform init

# 3. Подивитися, що буде створено
terraform plan

# 4. Створити мережу (без NAT Gateway — безкоштовно)
terraform apply
```

### NAT Gateway (платно)

NAT Gateway коштує ~$0.05/год плюс Elastic IP, тобто ~$1.3 на добу, поки його не видалити. Увімкнути:

```bash
terraform apply -var enable_nat_gateway=true
```

Вимкнути, лишивши решту мережі: `terraform apply` (без змінної).

## Перевірка через AWS CLI

```bash
aws ec2 describe-vpcs --profile admin \
  --filters Name=tag:Project,Values=goit-topic-03 \
  --query 'Vpcs[].[VpcId,CidrBlock,Tags[?Key==`Name`]|[0].Value]' --output table

aws ec2 describe-subnets --profile admin \
  --filters Name=tag:Project,Values=goit-topic-03 \
  --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output table

aws ec2 describe-route-tables --profile admin \
  --filters Name=tag:Project,Values=goit-topic-03 \
  --query 'RouteTables[].[Tags[?Key==`Name`]|[0].Value,Routes[].[DestinationCidrBlock,GatewayId||NatGatewayId]]' --output json
```

## Прибирання — обов'язково після заняття

```bash
terraform destroy
```

## Типові помилки

| Симптом | Причина / що зробити |
|---|---|
| `No valid credential sources found` / `failed to get shared config profile, admin` | Немає профілю `admin` — пройдіть гайд або передайте `-var aws_profile=...` |
| Terraform питає `var.my_ip_cidr` | Не створено `terraform.tfvars` (крок 1) |
| SSH не підключається після зміни мережі (Wi‑Fi/VPN) | Змінився публічний IP — повторіть крок 1 і `terraform apply` |
| Приватна підмережа не має інтернету | Так і задумано без NAT; увімкніть `enable_nat_gateway=true` |
