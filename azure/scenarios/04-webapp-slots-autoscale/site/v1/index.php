<?php
// Release v1. The page shows which code is running and which slot settings it sees.
$env = getenv('ENVIRONMENT') ?: 'unset';
$ver = getenv('APP_VERSION') ?: 'unset';
?>
<!doctype html>
<html><head><meta charset="utf-8"><title>Shop - release 1</title></head>
<body style="font-family:sans-serif;background:#eef4ff;padding:2rem">
  <h1>Code: release 1</h1>
  <p>ENVIRONMENT (sticky setting): <strong><?= htmlspecialchars($env) ?></strong></p>
  <p>APP_VERSION (swaps with code): <strong><?= htmlspecialchars($ver) ?></strong></p>
  <p>Instance: <?= htmlspecialchars(getenv('WEBSITE_INSTANCE_ID') ?: 'local') ?></p>
</body></html>
