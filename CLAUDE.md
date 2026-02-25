# WorkWidget - Development Rules

## Build & Deploy Workflow

When completing a feature, bug fix, or any code change task, **always** run the following steps automatically before reporting completion:

```bash
# 1. Kill existing WorkWidget process
pkill -x WorkWidget 2>/dev/null || true

# 2. Build and install to /Applications
bash Scripts/build-app.sh

# 3. Launch the updated app
open /Applications/WorkWidget.app
```

Do NOT skip these steps. The user expects the updated app to be running after every code change.
