<?php

// Fails when a plugin's plugin.json "require" is not satisfied by this Matomo
// (and PHP), using Matomo's own Dependency class so the verdict matches what
// Matomo decides at runtime when it refuses to load the plugin.
//
// Usage: php check-plugin-dependencies.php <matomo share dir> <plugin.json>

// Matomo's vendored libraries emit deprecation notices on current PHP.
error_reporting(E_ALL & ~E_DEPRECATED);

[, $matomoDir, $pluginJson] = $argv;

require $matomoDir . '/vendor/autoload.php';

$requires = json_decode(file_get_contents($pluginJson), true, flags: JSON_THROW_ON_ERROR)['require'] ?? [];
$missing = (new \Piwik\Plugin\Dependency())->getMissingDependencies($requires);

foreach ($missing as $m) {
    fwrite(STDERR, "$pluginJson: requires {$m['requirement']} {$m['requiredVersion']}, found {$m['actualVersion']}\n");
}

exit($missing ? 1 : 0);
