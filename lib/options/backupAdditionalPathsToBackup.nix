{
  lib,
  additionalPathsToBackup ? [ ],
}:

lib.mkOption {
  type = lib.types.listOf lib.types.path;
  description = "List of paths to include in the backup for this service in addition to stateDir.";
  default = additionalPathsToBackup;
}
