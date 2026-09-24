# =====================================================
# FreshBox SpA - Compute
# Amazon Linux 2023 ARM64
# =====================================================

data "aws_ami" "amazon_linux_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =====================================================
# EC2 DATA - MySQL PRIMARY
# Ubicada en DATA-1A
# =====================================================

resource "aws_instance" "mysql" {
  ami                    = data.aws_ami.amazon_linux_arm.id
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.data_1a.id
  vpc_security_group_ids = [aws_security_group.data.id]

  iam_instance_profile = "LabInstanceProfile"

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x

    # Instalar MariaDB Server
    dnf update -y
    dnf install -y mariadb105-server

    # Configurar PRIMARY para replicacion
    cat > /etc/my.cnf.d/replication.cnf <<'MYSQLCONF'
    [mariadb]
    server_id=1
    log_bin=mysql-bin
    binlog_format=ROW
    bind-address=0.0.0.0
    MYSQLCONF

    # Iniciar y habilitar MariaDB
    systemctl enable mariadb
    systemctl start mariadb

    # Crear usuario de FreshBox y usuario de replicacion
    mysql -u root <<'MYSQLUSER'
    CREATE USER IF NOT EXISTS 'alumno'@'%' IDENTIFIED BY '${var.db_password}';
    GRANT ALL PRIVILEGES ON freshbox.* TO 'alumno'@'%';

    CREATE USER IF NOT EXISTS 'replicator'@'10.0.2.%' IDENTIFIED BY '${var.replication_password}';
    GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'10.0.2.%';
    GRANT BINLOG MONITOR ON *.* TO 'replicator'@'10.0.2.%';

    FLUSH PRIVILEGES;
    MYSQLUSER

    # Crear archivo SQL inicial
    cat > /tmp/init.sql <<'SQLFILE'
    ${file("${path.module}/init.sql")}
    SQLFILE

    # Crear base de datos, tabla y productos iniciales
    mysql -u root < /tmp/init.sql

    echo "=== FreshBox MySQL PRIMARY configurado ==="
  EOF

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "FreshBox-MySQL"
  }
}

# =====================================================
# EC2 DATA - MySQL SECONDARY
# Ubicada en DATA-1B
# Preparada para replicacion y failover
# =====================================================

resource "aws_instance" "mysql_secondary" {
  ami                    = data.aws_ami.amazon_linux_arm.id
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.data_1b.id
  vpc_security_group_ids = [aws_security_group.data.id]

  iam_instance_profile = "LabInstanceProfile"

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x

    # Instalar MariaDB Server
    dnf update -y
    dnf install -y mariadb105-server

    # Configurar SECONDARY
    cat > /etc/my.cnf.d/replication.cnf <<'MYSQLCONF'
    [mariadb]
    server_id=2
    relay_log=relay-bin
    read_only=ON
    bind-address=0.0.0.0
    MYSQLCONF

    systemctl enable mariadb
    systemctl start mariadb

    # Crear base inicial y usuario de FreshBox
    cat > /tmp/init.sql <<'SQLFILE'
    ${file("${path.module}/init.sql")}
    SQLFILE

    mysql -u root < /tmp/init.sql

    mysql -u root <<'MYSQLUSER'
    CREATE USER IF NOT EXISTS 'alumno'@'%' IDENTIFIED BY '${var.db_password}';
    GRANT ALL PRIVILEGES ON freshbox.* TO 'alumno'@'%';
    FLUSH PRIVILEGES;
    MYSQLUSER

    # Copiar script de configuracion de replicacion
    cat > /home/ec2-user/configure-replication.sh <<'REPLICATIONSCRIPT'
    ${local.replication_script}
    REPLICATIONSCRIPT

    chmod +x /home/ec2-user/configure-replication.sh
    chown ec2-user:ec2-user /home/ec2-user/configure-replication.sh

    # Guardar automaticamente la IP de la PRIMARY
    echo '${aws_instance.mysql.private_ip}' > /home/ec2-user/mysql-primary-ip.txt
    chown ec2-user:ec2-user /home/ec2-user/mysql-primary-ip.txt

    # Ejecutar automaticamente la configuracion de replicacion
    /home/ec2-user/configure-replication.sh '${aws_instance.mysql.private_ip}' '${var.db_password}' '${var.replication_password}'

    echo "=== FreshBox MySQL SECONDARY preparada ==="
  EOF

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "FreshBox-MySQL-Secondary"
  }
}

# =====================================================
# USER DATA - EC2 APP
# Instala Docker + Docker Compose
# y deja preparado deploy-containers.sh
# =====================================================

locals {
  deploy_script = file("${path.module}/app/scripts/deploy-containers.sh")

  replication_script = file("${path.module}/scripts/configure-replication.sh")

  app_user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x

    dnf update -y
    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    usermod -aG docker ec2-user

    mkdir -p /usr/local/lib/docker/cli-plugins

    curl -SL https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-aarch64 \
      -o /usr/local/lib/docker/cli-plugins/docker-compose

    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    dnf install -y telnet mariadb105

    # Copiar automaticamente el script de despliegue
    cat > /home/ec2-user/deploy-containers.sh <<'DEPLOYSCRIPT'
    ${local.deploy_script}
    DEPLOYSCRIPT

    chmod +x /home/ec2-user/deploy-containers.sh
    chown ec2-user:ec2-user /home/ec2-user/deploy-containers.sh

    # Guardar automaticamente la IP privada de MySQL
    echo '${aws_instance.mysql.private_ip}' > /home/ec2-user/mysql-private-ip.txt
    chown ec2-user:ec2-user /home/ec2-user/mysql-private-ip.txt

    # Ejecutar automaticamente el despliegue de los 5 contenedores
    sudo -u ec2-user env DB_PASSWORD='${var.db_password}' /home/ec2-user/deploy-containers.sh

    echo "=== FreshBox APP configurada ==="
  EOF
}

# =====================================================
# LAUNCH TEMPLATE - EC2 APP
# Plantilla utilizada por Auto Scaling Group
# =====================================================

resource "aws_launch_template" "app" {
  name_prefix   = "FreshBox-APP-"
  image_id      = data.aws_ami.amazon_linux_arm.id
  instance_type = "t4g.small"

  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(local.app_user_data)

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted   = true
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "FreshBox-APP-ASG"
    }
  }

  tags = {
    Name = "FreshBox-APP-Launch-Template"
  }
}

# =====================================================
# AUTO SCALING GROUP
# Minimo 2 - Deseado 2 - Maximo 4
# Distribuido entre AZ us-east-1a y us-east-1b
# =====================================================

resource "aws_autoscaling_group" "app" {
  name = "FreshBox-APP-ASG"

  depends_on = [
    terraform_data.ecr_images
  ]

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = [
    aws_subnet.app_1a.id,
    aws_subnet.app_1b.id
  ]

  target_group_arns = [
    aws_lb_target_group.freshbox.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }

  }

  tag {
    key                 = "Name"
    value               = "FreshBox-APP-ASG"
    propagate_at_launch = true
  }
}


