<#!
Environment / Container Management Utility
Commands:
  list-wsl              List WSL distros
  shell                 Open interactive shell in Ubuntu-Dev
  docker-ps             List running containers (inside Ubuntu-Dev)
  docker-prune          Prune unused Docker objects safely
  ensure-network        Test DNS/network inside WSL (curl, apt update dry run)
  pull <image>          Pull a docker image inside WSL
  run <image> [args]    Run container (prints container id)
  compose-up <dir>      Run docker compose up (expects compose.yaml in dir)
  compose-down <dir>    Run docker compose down
  reset-docker          Restart docker service inside WSL
  export-image <image> <outTar>  Save image to tar
  import-image <tar> <name:tag>  Load image
#>
param(
  [Parameter(Mandatory=$true,Position=0)][string]$Command,
  [Parameter(Position=1)][string]$Arg1,
  [Parameter(Position=2)][string]$Arg2,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Rest
)
$ErrorActionPreference='Stop'
$distro='Ubuntu-Dev'
function InWSL([string]$cmd){ wsl -d $distro -- bash -lc "$cmd" }
if ($Command -eq 'list-wsl'){ wsl -l -v; exit 0 }
if ($Command -eq 'shell'){ wsl -d $distro; exit 0 }
if ($Command -eq 'docker-ps'){ InWSL 'docker ps -a'; exit 0 }
if ($Command -eq 'images'){ InWSL 'docker images'; exit 0 }
if ($Command -eq 'docker-prune'){ InWSL 'docker system prune -f'; exit 0 }
if ($Command -eq 'ensure-network'){ InWSL 'getent hosts github.com && curl -I https://download.docker.com/linux/ubuntu/ | head -n1'; exit 0 }
if ($Command -eq 'pull'){ if(-not $Arg1){ throw 'Image required' }; InWSL "docker pull $Arg1"; exit 0 }
if ($Command -eq 'run'){ if(-not $Arg1){ throw 'Image required' }; $extraArgs = ($Rest -join ' '); InWSL "docker run -d $extraArgs $Arg1"; exit 0 }
if ($Command -eq 'compose-up'){ if(-not $Arg1){ throw 'Directory required' }; InWSL "cd '$Arg1' && docker compose up -d"; exit 0 }
if ($Command -eq 'compose-down'){ if(-not $Arg1){ throw 'Directory required' }; InWSL "cd '$Arg1' && docker compose down"; exit 0 }
if ($Command -eq 'reset-docker'){ InWSL 'sudo systemctl restart docker && docker info | grep -i server'; exit 0 }
if ($Command -eq 'export-image'){ if(-not ($Arg1 -and $Arg2)){ throw 'Usage: export-image <image> <outTar>' }; InWSL "docker save $Arg1 -o $Arg2"; exit 0 }
if ($Command -eq 'import-image'){ if(-not ($Arg1 -and $Arg2)){ throw 'Usage: import-image <tar> <name:tag>' }; InWSL "docker load -i $Arg1 && docker tag $(basename $Arg1 .tar) $Arg2"; exit 0 }
Write-Error "Unknown command: $Command"; exit 1
