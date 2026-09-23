# =====================================================
# FreshBox SpA - AWS Backup
# Backup diario EC2 MySQL - Retencion 7 dias
# =====================================================

resource "aws_backup_vault" "freshbox" {
  name = "FreshBox-Backup-Vault"
}

resource "aws_backup_plan" "freshbox" {
  name = "FreshBox-Backup-Plan"

  rule {
    rule_name         = "FreshBox-MySQL-Daily"
    target_vault_name = aws_backup_vault.freshbox.name

    # Backup diario a las 05:00 UTC
    schedule = "cron(0 5 * * ? *)"

    lifecycle {
      delete_after = 7
    }
  }
}

resource "aws_backup_selection" "mysql" {
  name         = "FreshBox-MySQL-Selection"
  plan_id      = aws_backup_plan.freshbox.id
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  resources = [
    aws_instance.mysql.arn
  ]
}

# Obtener automaticamente el ID de nuestra cuenta AWS
data "aws_caller_identity" "current" {}