data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Hasło trzymane w SSM Parameter Store (SecureString) zamiast w user_data.
resource "aws_ssm_parameter" "server_password" {
  name  = "/${var.name}/server_password"
  type  = "SecureString"
  value = var.server_password
}

# --- IAM: dostęp przez SSM Session Manager (bez SSH) + odczyt hasła ---------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "read_password" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.server_password.arn]
  }
}

resource "aws_iam_role_policy" "read_password" {
  name   = "read-server-password"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.read_password.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-instance"
  role = aws_iam_role.instance.name
}

# --- Trwały dysk na świat (przeżywa odtworzenie instancji) ------------------

resource "aws_ebs_volume" "data" {
  availability_zone = local.az
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name     = "${var.name}-data"
    Snapshot = var.name
  }

  lifecycle {
    prevent_destroy = false # ustaw na true, jeśli chcesz chronić świat przed `terraform destroy`
  }
}

# --- Instancja EC2 ----------------------------------------------------------

resource "aws_instance" "valheim" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.valheim.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region         = var.region
    volume_id      = aws_ebs_volume.data.id
    password_param = aws_ssm_parameter.server_password.name
    server_name    = var.server_name
    world_name     = var.world_name
    server_public  = var.server_public
    timezone       = var.timezone
    extra_env      = var.extra_env
  })
  user_data_replace_on_change = true

  tags = { Name = var.name }

  lifecycle {
    # Nie odtwarzaj serwera przy każdym nowym wydaniu AMI.
    ignore_changes = [ami]
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.valheim.id

  # Zatrzymaj instancję (czysty zapis świata) zanim odepniesz dysk.
  stop_instance_before_detaching = true
}

resource "aws_eip" "valheim" {
  domain   = "vpc"
  instance = aws_instance.valheim.id

  tags = { Name = var.name }

  depends_on = [aws_internet_gateway.this]
}

# --- Codzienne snapshoty dysku ze światem (Data Lifecycle Manager) ----------

data "aws_iam_policy_document" "dlm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm" {
  count              = var.snapshot_retention_days > 0 ? 1 : 0
  name               = "${var.name}-dlm"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume.json
}

resource "aws_iam_role_policy_attachment" "dlm" {
  count      = var.snapshot_retention_days > 0 ? 1 : 0
  role       = aws_iam_role.dlm[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

resource "aws_dlm_lifecycle_policy" "snapshots" {
  count              = var.snapshot_retention_days > 0 ? 1 : 0
  description        = "${var.name} daily world snapshots"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { Snapshot = var.name }

    schedule {
      name = "daily"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["05:00"] # UTC
      }

      retain_rule {
        count = var.snapshot_retention_days
      }

      copy_tags = true
    }
  }
}
