cd C:\Users\Admin\hecate-nautilus
Copy-Item .\Fix-Unbound.ps1 .\Fix-Unbound.old.ps1 -Force 2>$null

@'
param(
  [switch]$BindAll
)

$ErrorActionPreference = 'Stop'

function Say([string]$m){ Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Try-Native([scriptblock]$sb){
  try { & $sb 2>&1 } catch { $_ | Out-String }
}

# --- Paths
$Here   = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Here
$ConfDir = Join-Path $Here 'unbound\config'
$Entryp  = Join-Path $Here 'unbound\entrypoint.sh'
$Conf    = Join-Path $ConfDir 'unbound.conf'
$Hints   = Join-Path $ConfDir 'root.hints'
$WinCmp  = Join-Path $Here 'compose.unbound.windows.yml'
$BkpDir  = Join-Path $Here 'backups'
New-Item -ItemType Directory -Force -Path $ConfDir,$BkpDir | Out-Null

Say "Preparacao & paths"

# --- 1) entrypoint.sh
Say "Escrevendo entrypoint.sh (tolerante a Windows)"
@'
#!/bin/sh
set -u
CONF_SRC="/config/unbound.conf"
HINTS_SRC="/config/root.hints"
CONF_DST="/etc/unbound/unbound.conf"
HINTS_DST="/etc/unbound/root.hints"
mkdir -p /etc/unbound /var/run/unbound
chown -R unbound:unbound /etc/unbound /var/run/unbound 2>/dev/null || true
[ -s "$CONF_SRC" ] && cp -f "$CONF_SRC" "$CONF_DST"
[ -s "$HINTS_SRC" ] && cp -f "$HINTS_SRC" "$HINTS_DST"
echo "[entrypoint] checkconf..."
unbound-checkconf "$CONF_DST" || { echo "[entrypoint] invalid conf"; exit 1; }
echo "[entrypoint] starting unbound..."
exec unbound -d -c "$CONF_DST"
'@ | Set-Content -Encoding ascii $Entryp

# --- 2) unbound.conf
Say "Escrevendo unbound.conf"
@'
server:
  username: "unbound"
  directory: "/etc/unbound/"

  trust-anchor: ". DS 20326 8 2 E06D44B80B8F1D39A95C0B0D7C65D08458E880409BBC683457104237C7F8EC8D"
  root-hints: "/etc/unbound/root.hints"

  interface: 0.0.0.0
  port: 5335

  do-daemonize: no
  do-ip4: yes
  do-ip6: no
  do-tcp: yes
  prefer-ip6: no
  verbosity: 1

  msg-cache-size: 64m
  rrset-cache-size: 128m
  prefetch: yes
  module-config: "validator iterator"

  access-control: 0.0.0.0/0 allow
'@ | Set-Content -Encoding ascii $Conf

# --- 3) root.hints
Say "Baixando root.hints"
Invoke-WebRequest -UseBasicParsing -Uri 'https://www.internic.net/domain/named.root' -OutFile $Hints

# --- 4) Normalizar EOL
Say "Normalizando EOL (CRLF -> LF)"
foreach($f in @($Conf,$Hints,$Entryp)){
  if(Test-Path $f){
    (Get-Content -Raw $f) -replace "`r`n","`n" | Set-Content -NoNewline -Encoding ascii $f
  }
}

# --- 5) compose override para Windows
Say "Gerando compose.unbound.windows.yml"
$hostIP = "127.0.0.1"
if ($BindAll) { $hostIP = "0.0.0.0" }

@"
services:
  unbound:
    build:
      context: ./unbound
    container_name: hecate-unbound
    restart: unless-stopped
    ports:
      - "$hostIP:5335:5335/udp"
      - "$hostIP:5335:5335/tcp"
    volumes:
      - ./unbound/config:/config:ro
      - unbound_etc:/etc/unbound
    read_only: false
    healthcheck:
      test: ["CMD-SHELL", "unbound-host -C /etc/unbound/unbound.conf -t A example.com >/dev/null 2>&1 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 6
      start_period: 5s

volumes:
  unbound_etc:
"@ | Set-Content -Encoding ascii $WinCmp

# --- 6) Firewall IN & OUT
Say "Regras de firewall TCP/UDP 5335"
if(-not (Get-NetFirewallRule -DisplayName "Unbound TCP 5335 IN" -ErrorAction SilentlyContinue)){
  New-NetFirewallRule -DisplayName "Unbound TCP 5335 IN" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5335 | Out-Null
}
if(-not (Get-NetFirewallRule -DisplayName "Unbound UDP 5335 IN" -ErrorAction SilentlyContinue)){
  New-NetFirewallRule -DisplayName "Unbound UDP 5335 IN" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 5335 | Out-Null
}
if(-not (Get-NetFirewallRule -DisplayName "Unbound TCP 5335 OUT" -ErrorAction SilentlyContinue)){
  New-NetFirewallRule -DisplayName "Unbound TCP 5335 OUT" -Direction Outbound -Action Allow -Protocol TCP -RemoteAddress 127.0.0.1 -RemotePort 5335 | Out-Null
}
if(-not (Get-NetFirewallRule -DisplayName "Unbound UDP 5335 OUT" -ErrorAction SilentlyContinue)){
  New-NetFirewallRule -DisplayName "Unbound UDP 5335 OUT" -Direction Outbound -Action Allow -Protocol UDP -RemoteAddress 127.0.0.1 -RemotePort 5335 | Out-Null
}

# --- 7) Limpeza silenciosa
Say "Limpando estado antigo"
Try-Native { docker rm -f hecate-unbound } | Out-Null
Try-Native { docker volume rm hecate-nautilus_unbound_etc } | Out-Null
Try-Native { docker volume rm unbound_etc } | Out-Null

# --- 8) Validar e subir
Say "Validando compose"
docker compose -f $WinCmp config | Out-Null

Say "Subindo container (compose.unbound.windows.yml)"
docker compose -f $WinCmp up -d --build unbound | Out-Null

# --- 9) Aguardar HEALTHY
Say "Aguardando status 'Up'"
$ok = $false
$health = ""
for($i=0;$i -lt 40;$i++){
  Start-Sleep -Seconds 2
  $health = Try-Native { docker inspect --format "{{.State.Health.Status}}" hecate-unbound }
  if($health -match "healthy"){ $ok = $true; break }
}

# --- 10) Validação interna
Say "Validacao interna"
$cmd = 'unbound-checkconf /etc/unbound/unbound.conf || true; unbound-host -C /etc/unbound/unbound.conf -t A example.com || true; unbound-host -C /etc/unbound/unbound.conf -t A dnssec-failed.org || true'
$outIn = Try-Native { docker exec hecate-unbound sh -lc $cmd }

# --- 11) Testes no host (UDP/TCP)
Say "Testes no host (TCP/UDP)"
$nsUdp127 = Try-Native { nslookup -port=5335 example.com 127.0.0.1 }
$nsTcp127 = Try-Native { nslookup -port=5335 -vc example.com 127.0.0.1 }

$hostIPv4 = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike "169.*" -and $_.IPAddress -ne "127.0.0.1" -and $_.InterfaceAlias -notmatch "vEthernet|Loopback" } |
  Select-Object -First 1 -ExpandProperty IPAddress)
