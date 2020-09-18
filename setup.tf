variable "org_name" {}
variable "api_token" {}
variable "base_url" {}

provider "okta" {
  org_name = var.org_name
  base_url = var.base_url
  api_token = var.api_token
  version   = "~> 3.0"
}

locals {
  base_url = "http://localhost:5000"
}

data "okta_group" "all" {
  name = "Everyone"
}

resource "okta_group" "admin" {
  name        = "mdorn_admin"
  description = "mdorn Admin (Generated by UDP)"
}

resource "okta_app_oauth" "mdorn" {
  label                      = "mdorn (Generated by UDP)"
  type                       = "web"
  grant_types                = ["authorization_code", "implicit"]
  redirect_uris              = [local.base_url,
                                "${local.base_url}/login/okta-admin/authorized",
                                "${local.base_url}/login/okta/authorized",
                                "${local.base_url}/implicit/callback",
                                "${local.base_url}/widget"
  ]
  post_logout_redirect_uris  = ["http://localhost:5000"]  
  login_uri                  = "${local.base_url}/login/okta/authorized"
  response_types             = ["token", "id_token", "code"]
  issuer_mode                = "ORG_URL"
  groups                     = [data.okta_group.all.id]
  consent_method             = "TRUSTED"
  # TODO: Grant this app the "okta.users.read" scope
}

resource "okta_app_user_schema" "app_permissions" {
  app_id      = okta_app_oauth.mdorn.id
  index       = "Permissions"
  title       = "app_permissions"
  description = "Permission level for the user of this application"
  master      = "OKTA"
  scope       = "SELF"
  type        = "array"
  array_type  = "string"
  array_enum  = ["admin", "premium"]

  array_one_of {
    const = "admin"
    title = "Admin"
  }

  array_one_of {
    const = "premium"
    title = "Premium"
  }
}

resource "okta_app_user_schema" "app_features" {
  app_id      = okta_app_oauth.mdorn.id
  index       = "Features"
  title       = "app_features"
  description = "Feature set for the user of this application"
  master      = "OKTA"
  scope       = "SELF"
  type        = "array"
  array_type  = "string"
  array_enum  = ["regular", "premium"]

  array_one_of {
    const = "regular"
    title = "Regular"
  }

  array_one_of {
    const = "premium"
    title = "Premium"
  }
}

resource "okta_trusted_origin" "mdorn" {
  name   = local.base_url
  origin = local.base_url
  scopes = ["CORS"]
}

resource "okta_auth_server" "mdorn" {
  audiences   = [local.base_url]
  description = "mdorn auth server"
  name        = "mdorn"
}

resource "okta_auth_server_scope" "products_read" {
  description    = "products:read"
  name           = "products:read"
  auth_server_id = okta_auth_server.mdorn.id
}

resource "okta_auth_server_scope" "products_update" {
  description    = "products:update"
  name           = "products:update"
  auth_server_id = okta_auth_server.mdorn.id
}

resource "okta_auth_server_scope" "orders_create" {
  description    = "orders:create"
  name           = "orders:create"
  auth_server_id = okta_auth_server.mdorn.id
}

resource "okta_auth_server_scope" "orders_read" {
  description    = "orders:read"
  name           = "orders:read"
  auth_server_id = okta_auth_server.mdorn.id
}

resource "okta_auth_server_scope" "orders_update" {
  description    = "orders:update"
  name           = "orders:update"
  auth_server_id = okta_auth_server.mdorn.id
}

resource "okta_auth_server_claim" "feature_access" {
  name              = "feature_access"
  status            = "ACTIVE"
  claim_type        = "RESOURCE"
  value_type        = "EXPRESSION"
  value             = "appuser.app_features"
  auth_server_id    = okta_auth_server.mdorn.id
}

resource "okta_auth_server_claim" "role" {
  name              = "role"
  status            = "ACTIVE"
  claim_type        = "RESOURCE"
  value_type        = "EXPRESSION"
  value             = "appuser.app_permissions"
  auth_server_id    = okta_auth_server.mdorn.id
}

resource "okta_auth_server_claim" "groups" {
  name              = "groups"
  status            = "ACTIVE"
  claim_type        = "IDENTITY"
  value_type        = "GROUPS"
  group_filter_type = "REGEX"
  value             = ".*"
  auth_server_id    = okta_auth_server.mdorn.id
}
resource "okta_auth_server_policy" "default" {
  status           = "ACTIVE"
  name             = "Default"
  description      = "Default"
  priority         = 1
  client_whitelist = ["ALL_CLIENTS"]
  auth_server_id   = okta_auth_server.mdorn.id
}
resource "okta_auth_server_policy_rule" "default" {
  auth_server_id       = okta_auth_server.mdorn.id
  policy_id            = okta_auth_server_policy.default.id
  status               = "ACTIVE"
  name                 = "Default"
  priority             = 1
  group_whitelist      = ["EVERYONE"]
  grant_type_whitelist = ["authorization_code", "implicit"]
  scope_whitelist      = ["orders:create", "products:read", "openid", "profile", "email"]
}
resource "okta_auth_server_policy_rule" "admin" {
  auth_server_id       = okta_auth_server.mdorn.id
  policy_id            = okta_auth_server_policy.default.id
  status               = "ACTIVE"
  name                 = "Admin"
  priority             = 2
  group_whitelist      = ["EVERYONE"]
  grant_type_whitelist = ["authorization_code", "implicit"]
  scope_whitelist      = ["orders:create", "products:read", "openid", "profile", "email", "orders:read", "orders:update", "products:update"]
}

resource "okta_auth_server_policy" "client_credentials" {
  status           = "ACTIVE"
  name             = "Client Credentials"
  description      = "Client Credentials"
  priority         = 2
  client_whitelist = ["ALL_CLIENTS"]
  auth_server_id   = okta_auth_server.mdorn.id
}
resource "okta_auth_server_policy_rule" "admin_client_credentials" {
  auth_server_id       = okta_auth_server.mdorn.id
  policy_id            = okta_auth_server_policy.client_credentials.id
  status               = "ACTIVE"
  name                 = "Admin client credentials"
  priority             = 1
  group_whitelist      = [okta_group.admin.id]
  grant_type_whitelist = ["client_credentials"]
  scope_whitelist      = ["orders:create", "orders:read", "orders:update", "products:update"]
}

data "template_file" "configuration" {
  template = "${file("${path.module}/.env.example")}"
  vars = {
    okta_base_url     = "${var.org_name}.${var.base_url}"
    okta_api_key      = var.api_token
    client_id         = okta_app_oauth.mdorn.client_id
    client_secret     = okta_app_oauth.mdorn.client_secret
    issuer            = okta_auth_server.mdorn.issuer
  }
}

resource "local_file" "env" {
  content  = data.template_file.configuration.rendered
  filename = "${path.module}/.env"
}
