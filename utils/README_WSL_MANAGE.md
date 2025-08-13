# WSL Management Cheatsheet

Move distro (relocate storage):
```
./utils/wsl_manage.ps1 Move -Name Ubuntu-Dev -To D:\WSL\Ubuntu-Dev
```

Clone distro (duplicate without destroying source):
```
./utils/wsl_manage.ps1 Clone -Name Ubuntu-Dev -NewName Ubuntu-Dev-Clone -NewPath D:\WSL\Ubuntu-Dev-Clone
```

Export baseline tar:
```
./utils/wsl_manage.ps1 Export -Name Ubuntu-Dev -Out K:\Baselines\WSL\Ubuntu-Dev_baseline.tar
```

Import from tar:
```
./utils/wsl_manage.ps1 Import -Name Ubuntu-Stage -From K:\Baselines\WSL\Ubuntu-Dev_baseline.tar -To D:\WSL\Ubuntu-Stage
```

Shrink VHDX (after cleanup):
```
./utils/wsl_manage.ps1 Shrink -Name Ubuntu-Dev
```

List distros with heuristic size info:
```
./utils/wsl_manage.ps1 List
```
