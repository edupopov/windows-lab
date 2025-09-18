<# 
  Cria 5 VMs no Hyper-V (Gen2):
    - SRV-AD-FIAP-01, SRV-AD-FIAP-02, SRV-FS-FIAP-03, CLI-W11-FIAP-01, SRV-APP-FIAP-01
    - 8 vCPUs, 4 GB RAM fixa (sem memória dinâmica), 1 VHDX (127 GB), 1 NIC ligada ao vSwitch informado
    - Criado pelo Professor Eduardo Popovici

No PowerShell, o param() é usado para declarar parâmetros de entrada de um script ou função — parecido com “argumentos” em uma função de programação.
Isso permite que você rode o script passando valores diferentes sem precisar editar o código.
Como funciona
Dentro do param() você define variáveis que podem ser passadas quando o script for executado.
Cada parâmetro pode ter:
Nome → Ex.: $SwitchName
Tipo → Ex.: [string], [int], [ValidateSet()]
Valor padrão → Ex.: = "vSwitch-External"
Obrigatoriedade → usando [Parameter(Mandatory=$true)]
#>

param(
  [string]$VmRoot     = "D:\Hyper-V\VMs",   # será validado; cai p/ C:\Hyper-V\VMs se a unidade não existir
  [UInt64]$VhdSizeGB  = 127,
  [int]$MemoryGB      = 4,
  [int]$vCPU          = 8,
  [ValidateSet(1,2)][int]$Generation = 2,
  [string]$ISOPath = ""
)

$vmNames = @(
  "SRV-AD-FIAP-01",
  "SRV-AD-FIAP-02",
  "SRV-FS-FIAP-03",
  "CLI-W11-FIAP-01",
  "SRV-APP-FIAP-01"
)

# --- Valida a unidade do VmRoot; fallback para C:\Hyper-V\VMs ---
$drive = (Split-Path -Qualifier $VmRoot).TrimEnd(':')   # ex.: "D"
if (-not (Get-PSDrive -Name $drive -ErrorAction SilentlyContinue)) {
  $VmRoot = Join-Path -Path "$($env:SystemDrive)\Hyper-V" -ChildPath "VMs"
  Write-Host "Unidade não encontrada. Usando '$VmRoot'." -ForegroundColor Yellow
}

# Garante pasta raiz
if (-not (Test-Path $VmRoot)) { New-Item -ItemType Directory -Path $VmRoot -Force | Out-Null }

# Converte tamanhos para bytes
[UInt64]$MemoryBytes = $MemoryGB * 1GB
[UInt64]$VhdBytes    = $VhdSizeGB * 1GB

foreach ($name in $vmNames) {
  try {
    if (Get-VM -Name $name -ErrorAction SilentlyContinue) {
      Write-Host "VM '$name' já existe. Ignorando criação..." -ForegroundColor Yellow
      continue
    }

    $vmPath  = Join-Path $VmRoot $name
    $vhdPath = Join-Path $vmPath "$name.vhdx"
    New-Item -ItemType Directory -Path $vmPath -Force | Out-Null

    # Cria VM sem switch
    New-VM -Name $name -Generation $Generation -MemoryStartupBytes $MemoryBytes -Path $vmPath | Out-Null

    # Memória fixa
    Set-VMMemory -VMName $name -DynamicMemoryEnabled:$false -StartupBytes $MemoryBytes

    # vCPU
    Set-VMProcessor -VMName $name -Count $vCPU

    # VHDX
    New-VHD -Path $vhdPath -SizeBytes $VhdBytes -Dynamic | Out-Null
    Add-VMHardDiskDrive -VMName $name -Path $vhdPath

    # 1 NIC desconectada
    $adapters = Get-VMNetworkAdapter -VMName $name
    if ($adapters.Count -eq 0) { Add-VMNetworkAdapter -VMName $name -Name "Network Adapter 1" | Out-Null }
    $adapters = Get-VMNetworkAdapter -VMName $name
    if ($adapters.Count -gt 1) {
      $adapters | Select-Object -Skip 1 | ForEach-Object { Remove-VMNetworkAdapter -VMName $name -Name $_.Name }
    }
    Disconnect-VMNetworkAdapter -VMName $name -Name (Get-VMNetworkAdapter -VMName $name).Name -ErrorAction SilentlyContinue

    # Notes + ações automáticas
    Set-VM -Name $name -Notes "Criado pelo professor Eduardo Popovici" `
           -AutomaticStartAction StartIfRunning -AutomaticStopAction Save

    # (Opcional) ISO + boot
    if ($ISOPath -and (Test-Path $ISOPath)) {
      $dvd = Get-VMDvdDrive -VMName $name -ErrorAction SilentlyContinue
      if (-not $dvd) { Add-VMDvdDrive -VMName $name -Path $ISOPath | Out-Null }
      else { Set-VMDvdDrive -VMName $name -Path $ISOPath | Out-Null }
      if ($Generation -eq 2) {
        $dvdBoot = Get-VMDvdDrive -VMName $name
        Set-VMFirmware -VMName $name -FirstBootDevice $dvdBoot
      }
    }

    Write-Host "VM '$name' criada em '$vmPath' (NIC sem switch)." -ForegroundColor Green
  }
  catch {
    Write-Host "Falha ao processar VM '$name': $($_.Exception.Message)" -ForegroundColor Red
  }
}

"`n=== RESUMO ==="
Get-VM -Name "*FIAP*" | Select-Object Name, State, ProcessorCount, MemoryStartup, Generation, Notes, Path | Format-Table -AutoSize


"`n=== RESUMO ==="
Get-VM -Name "*FIAP*" | Select-Object Name, State, ProcessorCount, MemoryStartup, Generation, Path | Format-Table -AutoSize
