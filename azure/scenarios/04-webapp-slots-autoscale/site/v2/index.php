<?php
// Release v2. Deployed to the staging slot first, then swapped into production.
$env = getenv('ENVIRONMENT') ?: 'unset';
$ver = getenv('APP_VERSION') ?: 'unset';
?>
<!doctype html>
<html><head><meta charset="utf-8"><title>Shop - release 2</title></head>
<body style="font-family:sans-serif;background:#eafbea;padding:2rem">
  <h1>Code: release 2 (new checkout)</h1>
  <p>ENVIRONMENT (sticky setting): <strong><?= htmlspecialchars($env) ?></strong></p>
  <p>APP_VERSION (swaps with code): <strong><?= htmlspecialchars($ver) ?></strong></p>
  <p>Instance: <?= htmlspecialchars(getenv('WEBSITE_INSTANCE_ID') ?: 'local') ?></p>
</body></html>
