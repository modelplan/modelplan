# U7: superseded self-signed test-identity plan

A14 is deferred until Developer ID. Do not create another self-signed test identity,
add trust settings or rerun the retired provisioning flow. The dedicated test
Keychain has been deleted. Per-certificate user/admin/system trust settings were
checked absent; no trust settings were added by these test runs.

The approved interim direction is the byte-identical helper described in
HELPER-PLAN.md. Packaging identity checks are not A14 or Keychain ACL acceptance.
