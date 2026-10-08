# Тема 4. Обчислювальні сервіси AWS: EC2, Load Balancer, Auto Scaling

Terraform-версія практики з теми 4. Розгортається **поверх мережі з теми 3** (`topic-03-vpc`): бере її VPC, публічні підмережі та Security Group і додає:

1. **Amazon EC2** — окремий сервер з вебсторінкою;
2. **Application Load Balancer** — розподіляє запити між серверами;
3. **Auto Scaling** — група серверів у двох AZ, що сама додає й прибирає інстанси за завантаженням CPU.

Кожен сервер показує сторінку зі своїм **Instance ID**, зоною доступності та IP. Відкрийте ALB і оновлюйте сторінку — ID чергуватимуться.

## Що створюється

```
Користувач ──► ALB goit-web-alb (HTTP :80)
                 │
                 ▼  Target Group goit-web-tg (health check "/")
        ┌───────────────────────────────┐
        │ Auto Scaling goit-web-asg     │   min 1 · desired 2 · max 4
        │  AZ a: EC2  ◄─┐               │   політика: середній CPU ≈ 50 %
        │  AZ b: EC2  ◄─┘ Launch Template│
        └───────────────────────────────┘
Користувач ──► EC2 goit-web-single (окремий інстанс, public IP)

Усе — у публічних підмережах VPC goit-vpc з теми 3, SG goit-vpc-web.
```

| Слайд | Ресурс у `main.tf` |
|---|---|
| Створення Amazon EC2 | `aws_launch_template.web`, `aws_instance.web`, `user-data.sh` |
| Elastic Load Balancing (ALB) | `aws_lb.web`, `aws_lb_target_group.web`, `aws_lb_listener.http` |
| Групи Auto Scaling | `aws_autoscaling_group.web` |
| Політики масштабування, метрики CloudWatch | `aws_autoscaling_policy.cpu` |
| Підключення до сервера без SSH-ключів | `aws_iam_role.ec2` + `AmazonSSMManagedInstanceCore` |

## Передумови

- Профіль `admin` з гайду. Перевірка: `aws sts get-caller-identity --profile admin`.
- **Застосована тема 3**: у `topic-03-vpc` виконано `terraform apply`. NAT Gateway для цієї теми не потрібен.

## Запуск

```bash
cd topic-04-ec2
terraform init
terraform plan
terraform apply
```

Через 2–3 хвилини сервери встановлять Apache і пройдуть health check.

```bash
terraform output
# alb_url = "http://goit-web-alb-....eu-central-1.elb.amazonaws.com"
# ec2_url = "http://3.x.x.x"
```

Відкрийте обидві адреси в браузері або подивіться ID з терміналу:

```bash
# окремий EC2
curl -s $(terraform output -raw ec2_url) | grep -o 'i-[0-9a-f]*' | head -1

# ALB: запити розподіляються між інстансами Auto Scaling групи
for i in $(seq 10); do curl -s $(terraform output -raw alb_url) | grep -o 'i-[0-9a-f]*' | head -1; done
```

## Практика Auto Scaling

Подивитися групу та її інстанси:

```bash
ASG=$(terraform output -raw asg_name)

aws autoscaling describe-auto-scaling-groups --profile admin --auto-scaling-group-names $ASG \
  --query 'AutoScalingGroups[0].[DesiredCapacity,Instances[].[InstanceId,AvailabilityZone,HealthStatus]]' --output json
```

**Навантажити CPU.** Через Session Manager на всіх інстансах групи на 10 хвилин запускаються два процеси `yes`, тобто ~100 % CPU на t3.micro:

```bash
aws ssm send-command --profile admin \
  --document-name AWS-RunShellScript \
  --targets Key=tag:aws:autoscaling:groupName,Values=$ASG \
  --parameters 'commands=["for c in 1 2; do timeout 600 yes > /dev/null & done"]'
```

За 3–5 хвилин CloudWatch-алярм спрацює, і група додасть інстанси (до `max = 4`). Стежити за цим можна так:

```bash
aws autoscaling describe-scaling-activities --profile admin --auto-scaling-group-name $ASG \
  --max-items 5 --query 'Activities[].[StatusCode,Description]' --output table
```

Коли навантаження скінчиться, група приблизно за 15 хвилин сама прибере зайві інстанси.

**Ручне масштабування** (у межах min…max):

```bash
aws autoscaling set-desired-capacity --profile admin --auto-scaling-group-name $ASG --desired-capacity 3
```

Інстанс у групі можна вбити й подивитися, як Auto Scaling замінить його новим:

```bash
aws ec2 terminate-instances --profile admin --instance-ids <i-...>
```

## Підключення до сервера

EC2 → Instances → оберіть інстанс → **Connect** → **Session Manager** → **Connect**. SSH-ключі не потрібні: доступ дає IAM-роль інстансу.

## Вартість

Поки ресурси працюють, вони коштують приблизно:
- ALB ≈ $0.025/год;
- кожен t3.micro ≈ $0.012/год;
- кожна публічна IPv4-адреса ≈ $0.005/год.

Разом це **≈ $1.5–2 на добу**. Не залишайте ресурси на ніч.

## Прибирання — обов'язково після заняття

Спершу ця тема, потім мережа:

```bash
cd topic-04-ec2 && terraform destroy
cd ../topic-03-vpc && terraform destroy   # якщо мережа більше не потрібна
```

## Типові помилки

| Симптом | Причина / що зробити |
|---|---|
| `no matching EC2 VPC found` | Не застосовано `topic-03-vpc` або змінено його `name` — передайте `-var vpc_name=...` |
| ALB віддає `502` / `503` | Інстанси ще встановлюють Apache або не пройшли health check — зачекайте 2–3 хв |
| Сторінка EC2 не відкривається | Відкривайте по `http://`, не `https://`; перевірте, що інстанс у стані `running` |
| `Destroy` теми 3 зависає на підмережах / SG | Спершу видаліть тему 4 — її ресурси використовують мережу теми 3 |
