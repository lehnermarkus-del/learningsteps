import os
from pathlib import Path
from string import Template

required = ("IMAGE", "APP_CLIENT_ID", "KEY_VAULT_NAME", "TENANT_ID", "CLIENT_CIDR")
for key in required:
    if not os.getenv(key):
        raise SystemExit(f"Fehlende Variable: {key}")
Path("rendered").mkdir(exist_ok=True)
for source in Path("k8s-manifests").glob("*.yaml"):
    Path("rendered", source.name).write_text(Template(source.read_text()).substitute(os.environ))