$nsUdpIP  = $null
$nsTcpIP  = $null
if($hostIPv4){
  $nsUdpIP = Try-Native { nslookup -port=5335 example.com $hostIPv4 }
  $nsTcpIP = Try-Native { nslookup -port=5335 -vc example.com $hostIPv4 }
}

$tnc127 = Try-Native { Test-NetConnection 127.0.0.1 -Port 5335 }

# --- 12) Diagnóstico
Say "Coletando diagnostico"
$report = @()
$report += "### STATUS`n" + (docker ps --filter "name=hecate-unbound" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
$report += "`n`n### PORTS (docker port)`n" + (Try-Native { docker port hecate-unbound })
$report += "`n`n### PORT BINDINGS (inspect)`n" + (Try-Native { docker inspect hecate-unbound --format '{{json .HostConfig.PortBindings}}' })
$report += "`n`n### VALIDATION INSIDE CONTAINER`n`n" + (Try-Native {
  docker exec hecate-unbound sh -lc 'test -s /etc/unbound/unbound.conf && head -n 60 /etc/unbound/unbound.conf || echo "conf ausente"'
  docker exec hecate-unbound sh -lc 'unbound-checkconf /etc/unbound/unbound.conf || true'
  docker exec hecate-unbound sh -lc 'unbound-host -C /etc/unbound/unbound.conf -t A example.com || true'
  docker exec hecate-unbound sh -lc 'unbound-host -C /etc/unbound/unbound.conf -t A dnssec-failed.org || true'
  docker exec hecate-unbound sh -lc 'cat /etc/resolv.conf || true'
})
$report += "`n`n### NSLOOKUP UDP 127.0.0.1`n$nsUdp127"
$report += "`n`n### NSLOOKUP TCP 127.0.0.1`n$nsTcp127"
if($hostIPv4){
  $report += "`n`n### NSLOOKUP UDP hostIP ($hostIPv4)`n$nsUdpIP"
  $report += "`n`n### NSLOOKUP TCP hostIP ($hostIPv4)`n$nsTcpIP"
}
$report += "`n`n### TEST-NETCONNECTION TCP 5335`n`n$tnc127"
$report += "`n`n### NETSTAT :5335`n" + (Try-Native { netstat -ano | Select-String ":5335" | Out-String })
$report += "`n`n### FIREWALL RULES (sumario)`n" + (Try-Native { Get-NetFirewallRule -DisplayName "Unbound * 5335 *" | Format-Table -AutoSize | Out-String })
$report += "`n`n### DOCKER LOGS (last 120s)`n" + (Try-Native { docker logs --since 120s hecate-unbound })

$ts = Get-Date -Format "yyyyMMddTHHmmss"
$repFile = Join-Path $BkpDir "unbound-diagnostics-$ts.txt"
$report -join "`r`n" | Set-Content -Encoding UTF8 $repFile
Write-Host "`nRelatorio salvo em: $repFile"

# --- 13) Resumo
$loopbackUdpFail = ($nsUdp127 -match "timed out")
$loopbackTcpFail = ($nsTcp127 -match "Unspecified error" -or $nsTcp127 -match "server failed" -or $nsTcp127 -match "could not")
$ipWorks = $false
if($hostIPv4){
  $ipWorks = (($nsUdpIP -and ($nsUdpIP -notmatch "timed out")) -or ($nsTcpIP -and ($nsTcpIP -notmatch "Unspecified error")))
}

if($ipWorks -and ($loopbackUdpFail -or $loopbackTcpFail)){
  Write-Warning "Loopback (127.0.0.1) bloqueado. Use -BindAll (0.0.0.0) ou consulte $hostIPv4:5335."
}elseif($loopbackUdpFail -and -not $ipWorks){
  Write-Warning "UDP do host nao chegou no container. Verifique Antivirus/Firewall/Winsock. Consulte o relatorio."
}elseif(-not $ok){
  Write-Warning "Container nao ficou HEALTHY; cheque logs no relatorio."
}else{
  Write-Host "Tudo OK: Unbound healthy e consultas funcionando." -ForegroundColor Green
}
'@ | Set-Content -Encoding ascii .\Fix-Unbound.ps1
