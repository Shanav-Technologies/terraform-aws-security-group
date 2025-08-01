
module "labels" {
  source      = "git::git@github.com:Shanav-Technologies/terraform-aws-labels.git?ref=v1.0.0"
  name        = var.name
  environment = var.environment
  managedby   = var.managedby
  label_order = var.label_order
  repository  = var.repository
}

##-----------------------------------------------------------------------------
## Security Group Resource
##-----------------------------------------------------------------------------
resource "aws_security_group" "default" {
  count       = var.enable && var.new_sg ? 1 : 0
  name        = format("%s-sg", module.labels.id)
  vpc_id      = var.vpc_id
  description = var.sg_description
  tags        = module.labels.tags
  lifecycle {
    create_before_destroy = true
  }
}

##-----------------------------------------------------------------------------
## Existing Security Group Data Source
##-----------------------------------------------------------------------------
data "aws_security_group" "existing" {
  count = var.enable && var.existing_sg_id != null ? 1 : 0
  id    = var.existing_sg_id
  # vpc_id = var.vpc_id
}

##-----------------------------------------------------------------------------
## Prefix List Resource
##-----------------------------------------------------------------------------
resource "aws_ec2_managed_prefix_list" "prefix_list" {
  count          = var.enable && var.prefix_list_enabled && length(var.prefix_list_ids) < 1 ? 1 : 0
  address_family = var.prefix_list_address_family
  max_entries    = var.max_entries
  name           = format("%s-prefix-list", module.labels.id)
  dynamic "entry" {
    for_each = var.entry
    content {
      cidr        = lookup(entry.value, "cidr", null)
      description = lookup(entry.value, "description", null)
    }
  }
}

##-----------------------------------------------------------------------------
## New SG Ingress Rules
##-----------------------------------------------------------------------------
resource "aws_security_group_rule" "new_sg_ingress_with_cidr_blocks" {
  for_each          = var.enable ? { for rule in var.new_sg_ingress_rules_with_cidr_blocks : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "new_sg_ingress_with_self" {
  for_each          = var.enable ? { for rule in var.new_sg_ingress_rules_with_self : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  self              = lookup(each.value, "self", true)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "new_sg_ingress_with_source_sg_id" {
  for_each          = var.enable ? { for rule in var.new_sg_ingress_rules_with_source_sg_id : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  source_security_group_id = lookup(each.value, "source_security_group_id", null) != null ? (
    length(regexall("^sg-", each.value.source_security_group_id)) > 0 ? each.value.source_security_group_id : null
  ) : null
  description = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "new_sg_ingress_with_prefix_list" {
  for_each          = var.enable ? { for rule in var.new_sg_ingress_rules_with_prefix_list : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  prefix_list_ids   = lookup(each.value, "prefix_list_ids", null) == null ? aws_ec2_managed_prefix_list.prefix_list[*].id : lookup(each.value, "prefix_list_ids", null)
  description       = lookup(each.value, "description", null)
}

##-----------------------------------------------------------------------------
## Existing SG Ingress Rules
##-----------------------------------------------------------------------------
resource "aws_security_group_rule" "existing_sg_ingress_cidr_blocks" {
  for_each          = var.enable ? { for rule in var.existing_sg_ingress_rules_with_cidr_blocks : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "existing_sg_ingress_with_self" {
  for_each          = var.enable ? { for rule in var.existing_sg_ingress_rules_with_self : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  self              = lookup(each.value, "self", true)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "existing_sg_ingress_with_source_sg_id" {
  for_each          = var.enable ? { for rule in var.existing_sg_ingress_rules_with_source_sg_id : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  source_security_group_id = lookup(each.value, "source_security_group_id", null) != null ? (
    length(regexall("^sg-", each.value.source_security_group_id)) > 0 ? each.value.source_security_group_id : null
  ) : null
  description = try(each.value.description, "Allow inbound traffic.")
}

resource "aws_security_group_rule" "existing_sg_ingress_with_prefix_list" {
  for_each          = var.enable ? { for rule in var.existing_sg_ingress_rules_with_prefix_list : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  prefix_list_ids   = lookup(each.value, "prefix_list_ids", null) == null ? aws_ec2_managed_prefix_list.prefix_list[*].id : lookup(each.value, "prefix_list_ids", null)
  description       = try(each.value.description, "Allow inbound traffic.")
}

##-----------------------------------------------------------------------------
## New SG Egress Rules
##-----------------------------------------------------------------------------
resource "aws_security_group_rule" "new_sg_egress_with_cidr_blocks" {
  for_each          = var.enable ? { for rule in var.new_sg_egress_rules_with_cidr_blocks : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "new_sg_egress_with_self" {
  for_each          = var.enable ? { for rule in var.new_sg_egress_rules_with_self : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  self              = lookup(each.value, "self", true)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "new_sg_egress_with_source_sg_id" {
  for_each          = var.enable ? { for rule in var.new_sg_egress_rules_with_source_sg_id : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  source_security_group_id = lookup(each.value, "source_security_group_id", null) != null ? (
    length(regexall("^sg-", each.value.source_security_group_id)) > 0 ? each.value.source_security_group_id : null
  ) : null
  description = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "new_sg_egress_with_prefix_list" {
  for_each          = var.enable ? { for rule in var.new_sg_egress_rules_with_prefix_list : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  prefix_list_ids   = lookup(each.value, "prefix_list_ids", null) == null ? aws_ec2_managed_prefix_list.prefix_list[*].id : lookup(each.value, "prefix_list_ids", null)
  description       = lookup(each.value, "description", null)
}

##-----------------------------------------------------------------------------
## Existing SG Egress Rules
##-----------------------------------------------------------------------------
resource "aws_security_group_rule" "existing_sg_egress_with_cidr_blocks" {
  for_each          = var.enable ? { for rule in var.existing_sg_egress_rules_with_cidr_blocks : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "existing_sg_egress_with_self" {
  for_each          = var.enable ? { for rule in var.existing_sg_egress_rules_with_self : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  self              = lookup(each.value, "self", true)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "existing_sg_egress_with_source_sg_id" {
  for_each          = var.enable ? { for rule in var.existing_sg_egress_rules_with_source_sg_id : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  source_security_group_id = lookup(each.value, "source_security_group_id", null) != null ? (
    length(regexall("^sg-", each.value.source_security_group_id)) > 0 ? each.value.source_security_group_id : null
  ) : null
  description = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "existing_sg_egress_with_prefix_list" {
  for_each          = var.enable ? { for rule in var.existing_sg_egress_rules_with_prefix_list : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  prefix_list_ids   = lookup(each.value, "prefix_list_ids", null) == null ? aws_ec2_managed_prefix_list.prefix_list[*].id : lookup(each.value, "prefix_list_ids", null)
  description       = lookup(each.value, "description", null)
}