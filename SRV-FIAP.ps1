<# 
  Cria 5 VMs no Hyper-V:
   - SRV-AD-FIAP-01, SRV-AD-FIAP-02, SRV-FS-FIAP-03, CLI-W11-FIAP-01, SRV-APP-FIAP-01
   - 8 vCPUs, 4 GB RAM fixa, 1 VHDX (127 GB), 1 NIC conectada ao vSwitch informado
   - Geração 2 por padrão (UEFI). Mantém 1 adaptador de rede.
   - Idempotente: se a VM já existir, apenas informa e segue para a próxima.
   - Criado pelo porfessor Eduardo Popovici
#>

param(
  [Parameter(Mandatory=$false)]
  [string]$SwitchName = "vSwitch-External",   # Substitua pelo seu vSwitch (já existente)

  [Parameter(Mandatory=$false)]
  [string]$VmRoot = "D:\Hyper-V\VMs",         # Pasta base das VMs

  [Parameter(Mandatory=$false)]
  [UInt64]$VhdSizeGB = 127,                   # Tamanho do VHDX (GB)

  [Parameter(Mandatory=$false)]
  [int]$MemoryGB = 4,                         # RAM fixa (GB)

  [Parameter(Mandatory=$false)]
  [int]$vCPU = 8,                             # Número de vCPUs

  [Parameter(Mandatory=$false)]
  [ValidateSet(1,2)]
  [int]$Generation = 2,                       # 2 = UEFI (recomendado)

  [Parameter(Mandatory=$false)]
  [string]$ISOPath = ""                        # Opcional: caminho de ISO para boot/instalação
)

$vmNames = @(
  "SRV-AD-FIAP-01",
  "SRV-AD-FIAP-02",
  "SRV-FS-FIAP-03",
  "CLI-W11-FIAP-01",
  "SRV-APP-FIAP-01"
)

# --- Validações iniciais ---
# Verifica vSwitch
$vSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $vSwitch) {
  throw "vSwitch '$SwitchName' não encontrado. Crie-o (New-VMSwitch) ou informe um existente via -SwitchName."
}

# Garante pasta raiz
if (-not (Test-Path $VmRoot)) { New-Item -ItemType Directory -Path $VmRoot -Force | Out-Null }

# --- Criação/Configuração das VMs ---
foreach ($name in $vmNames) {
  try {
    if (Get-VM -Name $name -ErrorAction SilentlyContinue) {
      Write-Host "⚠VM '$name' já existe. Ignorando criação..." -ForegroundColor Yellow
      continue
    }

    $vmPath  = Join-Path $VmRoot $name
    $vhdPath = Join-Path $vmPath "$name.vhdx"
    New-Item -ItemType Directory -Path $vmPath -Force | Out-Null

    # Cria VM (gera 1 NIC por padrão e já conecta ao vSwitch)
    New-VM -Name $name `
           -Generation $Generation `
           -MemoryStartupBytes (${MemoryGB}GB) `
           -SwitchName $SwitchName `
           -Path $vmPath | Out-Null

    # Memória fixa (desabilita dinâmica)
    Se
