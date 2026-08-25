#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <region> <hub-subscription-id> <enable-soft-delete> <environment> <storage-resource-group> <storage-account-name> <app-short-name> <arm-subscription-id>\n' "$0" >&2
}

if (( $# < 8 || $# > 9 )); then
  printf 'ERROR: expected 8 or 9 arguments, received %d.\n' "$#" >&2
  usage
  exit 2
fi

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  ANSI_ESC=$'\033'
  ANSI_RESET="${ANSI_ESC}[0m"
  ANSI_BOLD="${ANSI_ESC}[1m"
  ANSI_DIM="${ANSI_ESC}[2m"
  ANSI_BLUE="${ANSI_ESC}[34m"
  ANSI_CYAN="${ANSI_ESC}[36m"
  ANSI_GREEN="${ANSI_ESC}[32m"
  ANSI_YELLOW="${ANSI_ESC}[33m"
else
  ANSI_ESC=''
  ANSI_RESET=''
  ANSI_BOLD=''
  ANSI_DIM=''
  ANSI_BLUE=''
  ANSI_CYAN=''
  ANSI_GREEN=''
  ANSI_YELLOW=''
fi

format_log_message() {
  local msg="$1"

  # Highlight words wrapped in [[...]] as bold yellow text.
  msg=$(printf '%s' "$msg" | sed -E "s/\\[\\[([^]]+)\\]\\]/${ANSI_BOLD}${ANSI_YELLOW}\\1${ANSI_RESET}/g")
  printf '%s' "$msg"
}

log_info() {
  local msg
  msg="$(format_log_message "$1")"
  printf '%b\n' "${ANSI_BLUE}${ANSI_BOLD}INFO${ANSI_RESET} ${msg}"
}

log_step() {
  local msg
  msg="$(format_log_message "$1")"
  printf '%b\n' "${ANSI_CYAN}${ANSI_BOLD}STEP${ANSI_RESET} ${msg}"
}

log_ok() {
  local msg
  msg="$(format_log_message "$1")"
  printf '%b\n' "${ANSI_GREEN}${ANSI_BOLD}OK${ANSI_RESET} ${msg}"
}

log_warn() {
  local msg
  msg="$(format_log_message "$1")"
  printf '%b\n' "${ANSI_YELLOW}${ANSI_BOLD}WARN${ANSI_RESET} ${msg}"
}

REGION="$1"
HUB_SUBSCRIPTION_ID="$2"
ENABLE_SOFT_DELETE="$3"
ENV_CONFIG="$4"
STORAGE_ACCOUNT_RG="$5"
STORAGE_ACCOUNT_NAME="$6"
APP_SHORT_NAME="$7"
ARM_SUBSCRIPTION_ID="$8"

MAIN_DEPLOYMENT_NAME="bootstrap-${APP_SHORT_NAME}-${ENV_CONFIG}-main"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
MAIN_TEMPLATE="${REPO_ROOT}/infrastructure/bootstrap/main.bicep"
userGroupName="screening_${APP_SHORT_NAME}_${ENV_CONFIG}"

check_prerequisites() {
  local command_name template subscription_id
  
  userGroupPrincipalID=$(az ad group show --group "$userGroupName" --query id -o tsv 2>/dev/null || true)
  if [ -z "$userGroupPrincipalID" ]; then
    log_warn "Required Entra group '[[$userGroupName]]' was not found or cannot be read"
    return 1
  fi

  userGroupDisplayName=$(az ad group show --group "$userGroupName" --query displayName -o tsv 2>/dev/null || true)
  if [ -z "$userGroupDisplayName" ]; then
    userGroupDisplayName="$userGroupName"
  fi

  hubSubscriptionName=$(az account list --query "[?id=='${HUB_SUBSCRIPTION_ID}'].name | [0]" -o tsv 2>/dev/null || true)
  if [ -z "$hubSubscriptionName" ]; then
    hubSubscriptionName="$HUB_SUBSCRIPTION_ID"
  fi

  log_ok "Prerequisite checks passed"
  log_ok "Hub subscription: [[$hubSubscriptionName]] ([[$HUB_SUBSCRIPTION_ID]])"
  log_ok "User group to grant access: [[$userGroupDisplayName]] ([[$userGroupPrincipalID]])"
}

check_prerequisites

mainBicepParams=(
  enableSoftDelete="$ENABLE_SOFT_DELETE"
  envConfig="$ENV_CONFIG"
  region="$REGION"
  storageAccountRGName="$STORAGE_ACCOUNT_RG"
  storageAccountName="$STORAGE_ACCOUNT_NAME"
  appShortName="$APP_SHORT_NAME"
  userGroupPrincipalID="$userGroupPrincipalID"
)

echo
log_step "Pre-test deploying bootstrap resources into hub subscription [[$hubSubscriptionName]]"
az deployment sub create \
  --location "$REGION" \
  --template-file "$MAIN_TEMPLATE" \
  --name "$MAIN_DEPLOYMENT_NAME" \
  --subscription "$HUB_SUBSCRIPTION_ID" \
  --parameters "${mainBicepParams[@]}" \
  --what-if

echo
read -r -p "Proceed with deployment? (y/n): " confirm
[[ "$confirm" != "y" ]] && exit 0

echo
log_step "Deploying bootstrap resources into hub subscription [[$hubSubscriptionName]]..."
output=$(az deployment sub create \
  --location "$REGION" \
  --template-file "$MAIN_TEMPLATE" \
  --name "$MAIN_DEPLOYMENT_NAME" \
  --subscription "$HUB_SUBSCRIPTION_ID" \
  --parameters "${mainBicepParams[@]}")

log_info "Deployment output:"
echo "$output"
