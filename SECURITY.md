# Security

## Reporting

Open a private security advisory in the hosting repository, or contact the
repository owner directly. Do not publish sensitive reproduction details in a
public issue.

## Scope

Cockpit TSPI Theme only injects a stylesheet into local Cockpit pages. It does
not implement authentication, authorization, networking, or privilege
escalation.

The installation script modifies package-provided HTML pages to add a local
stylesheet link. It backs up the originals under
`/var/lib/cockpit-tsi-theme/originals/`.

Do not expose Cockpit's port 9090 directly to the public internet.
