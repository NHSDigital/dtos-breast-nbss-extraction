# The header row of the CSV file is expected to be:
# suffix,container_name,security_group_name,ipAddress
#
# If 'container_name' is empty, it will default to "user-data".
# If 'security_group_name' is empty, it will default to "screening_nbsse_dev".
# The 'ipAddresses' column can contain one or more ';' separated IP values.
# Invalid, blank, 'null', or blocked IP values are ignored.

data "local_file" "upload_accounts" {
  filename = "${path.module}/upload-accounts.csv"
}
